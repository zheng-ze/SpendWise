import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:spendwise/sync/cached_collection_version_source.dart';
import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:spendwise/sync/credential_provider.dart';
import 'package:spendwise/sync/drift_sync_staging_store.dart';
import 'package:spendwise/sync/post_flush_readback_verifier.dart';
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
  }) : _status = const SyncIdle();

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

  /// Processes one pulled page for [collection].
  ///
  /// Pulls from the current watermark, reconciles the page, and — when every
  /// row is duplicate or already-dominated — durably advances the watermark
  /// and pending acknowledgement with an empty vectors map. This branch
  /// publishes nothing to [Ledger.bus] and enqueues nothing to the
  /// persistence store. A page with a new row or a staged conflict commits
  /// nothing further; the engine's own (idempotent) conflict staging from
  /// [SyncEngine.reconcile] still stands. A failed pull, or a returned
  /// envelope declaring a collection other than [collection], throws
  /// [StateError]; retry classification belongs to a later slice.
  Future<void> processPullPage(SyncCollection collection) async {
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
    final ReconcileResult result = await engine.reconcile(envelopes);
    // The production cache starts empty and only populates via refresh();
    // without this every row would read as unseen and misclassify. The
    // in-memory test fake has no refresh and is pre-populated directly, so
    // refresh only when the concrete source supports it. Reads stay typed to
    // the SyncVersionSource interface; no new abstraction is introduced.
    final SyncVersionSource source = versionSource;
    if (source is CachedCollectionVersionSource) {
      await source.refresh();
    }
    final bool allDuplicateOrDominated =
        result.stagedConflicts.isEmpty &&
        result.stamps.entries.every(
          (entry) => _isDuplicateOrDominated(
            versionSource.readRowVersion(entry.key),
            entry.value,
          ),
        );
    if (!allDuplicateOrDominated) return;
    await metadataStore.recordPulledPage(
      collection: collection,
      vectors: const <SyncRowID, VersionVector>{},
      watermark: nextCursor,
      checkpoint: nextCursor,
    );
  }

  /// Retries every durable pending collection-checkpoint acknowledgement.
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
      final SyncOutcome<AcknowledgeResponse> outcome = await _credentialProvider
          .withCredential(
            (DeviceCredential credential) => backend.acknowledge(
              credential,
              AcknowledgeRequest(
                collection: entry.key,
                checkpoint: entry.value,
              ),
            ),
          );
      switch (outcome) {
        case SyncSuccess<AcknowledgeResponse>():
          await metadataStore.clearPendingAcknowledgementIfMatches(
            entry.key,
            entry.value,
          );
        case SyncFailure<AcknowledgeResponse>():
          continue;
      }
    }
  }
}
