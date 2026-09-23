import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise/sync/enrollment_snapshot_publisher.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_backend_resolver.dart';
import 'package:spendwise/sync/sync_enrollment_composition.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:sync/sync.dart';

abstract interface class SyncEnrollmentSession {
  Future<void> enroll();

  Future<EnrollmentSnapshotPublishResult> publishSnapshot();
}

sealed class SyncEnrollmentSessionResult {
  const SyncEnrollmentSessionResult();
}

final class SyncEnrollmentSessionReady extends SyncEnrollmentSessionResult {
  const SyncEnrollmentSessionReady(this.session);

  final SyncEnrollmentSession session;
}

final class SyncEnrollmentSessionNotReady extends SyncEnrollmentSessionResult {
  const SyncEnrollmentSessionNotReady({
    required this.ledgerReady,
    required this.persistenceReady,
  });

  final bool ledgerReady;
  final bool persistenceReady;
}

final class SyncEnrollmentSessionConfigurationError
    extends SyncEnrollmentSessionResult {
  const SyncEnrollmentSessionConfigurationError(this.message);

  final String message;
}

typedef SyncEnrollmentSessionOpener =
    Future<SyncEnrollmentSessionResult> Function({
      required String identifier,
      required Future<String> Function(EnrollmentChallenge challenge)
      resolveOtp,
    });

final class _ComposedSyncEnrollmentSession implements SyncEnrollmentSession {
  _ComposedSyncEnrollmentSession(SyncEnrollmentReady ready)
    : _service = ready.enrollmentService,
      _publisher = ready.snapshotPublisher;

  final SyncEnrollmentService _service;
  final EnrollmentSnapshotPublisher _publisher;

  @override
  Future<void> enroll() => _service.enroll();

  @override
  Future<EnrollmentSnapshotPublishResult> publishSnapshot() =>
      _publisher.publish();
}

Future<SyncEnrollmentSessionResult> openSyncEnrollmentSession(
  Ref ref, {
  required String identifier,
  required Future<String> Function(EnrollmentChallenge challenge) resolveOtp,
  SupabaseConfig? Function()? supabaseConfigSource,
  http.Client? httpClient,
  SecretStore? secretStore,
}) async {
  final composition = await composeSyncEnrollment(
    ref,
    identifier: identifier,
    resolveOtp: resolveOtp,
    supabaseConfigSource: supabaseConfigSource,
    httpClient: httpClient,
    secretStore: secretStore,
  );
  return switch (composition) {
    SyncEnrollmentReady() => SyncEnrollmentSessionReady(
      _ComposedSyncEnrollmentSession(composition),
    ),
    SyncEnrollmentNotReady(:final ledgerReady, :final persistenceReady) =>
      SyncEnrollmentSessionNotReady(
        ledgerReady: ledgerReady,
        persistenceReady: persistenceReady,
      ),
    SyncEnrollmentConfigurationError(:final message) =>
      SyncEnrollmentSessionConfigurationError(message),
  };
}
