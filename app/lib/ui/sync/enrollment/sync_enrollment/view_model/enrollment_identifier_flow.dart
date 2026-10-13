part of '../sync_enrollment_view_model.dart';

// MARK: - Identifier Flow

Future<void> _submitEnrollmentAfterIdentifier({
  required String identifier,
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required bool Function() isMounted,
  required _EnrollmentStateUpdater updateState,
  required Future<void> Function(String, _EnrollmentOperation)
  enrollFromIdentifier,
  required Future<void> Function() refreshSyncStatus,
}) async {
  try {
    await operations.abandonedPublication;
    if (!identical(operation, operations.currentOperation)) return;
    await enrollFromIdentifier(identifier, operation);
  } finally {
    if (identical(operation, operations.currentOperation) && isMounted()) {
      updateState((current) => current.copyWith(inFlight: false));
    }
  }
  if (isMounted()) await refreshSyncStatus();
}

Future<void> _enrollWithIdentifier({
  required String identifier,
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required bool Function() isMounted,
  required bool Function() repairMode,
  required _EnrollmentStateUpdater updateState,
  required void Function(SyncEnrollmentStep step) emitStep,
  required void Function() noteCodeRequested,
  required Future<SyncEnrollmentSessionResult?> Function({
    required String identifier,
    required Future<String> Function(EnrollmentChallenge) resolveOtp,
    required _EnrollmentOperation operation,
  })
  openSession,
  required Future<void> Function(_EnrollmentOperation) refreshRepairPhase,
  required void Function(_EnrollmentOperation) enterCancelled,
  required Future<void> Function(Object, _EnrollmentOperation) failPhaseAware,
  required Future<void> Function(SyncEnrollmentSession)
  publishAbandonedRepairProof,
  required Future<void> Function(SyncEnrollmentSession, _EnrollmentOperation)
  completeRepairIfProofPresent,
  required Future<void> Function(SyncEnrollmentSession, _EnrollmentOperation)
  publishUntilPublished,
}) async {
  Future<String> resolveOtp(EnrollmentChallenge challenge) {
    if (!identical(operation, operations.currentOperation) ||
        operation.cancelled) {
      throw const SyncEnrollmentOtpCancelled();
    }
    noteCodeRequested();
    final otpCompleter = Completer<String>();
    operations.otpCompleter = otpCompleter;
    if (repairMode()) {
      updateState(
        (current) =>
            current.copyWith(explainCodeReplacement: true, otpWaiting: true),
      );
    } else {
      updateState((current) => current.copyWith(otpWaiting: true));
    }
    emitStep(ShowOtpEntry());
    return otpCompleter.future;
  }

  final SyncEnrollmentSessionResult? result = await openSession(
    identifier: identifier,
    resolveOtp: resolveOtp,
    operation: operation,
  );
  if (!isMounted() ||
      !identical(operation, operations.currentOperation) ||
      result == null) {
    return;
  }
  if (result is SyncEnrollmentSessionNotReady) {
    updateState(
      (current) => current.copyWith(
        errorMessage: () =>
            'Sync is not ready yet. Finish app start, then try again.',
      ),
    );
    return;
  }
  if (result is SyncEnrollmentSessionConfigurationError) {
    updateState(
      (current) => current.copyWith(
        errorMessage: () =>
            'Hosted sync is not available right now. Please try again later.',
      ),
    );
    return;
  }
  final session = (result as SyncEnrollmentSessionReady).session;
  operations.session = session;
  if (repairMode()) {
    await refreshRepairPhase(operation);
    if (!isMounted() || !identical(operation, operations.currentOperation)) {
      return;
    }
  }
  try {
    operations.pendingEnrolls++;
    await session.enroll();
  } on SyncEnrollmentOtpCancelled {
    enterCancelled(operation);
    return;
  } on Object catch (error) {
    await failPhaseAware(error, operation);
    return;
  } finally {
    operations.pendingEnrolls--;
  }
  if (!isMounted()) return;
  if (!identical(operation, operations.currentOperation)) {
    if (repairMode() && operations.currentOperation == null) {
      await publishAbandonedRepairProof(session);
    }
    return;
  }
  if (repairMode()) {
    await completeRepairIfProofPresent(session, operation);
    return;
  }
  await publishUntilPublished(session, operation);
}

// MARK: - Session Opening

Future<SyncEnrollmentSessionResult?> _openEnrollmentSession({
  required String identifier,
  required Future<String> Function(EnrollmentChallenge) resolveOtp,
  required _EnrollmentOperation operation,
  required SyncEnrollmentSessionOpener opener,
  required Future<void> Function(Object, _EnrollmentOperation) failPhaseAware,
}) async {
  try {
    return await opener(identifier: identifier, resolveOtp: resolveOtp);
  } on Object catch (error) {
    await failPhaseAware(error, operation);
    return null;
  }
}
