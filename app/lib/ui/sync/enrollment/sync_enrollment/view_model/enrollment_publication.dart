part of '../sync_enrollment_view_model.dart';

// MARK: - Snapshot Publication

Future<void> _completeEnrollmentRepairIfProofPresent({
  required SyncEnrollmentSession session,
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required SecretStore secretStore,
  required bool Function() isMounted,
  required _EnrollmentStateUpdater updateState,
  required void Function(SyncEnrollmentStep step) emitStep,
  required Future<void> Function(Object, _EnrollmentOperation) failPhaseAware,
  required Future<void> Function(SyncEnrollmentSession, _EnrollmentOperation)
  publishUntilPublished,
}) async {
  final String? proof;
  try {
    proof = await secretStore.read(syncWriteProofSecretKey);
  } on Object catch (error) {
    await failPhaseAware(error, operation);
    return;
  }
  if (!isMounted() || !identical(operation, operations.currentOperation)) {
    return;
  }
  if (proof == null || proof.isEmpty) {
    updateState((current) => current.copyWith(errorMessage: () => null));
    emitStep(ShowEnrollmentCompleted());
    return;
  }
  await publishUntilPublished(session, operation);
}

Future<void> _publishEnrollmentUntilPublished({
  required SyncEnrollmentSession session,
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required bool Function() isMounted,
  required _EnrollmentStateUpdater updateState,
  required void Function(SyncEnrollmentStep step) emitStep,
  required Future<void> Function(Object, _EnrollmentOperation) failPhaseAware,
}) async {
  var attempts = 0;
  try {
    while (true) {
      final outcome = await session.publishSnapshot();
      if (!isMounted() || !identical(operation, operations.currentOperation)) {
        return;
      }
      if (outcome is EnrollmentSnapshotPublished) {
        updateState((current) => current.copyWith(errorMessage: () => null));
        emitStep(ShowEnrollmentCompleted());
        return;
      }
      attempts += 1;
      if (attempts >= SyncEnrollmentNotifier.maxPublishAttempts) {
        await failPhaseAware(
          const SyncEnrollmentException(
            step: 'publishSnapshot',
            code: 'snapshotPending',
            message: 'Snapshot publication is still pending. Please retry.',
          ),
          operation,
        );
        return;
      }
      await Future<void>.delayed(SyncEnrollmentNotifier._publishRetryDelay);
      if (!isMounted() || !identical(operation, operations.currentOperation)) {
        return;
      }
    }
  } on Object catch (error) {
    await failPhaseAware(error, operation);
  }
}

// MARK: - Abandoned Publication

Future<void> _publishAbandonedEnrollmentRepairProof({
  required SyncEnrollmentSession session,
  required _EnrollmentOperations operations,
  required Future<void> Function(SyncEnrollmentSession) runAbandonedPublication,
}) {
  final publication = runAbandonedPublication(session);
  operations.abandonedPublication = publication;
  return publication.whenComplete(() {
    if (identical(operations.abandonedPublication, publication)) {
      operations.abandonedPublication = null;
    }
  });
}

Future<void> _runAbandonedEnrollmentPublication({
  required SyncEnrollmentSession session,
  required SecretStore secretStore,
  required bool Function() isMounted,
  required Future<void> Function() refreshSyncStatus,
}) async {
  try {
    final proof = await secretStore.read(syncWriteProofSecretKey);
    if (proof != null && proof.isNotEmpty) {
      for (
        var attempt = 1;
        attempt <= SyncEnrollmentNotifier.maxPublishAttempts;
        attempt++
      ) {
        final outcome = await session.publishSnapshot();
        if (outcome is EnrollmentSnapshotPublished) break;
        if (attempt == SyncEnrollmentNotifier.maxPublishAttempts) break;
        await Future<void>.delayed(SyncEnrollmentNotifier._publishRetryDelay);
      }
    }
  } on Object catch (_) {}
  if (isMounted()) await refreshSyncStatus();
}
