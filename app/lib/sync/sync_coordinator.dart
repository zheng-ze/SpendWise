import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/drift_ledger_store.dart'
    show PersistenceBarrierFailure;
import 'package:spendwise/persistence/ledger_database.dart'
    hide Account, SubPocket, Entry, Budget;
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:spendwise/sync/cached_collection_version_source.dart';
import 'package:spendwise/sync/collection_lock.dart';
import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:spendwise/sync/credential_provider.dart';
import 'package:spendwise/sync/drift_sync_staging_store.dart';
import 'package:spendwise/sync/mutation_fence.dart';
import 'package:spendwise/sync/post_flush_readback_verifier.dart';
import 'package:spendwise/sync/row_readback_outcome.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_backend_resolver.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_run_scheduler.dart';
import 'package:spendwise/sync/sync_status.dart';
import 'package:sync/sync.dart';

final class SyncCoordinatorWiringException implements Exception {
  const SyncCoordinatorWiringException();

  @override
  String toString() =>
      'SyncCoordinatorWiringException: the ledger and the persistence '
      'processor must share one event bus; their bus instances differ.';
}

typedef PassFailureHandler = void Function(Object error);

sealed class PushCollectionResult {
  const PushCollectionResult();
}

final class PushNoop extends PushCollectionResult {
  const PushNoop();
}

final class PushDeferred extends PushCollectionResult {
  const PushDeferred();
}

final class PushFullyAcknowledged extends PushCollectionResult {
  PushFullyAcknowledged(Set<SyncRowID> acknowledged)
    : acknowledged = Set.unmodifiable(acknowledged);

  final Set<SyncRowID> acknowledged;
}

final class PushUnresolvedRows extends PushCollectionResult {
  PushUnresolvedRows(Set<SyncRowID> unresolved)
    : unresolved = Set.unmodifiable(unresolved);

  final Set<SyncRowID> unresolved;
}

final class SyncCoordinator extends ChangeNotifier {
  SyncCoordinator._({
    required this.engine,
    required this.backend,
    required this.versionSource,
    required this.versionReader,
    required this.metadataStore,
    required this.verifier,
    required this._credentialProvider,
    required this.ledger,
    required this.persistenceProcessor,
    required this.stagingStore,
    this.onPassFailure,
  }) : _status = const SyncIdle() {
    _scheduler = SyncRunScheduler(
      runPass: _runOnePass,
      onStatusChanged: _handleSchedulerStatus,
    );
  }

  static Future<SyncCoordinator> create({
    required LedgerDatabase database,
    required Ledger ledger,
    required PersistenceProcessor persistenceProcessor,
    SupabaseConfig? supabaseConfig,
    http.Client? httpClient,
    SecretStore? secretStore,
    PassFailureHandler? onPassFailure,
  }) async {
    if (!identical(ledger.bus, persistenceProcessor.bus)) {
      throw const SyncCoordinatorWiringException();
    }
    final String userID = await deviceID(database);
    final DriftSyncStagingStore staging = await DriftSyncStagingStore.open(
      database,
    );
    final SyncMetadataStore metadataStore = SyncMetadataStore(database);
    final SyncMetadataSnapshot snapshot = await metadataStore.snapshot();
    final SyncBackend? backend = const SyncBackendResolver().resolve(
      snapshot,
      supabaseConfig: supabaseConfig,
      httpClient: httpClient,
    );
    final DriftCollectionVersionReader reader = DriftCollectionVersionReader(
      database,
    );
    final CachedCollectionVersionSource versionSource =
        CachedCollectionVersionSource(reader);
    final SecretStore effectiveSecrets = secretStore ?? SecureSecretStore();
    final SyncE2EKeyProvider keyProvider = SyncE2EKeyProvider(
      secretStore: effectiveSecrets,
    );
    final CredentialProvider credentialProvider = CredentialProvider(
      database: database,
      secretStore: effectiveSecrets,
    );
    final SyncEngine engine = SyncEngine(
      userID: userID,
      keyAccessor: keyProvider.accessor,
      stagingStore: staging,
    );
    return SyncCoordinator._(
      engine: engine,
      backend: backend,
      versionSource: versionSource,
      versionReader: reader,
      metadataStore: metadataStore,
      verifier: PostFlushReadbackVerifier(reader),
      credentialProvider: credentialProvider,
      ledger: ledger,
      persistenceProcessor: persistenceProcessor,
      stagingStore: staging,
      onPassFailure: onPassFailure,
    );
  }

  @visibleForTesting
  SyncCoordinator.forTesting({
    required this.engine,
    required this.backend,
    required this.versionSource,
    required this.versionReader,
    required this.metadataStore,
    required this.verifier,
    required this._credentialProvider,
    required this.ledger,
    required this.persistenceProcessor,
    required this.stagingStore,
    this.onPassFailure,
  }) : _status = const SyncIdle() {
    _scheduler = SyncRunScheduler(
      runPass: _runOnePass,
      onStatusChanged: _handleSchedulerStatus,
    );
  }

  static const int _maxFoldInAttempts = 3;

  final SyncEngine engine;

  final SyncBackend? backend;

  final SyncVersionSource versionSource;

  final CollectionVersionReader versionReader;

  final SyncMetadataStore metadataStore;

  final PostFlushReadbackVerifier verifier;

  final CredentialProvider _credentialProvider; // ignore: unused_field

  final Ledger ledger;

  final PersistenceProcessor persistenceProcessor;

  final SyncStagingStore stagingStore;

  final PassFailureHandler? onPassFailure;

  final CollectionLock _lock = CollectionLock();

  SyncStatus _status;

  SyncStatus get status => _status;

  bool _disposed = false;

  late final SyncRunScheduler _scheduler;

  void requestSync() {
    if (_disposed) return;
    _scheduler.requestRun();
  }

  Future<void> syncNow() {
    if (_disposed) {
      throw StateError('Cannot sync: this SyncCoordinator has been disposed.');
    }
    return _scheduler.runNow();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _runOnePass() async {
    try {
      await recoverPendingAcknowledgements();
      final passes = <Future<void>>[
        for (final collection in SyncCollection.values)
          _pullThenPush(collection),
      ];
      await Future.wait(passes);
    } on StateError catch (error) {
      onPassFailure?.call(error);
    }
  }

  Future<void> _pullThenPush(SyncCollection collection) async {
    await processPullPage(collection);
    await pushCollection(collection);
  }

  void _handleSchedulerStatus(bool running) {
    if (_disposed) return;
    _status = running ? const SyncRunning() : const SyncIdle();
    notifyListeners();
  }

  static bool _isDuplicateOrDominated(
    RowVersion? stored,
    VersionVector pulled,
  ) => stored != null && stored.versionVector.dominates(pulled);

  Future<void> processPullPage(SyncCollection collection) =>
      _lock.withLock(collection, () => _processPullPageLocked(collection));

  Future<void> _processPullPageLocked(SyncCollection collection) async {
    final _PulledPage page = await _pullAndValidatePage(collection);

    try {
      final ReconcileResult remoteResult = await engine.reconcile(
        page.envelopes,
      );
      final _RemoteProvenance provenance = _indexRemoteProvenance(
        page.envelopes,
        remoteResult,
      );

      var applied = false;
      var everyAttemptWasEmptyAttemptRows = false;

      for (var attempt = 1; attempt <= _maxFoldInAttempts; attempt += 1) {
        final _AttemptOutcome outcome = await _runFoldInAttempt(
          collection: collection,
          nextCursor: page.nextCursor,
          remoteResult: remoteResult,
          remoteWinner: provenance.remoteWinner,
          remoteWinnerChange: provenance.remoteWinnerChange,
        );
        if (outcome is _AttemptRetry) {
          continue;
        }
        if (outcome is _AttemptEmpty) {
          everyAttemptWasEmptyAttemptRows = true;
          break;
        }
        applied = true;
        return;
      }

      if (!applied) {
        if (everyAttemptWasEmptyAttemptRows) {
          await _finalizeAndMaybeAcknowledge(
            collection,
            stamps: const <SyncRowID, VersionVector>{},
            watermark: page.nextCursor,
            checkpoint: page.nextCursor,
          );
        }
      }
    } on PersistenceBarrierFailure {
      return;
    } finally {
      await stagingStore.flush();
    }
  }

  Future<_PulledPage> _pullAndValidatePage(SyncCollection collection) async {
    final SyncBackend? backend = this.backend;
    if (backend == null) {
      throw StateError(
        'Cannot pull $collection before enrollment: no sync backend.',
      );
    }
    final SyncMetadataSnapshot snapshot = await metadataStore.snapshot();
    final String? cursor = snapshot.watermarks[collection];
    final SyncOutcome<PullResponse> outcome = await _credentialProvider
        .withCredential(
          (DeviceCredential credential) => backend.pull(
            credential,
            PullRequest(collection: collection, cursor: cursor),
          ),
        );
    final PullResponse response;
    switch (outcome) {
      case SyncSuccess<PullResponse>(value: final value):
        response = value;
      case SyncFailure<PullResponse>(code: final code, message: final message):
        throw StateError('Pull of $collection failed ($code): $message.');
    }
    final List<SyncEnvelope> envelopes = response.envelopes;
    for (final SyncEnvelope envelope in envelopes) {
      if (envelope.collection != collection) {
        throw StateError(
          'Pull of $collection returned an envelope for '
          '${envelope.collection}.',
        );
      }
    }
    return _PulledPage(envelopes: envelopes, nextCursor: response.cursor);
  }

  _RemoteProvenance _indexRemoteProvenance(
    List<SyncEnvelope> envelopes,
    ReconcileResult remoteResult,
  ) {
    final Map<SyncRowID, SyncEnvelope> remoteWinner =
        <SyncRowID, SyncEnvelope>{};
    for (final MapEntry<SyncRowID, int> entry
        in remoteResult.winningInputIndex.entries) {
      final int index = entry.value;
      if (index < 0 || index >= envelopes.length) continue;
      remoteWinner[entry.key] = envelopes[index];
    }
    final Map<SyncRowID, LedgerChange> remoteWinnerChange =
        <SyncRowID, LedgerChange>{};
    for (final LedgerChange change in remoteResult.changes) {
      remoteWinnerChange[SyncRowID.of(collectionFor(change), change.targetID)] =
          change;
    }
    return _RemoteProvenance(
      remoteWinner: remoteWinner,
      remoteWinnerChange: remoteWinnerChange,
    );
  }

  Future<_AttemptOutcome> _runFoldInAttempt({
    required SyncCollection collection,
    required String nextCursor,
    required ReconcileResult remoteResult,
    required Map<SyncRowID, SyncEnvelope> remoteWinner,
    required Map<SyncRowID, LedgerChange> remoteWinnerChange,
  }) async {
    final MutationFence fence = MutationFence(ledger.bus)..install();
    try {
      final int epoch = fence.snapshot();

      await versionSource.refresh();
      final _AttemptClassification classification = _classifyAttemptRows(
        remoteResult.stamps,
      );
      if (classification.attemptRows.isEmpty) {
        return const _AttemptEmpty();
      }

      await persistenceProcessor.flush();
      await versionSource.refresh();
      if (!fence.checkClean(epoch)) {
        return const _AttemptRetry();
      }

      final _AttemptSnapshot captured = _captureAttemptSnapshot(
        classification.attemptRows,
      );

      final _FoldInOutcome foldIn = await _reconcileFoldInCandidates(
        foldInCandidates: classification.foldInCandidates,
        remoteWinner: remoteWinner,
        refreshedContent: captured.refreshedContent,
      );
      if (foldIn.excluded) {
        return const _AttemptRetry();
      }

      final _FinalDecision decision = _finalizeSynchronously(
        directApplyCandidates: classification.directApplyCandidates,
        remoteEligible: foldIn.remoteEligible,
        remoteWinnerChange: remoteWinnerChange,
        remoteStamps: remoteResult.stamps,
        refreshedVersions: captured.refreshedVersions,
        fence: fence,
        epoch: epoch,
      );
      if (decision.raceDetected) {
        return const _AttemptRetry();
      }

      if (decision.changes.isNotEmpty) {
        ledger.applySyncBatch(decision.changes, decision.stamps);
      }

      if (decision.changes.isNotEmpty) {
        await persistenceProcessor.flush();
        final Map<SyncRowID, RowReadbackOutcome> outcomes = await verifier
            .verify(decision.stamps);
        if (outcomes.values.any((result) => !result.passed)) {
          return const _AttemptDone();
        }
      }

      await _finalizeAndMaybeAcknowledge(
        collection,
        stamps: decision.stamps,
        watermark: nextCursor,
        checkpoint: nextCursor,
      );
      return const _AttemptDone();
    } finally {
      await fence.uninstall();
    }
  }

  _AttemptClassification _classifyAttemptRows(
    Map<SyncRowID, VersionVector> stamps,
  ) {
    final Set<SyncRowID> directApplyCandidates = <SyncRowID>{};
    final Set<SyncRowID> foldInCandidates = <SyncRowID>{};
    for (final MapEntry<SyncRowID, VersionVector> entry in stamps.entries) {
      final SyncRowID row = entry.key;
      final RowVersion? stored = versionSource.readRowVersion(row);
      if (_isDuplicateOrDominated(stored, entry.value)) continue;
      if (stored == null) {
        directApplyCandidates.add(row);
      } else {
        foldInCandidates.add(row);
      }
    }
    final Set<SyncRowID> attemptRows = <SyncRowID>{
      ...directApplyCandidates,
      ...foldInCandidates,
    };
    return _AttemptClassification(
      directApplyCandidates: directApplyCandidates,
      foldInCandidates: foldInCandidates,
      attemptRows: attemptRows,
    );
  }

  _AttemptSnapshot _captureAttemptSnapshot(Set<SyncRowID> attemptRows) {
    final Map<SyncRowID, RowVersion?> refreshedVersions =
        <SyncRowID, RowVersion?>{};
    for (final SyncRowID row in attemptRows) {
      refreshedVersions[row] = versionSource.readRowVersion(row);
    }
    final LedgerState liveState = ledger.state;
    final Map<SyncRowID, LedgerChange> refreshedContent =
        <SyncRowID, LedgerChange>{};
    for (final SyncRowID row in attemptRows) {
      refreshedContent[row] = _currentLocalChange(liveState, row);
    }
    return _AttemptSnapshot(
      refreshedVersions: refreshedVersions,
      refreshedContent: refreshedContent,
    );
  }

  Future<_FoldInOutcome> _reconcileFoldInCandidates({
    required Set<SyncRowID> foldInCandidates,
    required Map<SyncRowID, SyncEnvelope> remoteWinner,
    required Map<SyncRowID, LedgerChange> refreshedContent,
  }) async {
    var foldInExcluded = false;
    final Map<SyncRowID, VersionVector> remoteEligible =
        <SyncRowID, VersionVector>{};
    for (final SyncRowID row in foldInCandidates) {
      final SyncEnvelope? remote = remoteWinner[row];
      final LedgerChange? local = refreshedContent[row];
      if (remote == null || local == null) {
        foldInExcluded = true;
        continue;
      }
      final List<SyncEnvelope> encoded = await engine.encode(<LedgerChange>[
        local,
      ], versionSource);
      if (encoded.length != 1) {
        foldInExcluded = true;
        continue;
      }
      final ReconcileResult foldInResult = await engine.reconcile(
        <SyncEnvelope>[remote, encoded[0]],
      );
      final int? winner = foldInResult.winningInputIndex[row];
      switch (winner) {
        case 0:
          final VersionVector? stamp = foldInResult.stamps[row];
          if (stamp == null) {
            foldInExcluded = true;
          } else {
            remoteEligible[row] = stamp;
          }
        case 1:
          break;
        case null:
          break;
      }
    }
    return _FoldInOutcome(
      excluded: foldInExcluded,
      remoteEligible: remoteEligible,
    );
  }

  _FinalDecision _finalizeSynchronously({
    required Set<SyncRowID> directApplyCandidates,
    required Map<SyncRowID, VersionVector> remoteEligible,
    required Map<SyncRowID, LedgerChange> remoteWinnerChange,
    required Map<SyncRowID, VersionVector> remoteStamps,
    required Map<SyncRowID, RowVersion?> refreshedVersions,
    required MutationFence fence,
    required int epoch,
  }) {
    final List<LedgerChange> changes = <LedgerChange>[];
    final Map<SyncRowID, VersionVector> stamps = <SyncRowID, VersionVector>{};
    for (final SyncRowID row in directApplyCandidates) {
      if (versionSource.readRowVersion(row) != null) {
        return const _FinalDecision.raceDetected();
      }
      final LedgerChange? change = remoteWinnerChange[row];
      final VersionVector? stamp = remoteStamps[row];
      if (change == null || stamp == null) {
        return const _FinalDecision.raceDetected();
      }
      changes.add(change);
      stamps[row] = stamp;
    }
    for (final MapEntry<SyncRowID, VersionVector> entry
        in remoteEligible.entries) {
      final SyncRowID row = entry.key;
      final RowVersion? reconciledAgainst = refreshedVersions[row];
      final RowVersion? current = versionSource.readRowVersion(row);
      if (reconciledAgainst == null ||
          current == null ||
          reconciledAgainst.versionVector != current.versionVector) {
        return const _FinalDecision.raceDetected();
      }
      final LedgerChange? change = remoteWinnerChange[row];
      if (change == null) {
        return const _FinalDecision.raceDetected();
      }
      changes.add(change);
      stamps[row] = entry.value;
    }
    if (!fence.checkClean(epoch)) {
      return const _FinalDecision.raceDetected();
    }
    if (changes.isEmpty) {
      return const _FinalDecision.raceDetected();
    }
    return _FinalDecision.commit(changes: changes, stamps: stamps);
  }

  Future<void> _finalizeAndMaybeAcknowledge(
    SyncCollection collection, {
    required Map<SyncRowID, VersionVector> stamps,
    required String watermark,
    required String checkpoint,
  }) async {
    await stagingStore.flush();
    await metadataStore.recordPulledPage(
      collection: collection,
      vectors: stamps,
      watermark: watermark,
      checkpoint: checkpoint,
    );
  }

  LedgerChange _currentLocalChange(LedgerState state, SyncRowID row) {
    switch (row.collection) {
      case SyncCollection.moneySources:
        final MoneySource? source = state.moneySources[row.rowID];
        if (source == null || source.lifecycle == LifecycleState.tombstoned) {
          return deleteFor(row.collection, row.rowID);
        }
        return LedgerChange.upsertSource(source);
      case SyncCollection.categories:
        final TransactionCategory? category = state.categories[row.rowID];
        if (category == null ||
            category.lifecycle == LifecycleState.tombstoned) {
          return deleteFor(row.collection, row.rowID);
        }
        return UpsertCategory(category);
      case SyncCollection.entries:
        final Entry? entry = state.entries[row.rowID];
        if (entry == null || entry.lifecycle == LifecycleState.tombstoned) {
          return deleteFor(row.collection, row.rowID);
        }
        return UpsertEntry(entry);
      case SyncCollection.plans:
        final RecurringPlan? plan = state.plans[row.rowID];
        if (plan == null) return deleteFor(row.collection, row.rowID);
        return UpsertPlan(plan);
      case SyncCollection.budgets:
        final Budget? budget = state.budgets[row.rowID];
        if (budget == null) return deleteFor(row.collection, row.rowID);
        return UpsertBudget(budget);
    }
  }

  Future<void> recoverPendingAcknowledgements() async {
    final SyncBackend? backend = this.backend;
    if (backend == null) {
      throw StateError(
        'Cannot acknowledge before enrollment: no sync backend.',
      );
    }
    final Map<SyncCollection, String> pending = await metadataStore
        .pendingAcknowledgements();
    for (final MapEntry<SyncCollection, String> entry in pending.entries) {
      await _lock.withLock(
        entry.key,
        () => _recoverOneAcknowledgement(backend, entry.key, entry.value),
      );
    }
  }

  Future<void> _recoverOneAcknowledgement(
    SyncBackend backend,
    SyncCollection collection,
    String checkpoint,
  ) => _recoverOneAcknowledgementLocked(backend, collection, checkpoint);

  Future<void> _recoverOneAcknowledgementLocked(
    SyncBackend backend,
    SyncCollection collection,
    String checkpoint,
  ) async {
    final List<StagedConflict> staged = await stagingStore
        .pendingConflictList();
    if (staged.any(
      (StagedConflict conflict) => conflict.collection == collection,
    )) {
      return;
    }
    final SyncOutcome<AcknowledgeResponse> outcome = await _credentialProvider
        .withCredential(
          (DeviceCredential credential) => backend.acknowledge(
            credential,
            AcknowledgeRequest(collection: collection, checkpoint: checkpoint),
          ),
        );
    switch (outcome) {
      case SyncSuccess<AcknowledgeResponse>():
        await metadataStore.clearPendingAcknowledgementIfMatches(
          collection,
          checkpoint,
        );
      case SyncFailure<AcknowledgeResponse>():
        break;
    }
  }

  Future<PushCollectionResult> pushCollection(
    SyncCollection collection, {
    String? writeProof,
  }) => _lock.withLock(
    collection,
    () => _pushCollectionLocked(collection, writeProof: writeProof),
  );

  Future<PushCollectionResult> _pushCollectionLocked(
    SyncCollection collection, {
    String? writeProof,
  }) async {
    final SyncMetadataSnapshot gate = await metadataStore.snapshot();
    if (!gate.writeEnabled) {
      throw StateError(
        'Cannot push $collection while sync writes are disabled.',
      );
    }
    final SyncBackend? backend = this.backend;
    if (backend == null) {
      throw StateError(
        'Cannot push $collection before enrollment: no sync backend.',
      );
    }

    final String? pending = await metadataStore.pendingAcknowledgement(
      collection,
    );
    if (pending != null) {
      await _recoverOneAcknowledgementLocked(backend, collection, pending);
      if (await metadataStore.pendingAcknowledgement(collection) != null) {
        return const PushDeferred();
      }
    }

    await persistenceProcessor.flush();
    await versionSource.refresh();

    final Map<SyncRowID, RowVersion> stored = await versionReader
        .readRowVersions(collection);
    final Map<SyncRowID, VersionVector> acknowledged = await metadataStore
        .acknowledgedVectors();
    final List<SyncRowID> candidates = <SyncRowID>[];
    for (final MapEntry<SyncRowID, RowVersion> entry in stored.entries) {
      final VersionVector? acked = acknowledged[entry.key];
      if (acked == null || !acked.dominates(entry.value.versionVector)) {
        candidates.add(entry.key);
      }
    }
    if (candidates.isEmpty) {
      return const PushNoop();
    }

    final LedgerState liveState = ledger.state;
    final List<LedgerChange> changes = <LedgerChange>[
      for (final SyncRowID row in candidates)
        _currentLocalChange(liveState, row),
    ];
    final List<SyncEnvelope> envelopes = await engine.encode(
      changes,
      versionSource,
    );
    final Map<SyncRowID, _SubmittedPush> submitted = Map.unmodifiable(
      <SyncRowID, _SubmittedPush>{
        for (final SyncEnvelope envelope in envelopes)
          SyncRowID.of(envelope.collection, envelope.rowID): _SubmittedPush(
            vector: envelope.versionVector,
            siblingID: envelope.siblingID,
          ),
      },
    );

    final SyncOutcome<PushResponse> outcome = await _credentialProvider
        .withCredential(
          (DeviceCredential credential) => backend.push(
            credential,
            PushRequest(envelopes: envelopes, writeProof: writeProof),
          ),
        );
    final PushResponse response;
    switch (outcome) {
      case SyncSuccess<PushResponse>(value: final value):
        response = value;
      case SyncFailure<PushResponse>(code: final code, message: final message):
        throw StateError('Push of $collection failed ($code): $message.');
    }
    final Map<SyncRowID, PushRowOutcome> rowOutcomes;
    try {
      rowOutcomes = response.rowOutcomes;
    } on FormatException {
      return PushUnresolvedRows(submitted.keys.toSet());
    }
    final Set<SyncRowID> unresolved = <SyncRowID>{};
    for (final MapEntry<SyncRowID, _SubmittedPush> entry in submitted.entries) {
      final PushRowOutcome? rowOutcome = rowOutcomes[entry.key];
      if (rowOutcome == null || rowOutcome.siblingID != entry.value.siblingID) {
        unresolved.add(entry.key);
        continue;
      }
      switch (rowOutcome) {
        case PushApplied():
        case PushAlreadyPresent():
          await metadataStore.setAcknowledgedVector(
            entry.key,
            entry.value.vector,
          );
        case PushRejected():
          unresolved.add(entry.key);
          break;
      }
    }
    if (unresolved.isEmpty) {
      return PushFullyAcknowledged(submitted.keys.toSet());
    }
    return PushUnresolvedRows(unresolved);
  }
}

final class _SubmittedPush {
  const _SubmittedPush({required this.vector, required this.siblingID});

  final VersionVector vector;
  final String siblingID;
}

final class _PulledPage {
  const _PulledPage({required this.envelopes, required this.nextCursor});

  final List<SyncEnvelope> envelopes;
  final String nextCursor;
}

final class _RemoteProvenance {
  const _RemoteProvenance({
    required this.remoteWinner,
    required this.remoteWinnerChange,
  });

  final Map<SyncRowID, SyncEnvelope> remoteWinner;
  final Map<SyncRowID, LedgerChange> remoteWinnerChange;
}

final class _AttemptClassification {
  const _AttemptClassification({
    required this.directApplyCandidates,
    required this.foldInCandidates,
    required this.attemptRows,
  });

  final Set<SyncRowID> directApplyCandidates;
  final Set<SyncRowID> foldInCandidates;
  final Set<SyncRowID> attemptRows;
}

final class _AttemptSnapshot {
  const _AttemptSnapshot({
    required this.refreshedVersions,
    required this.refreshedContent,
  });

  final Map<SyncRowID, RowVersion?> refreshedVersions;
  final Map<SyncRowID, LedgerChange> refreshedContent;
}

final class _FoldInOutcome {
  const _FoldInOutcome({required this.excluded, required this.remoteEligible});

  final bool excluded;
  final Map<SyncRowID, VersionVector> remoteEligible;
}

sealed class _AttemptOutcome {
  const _AttemptOutcome();
}

final class _AttemptRetry extends _AttemptOutcome {
  const _AttemptRetry();
}

final class _AttemptEmpty extends _AttemptOutcome {
  const _AttemptEmpty();
}

final class _AttemptDone extends _AttemptOutcome {
  const _AttemptDone();
}

final class _FinalDecision {
  const _FinalDecision.raceDetected()
    : changes = const <LedgerChange>[],
      stamps = const <SyncRowID, VersionVector>{},
      raceDetected = true;

  _FinalDecision.commit({
    required List<LedgerChange> changes,
    required Map<SyncRowID, VersionVector> stamps,
  }) : changes = List.unmodifiable(changes),
       stamps = Map.unmodifiable(stamps),
       raceDetected = false;

  final List<LedgerChange> changes;
  final Map<SyncRowID, VersionVector> stamps;
  final bool raceDetected;
}
