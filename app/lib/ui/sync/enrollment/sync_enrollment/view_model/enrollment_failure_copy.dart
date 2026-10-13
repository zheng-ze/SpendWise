// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of '../sync_enrollment_view_model.dart';

// MARK: - Phase-Aware Failure

extension SyncEnrollmentFailureCopy on SyncEnrollmentNotifier {
  void _enterCancelled(_EnrollmentOperation operation) {
    if (!identical(operation, _currentOperation)) return;
    _otpCompleter = null;
    _session = null;
    state = state.copyWith(
      errorMessage: () => null,
      cancelled: true,
      otpWaiting: false,
    );
    emitStep(ShowIdentifierEntry());
  }

  Future<void> _failPhaseAware(
    Object error,
    _EnrollmentOperation operation,
  ) async {
    if (!identical(operation, _currentOperation)) return;
    final message = _failureCopy(error);
    _extendCooldownFrom(error, operation);
    final phase = await _currentPhase();
    if (!ref.mounted || !identical(operation, _currentOperation)) return;
    state = state.copyWith(
      errorMessage: () => message,
      repairPhase: _repairMode && _isRepairPhase(phase) ? () => phase : null,
    );
    if (phase == SyncEnrollmentPhase.notEnrolled || _isRepairPhase(phase)) {
      emitStep(ShowIdentifierEntry());
    } else {
      emitStep(ShowProgressResume());
    }
  }

  Future<void> _refreshRepairPhase(_EnrollmentOperation operation) async {
    final phase = await _currentPhase();
    if (!ref.mounted || !identical(operation, _currentOperation)) return;
    if (_isRepairPhase(phase)) {
      state = state.copyWith(repairPhase: () => phase);
    }
  }

  Future<void> _refreshSyncStatus() async {
    try {
      await ref.read(appBootProvider).refreshSyncStatus();
    } catch (_) {}
  }

  Future<SyncEnrollmentPhase> _currentPhase() async {
    final snapshot = await ref.read(syncMetadataStoreProvider).snapshot();
    return snapshot.phase;
  }

  static bool _isRepairPhase(SyncEnrollmentPhase phase) =>
      phase == SyncEnrollmentPhase.bindingAuthorizationRequired ||
      phase == SyncEnrollmentPhase.sessionReauthRequired;

  // MARK: - Cooldown

  Duration? _codeCooldownRemaining() {
    final endsAt = state.codeCooldownEndsAt;
    if (endsAt == null) return null;
    final remaining = endsAt.difference(_now());
    return remaining.isNegative ? null : remaining;
  }

  void _noteCodeRequested() {
    if (!ref.mounted) return;
    state = state.copyWith(
      codeCooldownEndsAt: () =>
          _now().add(SyncEnrollmentNotifier.codeRequestCooldown),
    );
  }

  void _extendCooldownFrom(Object error, _EnrollmentOperation operation) {
    if (!identical(operation, _currentOperation)) return;
    final retryAfter = error is SyncEnrollmentException
        ? error.retryAfter
        : null;
    if (retryAfter == null) return;
    final candidate = _now().add(retryAfter);
    final current = state.codeCooldownEndsAt;
    if (current == null || candidate.isAfter(current)) {
      state = state.copyWith(codeCooldownEndsAt: () => candidate);
    }
  }

  static int _ceilSeconds(Duration remaining) {
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    return seconds < 1 ? 1 : seconds;
  }

  // MARK: - Failure Copy

  String _failureCopy(Object error) {
    if (error is SyncEnrollmentException) {
      final base = _copyForCode(error.code);
      final retryAfter = error.retryAfter;
      if (retryAfter == null) return base;
      return '$base ${_waitCopy(retryAfter)}';
    }
    return _repairMode
        ? 'Repair failed. Please try again.'
        : 'Enrollment failed. Please try again.';
  }

  String _copyForCode(String code) {
    switch (code) {
      case 'rate_limited':
        return 'Too many codes were requested.';
      case 'invalid_request':
        return _repairMode
            ? 'The code was not accepted. Enter the latest code from your email.'
            : 'The request was not accepted. Please try again.';
      case 'credential_expired':
        return 'The sign-in expired. Enter your email to get a new code.';
      case 'device_authorization_required':
        return 'This device needs authorization again. '
            'Enter your email to get a new code.';
      case 'network_unavailable':
      case 'backend_unavailable':
        return 'The sync service is unreachable. '
            'Check your connection and try again.';
      case 'incompatible_server':
      case 'protocol_unsupported':
        return 'Hosted sync is temporarily unavailable. '
            'Please try again later.';
      case 'snapshotPending':
        return 'Snapshot publication is still pending. Please retry.';
      default:
        return _repairMode
            ? 'Repair failed. Please try again.'
            : 'Enrollment failed. Please try again.';
    }
  }

  static String _cooldownCopy(Duration remaining) =>
      remaining > SyncEnrollmentNotifier._maxWaitDisplay
      ? _waitCopy(remaining)
      : 'Send a new code in ${_ceilSeconds(remaining)}s.';

  static String _waitCopy(Duration retryAfter) {
    final seconds = retryAfter.inSeconds;
    final capped = seconds > SyncEnrollmentNotifier._maxWaitDisplay.inSeconds
        ? SyncEnrollmentNotifier._maxWaitDisplay.inSeconds
        : seconds;
    if (capped <= 0) {
      return 'Please wait a moment before trying again.';
    }
    if (capped < 60) {
      return 'Please wait $capped seconds before trying again.';
    }
    final minutes = capped ~/ 60;
    if (minutes <= 1) {
      return 'Please wait about a minute before trying again.';
    }
    return 'Please wait about $minutes minutes before trying again.';
  }
}
