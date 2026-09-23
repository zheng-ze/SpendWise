import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/sync/enrollment_snapshot_publisher.dart';
import 'package:spendwise/sync/reconciliation_snapshot_hasher.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_backend_resolver.dart';
import 'package:spendwise/sync/sync_coordinator.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:sync/sync.dart';

sealed class SyncEnrollmentComposition {
  const SyncEnrollmentComposition();
}

final class SyncEnrollmentReady extends SyncEnrollmentComposition {
  const SyncEnrollmentReady({
    required this.backend,
    required this.authenticator,
    required this.enrollmentService,
    required this.coordinator,
    required this.snapshotPublisher,
    required this.secretStore,
  });

  final SyncBackend backend;
  final SupabaseSyncAuthenticator authenticator;
  final SyncEnrollmentService enrollmentService;
  final SyncCoordinator coordinator;
  final EnrollmentSnapshotPublisher snapshotPublisher;
  final SecretStore secretStore;
}

final class SyncEnrollmentNotReady extends SyncEnrollmentComposition {
  const SyncEnrollmentNotReady({
    required this.ledgerReady,
    required this.persistenceReady,
  });

  final bool ledgerReady;
  final bool persistenceReady;
}

final class SyncEnrollmentConfigurationError extends SyncEnrollmentComposition {
  const SyncEnrollmentConfigurationError(this.message, {this.cause});

  final String message;
  final Object? cause;
}

Future<Uint8List> resolveProductionSyncE2EKey() async {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(SyncCipher.keyByteCount, (_) => random.nextInt(256)),
  );
}

Future<SyncEnrollmentComposition> composeSyncEnrollment(
  Ref ref, {
  required String identifier,
  required Future<String> Function(EnrollmentChallenge challenge) resolveOtp,
  Future<Uint8List> Function()? resolveE2EKey,
  SecretStore? secretStore,
  SupabaseConfig? Function()? supabaseConfigSource,
  http.Client? httpClient,
}) async {
  final ledger = ref.read(ledgerProvider);
  final persistence = ref.read(persistenceProcessorProvider);
  if (ledger == null || persistence == null) {
    return SyncEnrollmentNotReady(
      ledgerReady: ledger != null,
      persistenceReady: persistence != null,
    );
  }
  final database = ref.read(ledgerDatabaseProvider);
  final metadataStore = ref.read(syncMetadataStoreProvider);
  final snapshot = await metadataStore.snapshot();
  if (snapshot.backend != SyncBackendKind.supabase) {
    return const SyncEnrollmentConfigurationError(
      'Hosted enrollment requires the persisted supabase backend selection.',
    );
  }
  final config = (supabaseConfigSource ?? SupabaseConfig.fromEnvironment)();
  if (config == null) {
    return const SyncEnrollmentConfigurationError(
      'Hosted enrollment requires a Supabase configuration.',
    );
  }
  final SyncBackend backend;
  try {
    final resolved = const SyncBackendResolver().resolve(
      snapshot,
      supabaseConfig: config,
      httpClient: httpClient,
    );
    if (resolved == null) {
      return const SyncEnrollmentConfigurationError(
        'Hosted enrollment requires the persisted supabase backend selection.',
      );
    }
    backend = resolved;
  } on SyncBackendConfigurationException catch (error) {
    return SyncEnrollmentConfigurationError(error.message, cause: error);
  }
  final sharedSecrets = secretStore ?? SecureSecretStore();
  final authenticator = SupabaseSyncAuthenticator(
    projectUrl: config.projectUrl,
    anonKey: config.anonKey,
    client: httpClient,
  );
  final enrollmentService = SyncEnrollmentService(
    authenticator: authenticator,
    backend: backend,
    metadataStore: metadataStore,
    secretStore: sharedSecrets,
    database: database,
    buildBeginRequest: () =>
        BeginEnrollmentRequest(<String, Object?>{'identifier': identifier}),
    buildCompleteRequest: (challenge) async {
      final otp = await resolveOtp(challenge);
      return CompleteEnrollmentRequest(<String, Object?>{
        'identifier': challenge.wire['identifier'],
        'otp': otp,
        'deviceId': await deviceID(database),
      });
    },
    resolveE2EKey: resolveE2EKey ?? resolveProductionSyncE2EKey,
    buildSnapshotHasher: (credential) =>
        ReconciliationSnapshotHasher(backend: backend, credential: credential),
  );
  final SyncCoordinator coordinator;
  try {
    coordinator = await SyncCoordinator.create(
      database: database,
      ledger: ledger,
      persistenceProcessor: persistence,
      supabaseConfig: config,
      httpClient: httpClient,
      secretStore: sharedSecrets,
    );
  } on SyncBackendConfigurationException catch (error) {
    return SyncEnrollmentConfigurationError(error.message, cause: error);
  }
  final reselected = await metadataStore.snapshot();
  if (reselected.backend != snapshot.backend ||
      reselected.endpoint != snapshot.endpoint) {
    return const SyncEnrollmentConfigurationError(
      'The persisted sync backend selection changed during enrollment composition.',
    );
  }
  if (coordinator.backend is! SupabaseSyncBackend) {
    return const SyncEnrollmentConfigurationError(
      'Hosted enrollment requires the persisted supabase backend selection.',
    );
  }
  return SyncEnrollmentReady(
    backend: backend,
    authenticator: authenticator,
    enrollmentService: enrollmentService,
    coordinator: coordinator,
    snapshotPublisher: EnrollmentSnapshotPublisher(
      coordinator: coordinator,
      secretStore: sharedSecrets,
    ),
    secretStore: sharedSecrets,
  );
}
