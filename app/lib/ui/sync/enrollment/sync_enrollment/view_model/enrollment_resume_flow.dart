// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of '../sync_enrollment_view_model.dart';

// MARK: - Resume Flow

extension SyncEnrollmentResumeFlow on SyncEnrollmentNotifier {
  Future<void> _retryAfterStart(_EnrollmentOperation operation) async {
    try {
      await _abandonedPublication;
      final phase = await _currentPhase();
      if (!ref.mounted || !identical(operation, _currentOperation)) return;
      if (phase == SyncEnrollmentPhase.notEnrolled ||
          SyncEnrollmentFailureCopy._isRepairPhase(phase)) {
        if (_repairMode && SyncEnrollmentFailureCopy._isRepairPhase(phase)) {
          state = state.copyWith(repairPhase: () => phase);
        }
        emitStep(ShowIdentifierEntry());
        return;
      }
      emitStep(ShowProgressResume());
      await _resumeWithoutCredentials(operation);
    } finally {
      if (identical(operation, _currentOperation) && ref.mounted) {
        state = state.copyWith(inFlight: false);
      }
    }
    if (ref.mounted) await _refreshSyncStatus();
  }

  Future<void> _resumeWithoutCredentials(_EnrollmentOperation operation) async {
    final session = _session ?? await _reopenForResume(operation);
    if (!ref.mounted ||
        !identical(operation, _currentOperation) ||
        session == null) {
      return;
    }
    _session = session;
    try {
      await session.enroll();
    } on Object catch (error) {
      await _failPhaseAware(error, operation);
      return;
    }
    if (!ref.mounted || !identical(operation, _currentOperation)) return;
    if (_repairMode) {
      await _completeRepairIfProofPresent(session, operation);
      return;
    }
    await _publishUntilPublished(session, operation);
  }

  Future<SyncEnrollmentSession?> _reopenForResume(
    _EnrollmentOperation operation,
  ) async {
    final result = await _openSession(
      identifier: state.identifier,
      resolveOtp: _rejectUnexpectedOtp,
      operation: operation,
    );
    if (!ref.mounted ||
        !identical(operation, _currentOperation) ||
        result == null) {
      return null;
    }
    if (result is SyncEnrollmentSessionReady) return result.session;
    if (result is SyncEnrollmentSessionNotReady) {
      state = state.copyWith(
        errorMessage: () =>
            'Sync is not ready yet. Finish app start, then try again.',
      );
      return null;
    }
    state = state.copyWith(
      errorMessage: () =>
          'Hosted sync is not available right now. Please try again later.',
    );
    return null;
  }

  static Future<String> _rejectUnexpectedOtp(EnrollmentChallenge challenge) =>
      throw StateError(
        'OTP is not collected when resuming from a durable phase.',
      );
}
