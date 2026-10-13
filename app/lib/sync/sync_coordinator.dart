import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/store/device_identity.dart';
import 'package:spendwise/persistence/store/drift_ledger_store.dart'
    show PersistenceBarrierFailure;
import 'package:spendwise/persistence/database/ledger_database.dart'
    hide Account, SubPocket, Entry, Budget;
import 'package:spendwise/persistence/store/persistence_processor.dart';
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
import 'package:spendwise/sync/sync_repair_gate.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_run_scheduler.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:spendwise/sync/sync_status.dart';
import 'package:sync/sync.dart';

part 'coordinator/sync_coordinator_wiring.dart';
part 'coordinator/push_collection_results.dart';
part 'coordinator/coordinator_types.dart';
part 'coordinator/coordinator_bound_rpc.dart';
part 'coordinator/coordinator_pull.dart';
part 'coordinator/coordinator_push.dart';

// MARK: - Sync Coordinator

final class SyncCoordinator extends ChangeNotifier {
  SyncCoordinator._({
    required this.engine,
    required this.backend,
    required this.versionSource,
    required this.versionReader,
    required this.metadataStore,
    required this.verifier,
    required this._credentialProvider,
    required this.repairGate,
    required this._secretStore,
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

  // MARK: - Construction

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
    final SyncRepairGate repairGate = SyncRepairGate.forDatabase(database);
    await repairGate.reseed(snapshot);
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
      repairGate: repairGate,
      secretStore: effectiveSecrets,
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
    required this.repairGate,
    required this._secretStore,
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

  // MARK: - Fields

  final SyncEngine engine;

  final SyncBackend? backend;

  final SyncVersionSource versionSource;

  final CollectionVersionReader versionReader;

  final SyncMetadataStore metadataStore;

  final PostFlushReadbackVerifier verifier;

  final CredentialProvider _credentialProvider;

  final SyncRepairGate repairGate;

  final SecretStore _secretStore;

  final Ledger ledger;

  final PersistenceProcessor persistenceProcessor;

  final SyncStagingStore stagingStore;

  final PassFailureHandler? onPassFailure;

  final CollectionLock _lock = CollectionLock();

  SyncStatus _status;

  SyncStatus get status => _status;

  bool _disposed = false;

  late final SyncRunScheduler _scheduler;

  // MARK: - Scheduling

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

  // MARK: - Run Pass

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
}
