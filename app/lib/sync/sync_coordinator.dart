import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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
import 'package:spendwise/sync/sync_status.dart';
import 'package:sync/sync.dart';

/// Thrown when [Ledger.bus] and [PersistenceProcessor.bus] are not the same
/// instance: the coordinator can only forward stamped publications correctly
/// when both collaborators share one event bus.
final class SyncCoordinatorWiringException implements Exception {
  const SyncCoordinatorWiringException();

  @override
  String toString() =>
      'SyncCoordinatorWiringException: the ledger and the persistence '
      'processor must share one event bus; their bus instances differ.';
}

/// Assembles the sync collaborators into one owner.
///
/// [create] is the only place that awaits I/O. It takes an already-built
/// [Ledger] and [PersistenceProcessor] (never constructs or starts either),
/// resolves the enrolled backend, and constructs a real [SyncEngine] over the
/// durable staging store with the scoped E2E key accessor as its only
/// key-related dependency. The [CredentialProvider] is held privately and
/// never passed to the engine; there is deliberately no getter reaching it,
/// the [SecretStore], or any [DeviceCredential] from outside.
///
/// This slice owns assembly only: no run, scheduling, or trigger logic.
/// Population of the version cache ([CachedCollectionVersionSource.refresh]),
/// backend calls, and [PersistenceProcessor.start] all belong to later
/// slices, so [status] stays [SyncIdle].
final class SyncCoordinator {
  SyncCoordinator._({
    required this.engine,
    required this.backend,
    required this.versionSource,
    required this.metadataStore,
    required this.verifier,
    required this._credentialProvider,
    required this.ledger,
    required this.persistenceProcessor,
    required this.stagingStore,
  }) : _status = const SyncIdle();

  /// Assembles a coordinator over already-constructed collaborators.
  ///
  /// Throws [SyncCoordinatorWiringException] before any I/O when the ledger
  /// and the persistence processor do not share one event bus. The caller
  /// must also ensure the processor's store is backed by [database]; no
  /// accessor exists on [LedgerStore] to check that at runtime.
  static Future<SyncCoordinator> create({
    required LedgerDatabase database,
    required Ledger ledger,
    required PersistenceProcessor persistenceProcessor,
    SupabaseConfig? supabaseConfig,
    http.Client? httpClient,
    SecretStore? secretStore,
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
      metadataStore: metadataStore,
      verifier: PostFlushReadbackVerifier(reader),
      credentialProvider: credentialProvider,
      ledger: ledger,
      persistenceProcessor: persistenceProcessor,
      stagingStore: staging,
    );
  }

  /// Test-only assembly over already-constructed collaborators.
  ///
  /// Mirrors [SyncCoordinator._] exactly so a test can inject a fake
  /// [SyncBackend], an [InMemorySyncVersionSource], and a stubbed
  /// [CredentialProvider] without touching the network or secure storage.
  /// [versionSource] is typed to the [SyncVersionSource] interface (not the
  /// concrete cache) for the same reason.
  @visibleForTesting
  SyncCoordinator.forTesting({
    required this.engine,
    required this.backend,
    required this.versionSource,
    required this.metadataStore,
    required this.verifier,
    required this._credentialProvider,
    required this.ledger,
    required this.persistenceProcessor,
    required this.stagingStore,
  }) : _status = const SyncIdle();

  /// Bounds the fold-in retry loop in [_processPullPageLocked]. A fence
  /// invalidation or a Stage-4 race detection retries the whole attempt with
  /// a freshly refreshed classification; after this many attempts the page
  /// defers untouched, leaving the next pull cycle to retry fresh.
  static const int _maxFoldInAttempts = 3;

  /// The real sync engine, keyed by [deviceID] with the scoped E2E accessor.
  final SyncEngine engine;

  /// The resolved backend, or null when the device never enrolled.
  final SyncBackend? backend;

  /// Empty until the run slice calls [CachedCollectionVersionSource.refresh].
  final SyncVersionSource versionSource;

  final SyncMetadataStore metadataStore;

  final PostFlushReadbackVerifier verifier;

  /// Held for the run slice, which spends credentials during pulls.
  /// Intentionally unexposed: no getter may leak secrets or credentials.
  final CredentialProvider _credentialProvider; // ignore: unused_field

  final Ledger ledger;

  final PersistenceProcessor persistenceProcessor;

  /// The durable staging store the engine stages conflicts into. Held
  /// directly (not only inside [engine]) so the pull path can flush staged
  /// writes to durability itself: once before advancing page metadata, and
  /// once on every exit path as an unavoidable choke point.
  final SyncStagingStore stagingStore;

  /// Serializes concurrent pull and acknowledgement work per collection.
  /// Different collections still run fully concurrently. The lock never
  /// poisons: a throwing body propagates to its caller only.
  final CollectionLock _lock = CollectionLock();

  final SyncStatus _status;

  SyncStatus get status => _status;

  /// Whether a pulled row version is already covered locally.
  ///
  /// True when [stored] exists and its vector causally dominates [pulled],
  /// including the reflexive equal-vector case ([VersionVector.dominates] is
  /// reflexive). A null [stored] (row never seen locally) is never covered.
  static bool _isDuplicateOrDominated(
    RowVersion? stored,
    VersionVector pulled,
  ) => stored != null && stored.versionVector.dominates(pulled);

  /// Processes one pulled page for [collection], serialized per collection.
  ///
  /// Holds [_lock] for [collection] and delegates to [_processPullPageLocked],
  /// so two overlapping pulls (or a pull overlapping acknowledgement
  /// recovery) for the same collection run one at a time instead of
  /// interleaving their retry loops.
  Future<void> processPullPage(SyncCollection collection) =>
      _lock.withLock(collection, () => _processPullPageLocked(collection));

  /// Pulls at the current watermark, reconciles, folds local content in, and
  /// — for rows that survive linearization and readback verification —
  /// applies the batch and durably advances the watermark with the verified
  /// vectors.
  ///
  /// Each attempt redoes classification fresh against a refreshed
  /// [versionSource]: duplicate or dominated rows are skipped, unseen rows
  /// become direct-apply candidates, and concurrently-versioned rows become
  /// fold-in candidates whose current local content is reconciled against the
  /// pulled winner two-inputs-at-a-time (the local envelope is always input
  /// index 1, and [ReconcileResult.winningInputIndex] maps the outcome back
  /// without any content or vector equality inference). One [MutationFence]
  /// spans the whole attempt, so a local edit landing in any await window —
  /// the persistence barrier, the second refresh, or a fold-in reconcile —
  /// retries instead of being silently overwritten.
  ///
  /// The final commit decision and [Ledger.applySyncBatch] run back to back
  /// with zero await between them, so no concurrent edit can slip in after
  /// the last race check. A verified batch is flushed again, read back from
  /// storage, and only then acknowledged durably; any verification failure
  /// stops the whole batch before any metadata moves. Retry exhaustion
  /// defers silently without touching the watermark, and a
  /// [PersistenceBarrierFailure] stops the whole page the same way. Every
  /// exit path settles staged conflicts through [stagingStore.flush], and
  /// [stagingStore.flush] always completes strictly before
  /// [SyncMetadataStore.recordPulledPage] begins.
  Future<void> _processPullPageLocked(SyncCollection collection) async {
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
    final String nextCursor = response.cursor;

    try {
      // Remote-only reconciliation, run once per page. Stages remote-vs-remote
      // conflicts as an unconditional side effect; a mid-decode throw can
      // leave an earlier row's conflict staged, which the outer finally below
      // still guarantees durable.
      final ReconcileResult remoteResult = await engine.reconcile(envelopes);
      // The pulled winner envelope per conflict-free row, located by the
      // index-based provenance: the coordinator passed the pulled envelopes
      // in order, so the winning input index addresses this list directly.
      final Map<SyncRowID, SyncEnvelope> remoteWinner =
          <SyncRowID, SyncEnvelope>{};
      for (final MapEntry<SyncRowID, int> entry
          in remoteResult.winningInputIndex.entries) {
        final int index = entry.value;
        if (index < 0 || index >= envelopes.length) continue;
        remoteWinner[entry.key] = envelopes[index];
      }
      // The winner change per conflict-free row, for the commit decision to
      // apply without re-decoding.
      final Map<SyncRowID, LedgerChange> remoteWinnerChange =
          <SyncRowID, LedgerChange>{};
      for (final LedgerChange change in remoteResult.changes) {
        remoteWinnerChange[SyncRowID.of(
              collectionFor(change),
              change.targetID,
            )] =
            change;
      }

      var applied = false;
      var everyAttemptWasEmptyAttemptRows = false;

      for (var attempt = 1; attempt <= _maxFoldInAttempts; attempt += 1) {
        final MutationFence fence = MutationFence(ledger.bus)..install();
        // The finally below uninstalls exactly once on every path after
        // install: break, continue, return, or a throw from refresh, the
        // barrier flush, encode, reconcile, apply, verification, or metadata.
        // No path inside uninstalls explicitly, so a retained listener is
        // impossible and a double uninstall cannot happen.
        try {
          final int epoch = fence.snapshot();

          await versionSource.refresh();
          // Classification is redone fresh every iteration, so a direct-apply
          // row that gains a version mid-attempt is automatically reclassified
          // (usually into fold-in) on the next pass.
          final Set<SyncRowID> directApplyCandidates = <SyncRowID>{};
          final Set<SyncRowID> foldInCandidates = <SyncRowID>{};
          for (final MapEntry<SyncRowID, VersionVector> entry
              in remoteResult.stamps.entries) {
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
          if (attemptRows.isEmpty) {
            everyAttemptWasEmptyAttemptRows = true;
            break;
          }

          // The barrier lands every debounced local edit before the second
          // refresh, so the versions and content below observe them.
          await persistenceProcessor.flush();
          await versionSource.refresh();
          if (!fence.checkClean(epoch)) {
            continue;
          }

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

          // A defensive fold-in skip (a missing winner envelope, missing
          // local content, an off-contract encode result, or a winner without
          // a stamp) races the whole attempt, like a Stage-4 exclusion: every
          // fold-in candidate provably carries all of these, so an absence is
          // a breach, never a row to skip past.
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
            final List<SyncEnvelope> encoded = await engine.encode(
              <LedgerChange>[local],
              versionSource,
            );
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
                // The pulled winner causally supersedes the local content:
                // eligible for apply under its pulled stamp.
                final VersionVector? stamp = foldInResult.stamps[row];
                if (stamp == null) {
                  foldInExcluded = true;
                } else {
                  remoteEligible[row] = stamp;
                }
              case 1:
                // The local input survived: a concurrent edit landed and now
                // dominates, so this row is neither applied nor acknowledged.
                break;
              case null:
                // A multi-member frontier: reconcile() staged the conflict
                // itself, so there is nothing to apply for this row.
                break;
            }
          }
          if (foldInExcluded) {
            continue;
          }

          final _FinalDecision decision = _finalizeSynchronously(
            directApplyCandidates: directApplyCandidates,
            remoteEligible: remoteEligible,
            remoteWinnerChange: remoteWinnerChange,
            remoteStamps: remoteResult.stamps,
            refreshedVersions: refreshedVersions,
            fence: fence,
            epoch: epoch,
          );
          if (decision.raceDetected) {
            continue;
          }

          // Zero await between the decision above and this apply: the commit
          // decision and the batch land as one linearization step, so a
          // concurrent edit cannot slip in after the last race check. The
          // fence stays installed across the apply; its epoch is already
          // decided and our own publication needs no observation.
          if (decision.changes.isNotEmpty) {
            ledger.applySyncBatch(decision.changes, decision.stamps);
          }
          applied = true;

          if (decision.changes.isNotEmpty) {
            await persistenceProcessor.flush();
            final Map<SyncRowID, RowReadbackOutcome> outcomes = await verifier
                .verify(decision.stamps);
            if (outcomes.values.any((result) => !result.passed)) return;
          }

          await _finalizeAndMaybeAcknowledge(
            collection,
            stamps: decision.stamps,
            watermark: nextCursor,
            checkpoint: nextCursor,
          );
          return;
        } finally {
          await fence.uninstall();
        }
      }

      if (!applied) {
        if (everyAttemptWasEmptyAttemptRows) {
          await _finalizeAndMaybeAcknowledge(
            collection,
            stamps: const <SyncRowID, VersionVector>{},
            watermark: nextCursor,
            checkpoint: nextCursor,
          );
        }
        // Else the retry budget is exhausted: pure defer, return silently
        // without advancing anything; the next pull cycle retries fresh.
      }
    } on PersistenceBarrierFailure {
      // A persistence-layer failure is not a transient race: hard-stop the
      // whole page. Staging still settles through the choke point below.
      return;
    } finally {
      // Single unavoidable choke point: covers the initial reconcile() call
      // itself and every abort, defer, and failure exit after it.
      await stagingStore.flush();
    }
  }

  /// Runs the Stage-4 linearization synchronously, with zero await inside.
  ///
  /// Any exclusion of an attempt row races the whole attempt: a direct-apply
  /// row whose version no longer reads null (a local creation raced the
  /// attempt), a fold-in remote-eligible row whose version no longer equals
  /// what fold-in reconciled against, or a missing remote change or stamp
  /// (a contract breach, since every attempt row is conflict-free and must
  /// carry both). Committing a surviving sibling while skipping another row
  /// would advance the watermark past a row whose fate is undecided, so the
  /// attempt retries instead, and defers if the budget exhausts. Returns a
  /// race as well when nothing survives, even with a clean fence.
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

  /// Settles staged conflicts and then commits the page durably in one step.
  ///
  /// [stagingStore.flush] must complete strictly before [recordPulledPage]
  /// begins: the watermark may only advance over staged rows once their
  /// conflicts are durable, independently of the readback gate that already
  /// ran.
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

  /// Rebuilds the [LedgerChange] describing [row]'s current local content in
  /// [state], for the fold-in encode step.
  ///
  /// Mirrors [CollectionVersionReader]'s tombstone classification: a
  /// tombstoned money source, category, or entry produces the corresponding
  /// delete change rather than an upsert of stale content, and a row absent
  /// from the live tables entirely (locally deleted, hence tracked only as a
  /// durable tombstone) does the same. Plans and budgets carry no lifecycle
  /// of their own, so a present row is always live content. The money-sources
  /// collection funnels through [LedgerChange.upsertSource], which already
  /// maps the dual account/pocket entity onto its change.
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

  /// Retries every durable pending collection-checkpoint acknowledgement.
  ///
  /// Each collection dispatches under [_lock], so recovery for a collection
  /// never interleaves with that collection's pull loop. Before calling
  /// [SyncBackend.acknowledge], the collection's staged conflicts are re-read
  /// durably: while any conflict in the collection is unresolved the pending
  /// checkpoint is left in place for a later pass, since acknowledging past
  /// an unreviewed conflict would drop the server's duty to keep serving it.
  ///
  /// Reads [SyncMetadataStore.pendingAcknowledgements] and replays each
  /// stored checkpoint through [SyncBackend.acknowledge]. A confirmed
  /// [SyncSuccess] clears that collection's pending record only if its
  /// stored checkpoint still equals the one just acknowledged, so a newer
  /// checkpoint recorded concurrently (for example by [processPullPage])
  /// is never lost. Any [SyncFailure] leaves the pending record durable
  /// for the next recovery pass, without throwing and without blocking the
  /// remaining collections. Retry scheduling belongs to a later slice: a
  /// failed collection is simply left in place for the next invocation.
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

  /// Acknowledges one collection's pending [checkpoint] unless a staged
  /// conflict in [collection] still blocks it.
  Future<void> _recoverOneAcknowledgement(
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
}

/// The outcome of one Stage-4 linearization: either a detected race, which
/// retries the attempt, or a commit carrying the surviving changes with
/// their per-row stamps for the immediate [Ledger.applySyncBatch].
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
