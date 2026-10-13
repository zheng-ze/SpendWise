// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of '../sync_enrollment_view_model.dart';

// MARK: - Identifier Flow

extension SyncEnrollmentIdentifierFlow on SyncEnrollmentNotifier {
  Future<void> _submitAfterIdentifier(
    String identifier,
    _EnrollmentOperation operation,
  ) async {
    try {
      await _abandonedPublication;
      if (!identical(operation, _currentOperation)) return;
      await _enrollFromIdentifier(identifier, operation);
    } finally {
      if (identical(operation, _currentOperation) && ref.mounted) {
        state = state.copyWith(inFlight: false);
      }
    }
    if (ref.mounted) await _refreshSyncStatus();
  }

  Future<void> _enrollFromIdentifier(
    String identifier,
    _EnrollmentOperation operation,
  ) async {
    Future<String> resolveOtp(EnrollmentChallenge challenge) {
      if (!identical(operation, _currentOperation) || operation.cancelled) {
        throw const SyncEnrollmentOtpCancelled();
      }
      // The challenge issues the code, so the cooldown starts here.
      _noteCodeRequested();
      final otpCompleter = Completer<String>();
      _otpCompleter = otpCompleter;
      if (_repairMode) {
        state = state.copyWith(explainCodeReplacement: true, otpWaiting: true);
      } else {
        state = state.copyWith(otpWaiting: true);
      }
      emitStep(ShowOtpEntry());
      return otpCompleter.future;
    }

    final SyncEnrollmentSessionResult? result = await _openSession(
      identifier: identifier,
      resolveOtp: resolveOtp,
      operation: operation,
    );
    if (!ref.mounted ||
        !identical(operation, _currentOperation) ||
        result == null) {
      return;
    }
    if (result is SyncEnrollmentSessionNotReady) {
      state = state.copyWith(
        errorMessage: () =>
            'Sync is not ready yet. Finish app start, then try again.',
      );
      return;
    }
    if (result is SyncEnrollmentSessionConfigurationError) {
      state = state.copyWith(
        errorMessage: () =>
            'Hosted sync is not available right now. Please try again later.',
      );
      return;
    }
    final session = (result as SyncEnrollmentSessionReady).session;
    _session = session;
    if (_repairMode) {
      await _refreshRepairPhase(operation);
      if (!ref.mounted || !identical(operation, _currentOperation)) return;
    }
    try {
      _pendingEnrolls++;
      await session.enroll();
    } on SyncEnrollmentOtpCancelled {
      _enterCancelled(operation);
      return;
    } on Object catch (error) {
      await _failPhaseAware(error, operation);
      return;
    } finally {
      _pendingEnrolls--;
    }
    if (!ref.mounted) return;
    if (!identical(operation, _currentOperation)) {
      if (_repairMode && _currentOperation == null) {
        await _publishAbandonedRepairProof(session);
      }
      return;
    }
    if (_repairMode) {
      await _completeRepairIfProofPresent(session, operation);
      return;
    }
    await _publishUntilPublished(session, operation);
  }

  // MARK: - Session Opening

  Future<SyncEnrollmentSessionResult?> _openSession({
    required String identifier,
    required Future<String> Function(EnrollmentChallenge challenge) resolveOtp,
    required _EnrollmentOperation operation,
  }) async {
    try {
      return await _opener(identifier: identifier, resolveOtp: resolveOtp);
    } on Object catch (error) {
      await _failPhaseAware(error, operation);
      return null;
    }
  }
}
