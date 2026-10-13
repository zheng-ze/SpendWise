part of '../sync_enrollment_view_model.dart';

// MARK: - Resume Flow

Future<void> _retryEnrollmentAfterStart({
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required bool Function() isMounted,
  required bool Function() repairMode,
  required _EnrollmentStateUpdater updateState,
  required void Function(SyncEnrollmentStep step) emitStep,
  required Future<SyncEnrollmentPhase> Function() currentPhase,
  required Future<void> Function(_EnrollmentOperation) resumeWithoutCredentials,
  required Future<void> Function() refreshSyncStatus,
}) async {
  try {
    await operations.abandonedPublication;
    final phase = await currentPhase();
    if (!isMounted() || !identical(operation, operations.currentOperation)) {
      return;
    }
    if (phase == SyncEnrollmentPhase.notEnrolled || _isRepairPhase(phase)) {
      if (repairMode() && _isRepairPhase(phase)) {
        updateState((current) => current.copyWith(repairPhase: () => phase));
      }
      emitStep(ShowIdentifierEntry());
      return;
    }
    emitStep(ShowProgressResume());
    await resumeWithoutCredentials(operation);
  } finally {
    if (identical(operation, operations.currentOperation) && isMounted()) {
      updateState((current) => current.copyWith(inFlight: false));
    }
  }
  if (isMounted()) await refreshSyncStatus();
}

Future<void> _resumeEnrollmentWithoutCredentials({
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required bool Function() isMounted,
  required bool Function() repairMode,
  required Future<SyncEnrollmentSession?> Function(_EnrollmentOperation)
  reopenForResume,
  required Future<void> Function(Object, _EnrollmentOperation) failPhaseAware,
  required Future<void> Function(SyncEnrollmentSession, _EnrollmentOperation)
  completeRepairIfProofPresent,
  required Future<void> Function(SyncEnrollmentSession, _EnrollmentOperation)
  publishUntilPublished,
}) async {
  final session = operations.session ?? await reopenForResume(operation);
  if (!isMounted() ||
      !identical(operation, operations.currentOperation) ||
      session == null) {
    return;
  }
  operations.session = session;
  try {
    await session.enroll();
  } on Object catch (error) {
    await failPhaseAware(error, operation);
    return;
  }
  if (!isMounted() || !identical(operation, operations.currentOperation)) {
    return;
  }
  if (repairMode()) {
    await completeRepairIfProofPresent(session, operation);
    return;
  }
  await publishUntilPublished(session, operation);
}

Future<SyncEnrollmentSession?> _reopenEnrollmentForResume({
  required String identifier,
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required bool Function() isMounted,
  required _EnrollmentStateUpdater updateState,
  required Future<SyncEnrollmentSessionResult?> Function({
    required String identifier,
    required Future<String> Function(EnrollmentChallenge) resolveOtp,
    required _EnrollmentOperation operation,
  })
  openSession,
}) async {
  final result = await openSession(
    identifier: identifier,
    resolveOtp: _rejectUnexpectedOtp,
    operation: operation,
  );
  if (!isMounted() ||
      !identical(operation, operations.currentOperation) ||
      result == null) {
    return null;
  }
  if (result is SyncEnrollmentSessionReady) return result.session;
  if (result is SyncEnrollmentSessionNotReady) {
    updateState(
      (current) => current.copyWith(
        errorMessage: () =>
            'Sync is not ready yet. Finish app start, then try again.',
      ),
    );
    return null;
  }
  updateState(
    (current) => current.copyWith(
      errorMessage: () =>
          'Hosted sync is not available right now. Please try again later.',
    ),
  );
  return null;
}

Future<String> _rejectUnexpectedOtp(EnrollmentChallenge challenge) =>
    throw StateError(
      'OTP is not collected when resuming from a durable phase.',
    );
