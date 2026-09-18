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

  /// The real sync engine, keyed by [deviceID] with the scoped E2E accessor.
  final SyncEngine engine;

  /// The resolved backend, or null when the device never enrolled.
  final SyncBackend? backend;

  /// Empty until the run slice calls [CachedCollectionVersionSource.refresh].
  final CachedCollectionVersionSource versionSource;

  final SyncMetadataStore metadataStore;

  final PostFlushReadbackVerifier verifier;

  /// Held for the run slice, which spends credentials during pulls.
  /// Intentionally unexposed: no getter may leak secrets or credentials.
  final CredentialProvider _credentialProvider; // ignore: unused_field

  final Ledger ledger;

  final PersistenceProcessor persistenceProcessor;

  final SyncStatus _status;

  SyncStatus get status => _status;
}
