part of '../sync_enrollment_view_model.dart';

// MARK: - Phase-Aware Failure

void _enterEnrollmentCancelled({
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required _EnrollmentStateUpdater updateState,
  required void Function(SyncEnrollmentStep step) emitStep,
}) {
  if (!identical(operation, operations.currentOperation)) return;
  operations.otpCompleter = null;
  operations.session = null;
  updateState(
    (current) => current.copyWith(
      errorMessage: () => null,
      cancelled: true,
      otpWaiting: false,
    ),
  );
  emitStep(ShowIdentifierEntry());
}

Future<void> _failEnrollmentPhaseAware({
  required Object error,
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required bool Function() isMounted,
  required bool Function() repairMode,
  required _EnrollmentStateUpdater updateState,
  required void Function(SyncEnrollmentStep step) emitStep,
  required Future<SyncEnrollmentPhase> Function() currentPhase,
  required void Function(Object, _EnrollmentOperation) extendCooldownFrom,
}) async {
  if (!identical(operation, operations.currentOperation)) return;
  final message = _failureCopy(error, repairMode());
  extendCooldownFrom(error, operation);
  final phase = await currentPhase();
  if (!isMounted() || !identical(operation, operations.currentOperation)) {
    return;
  }
  updateState(
    (current) => current.copyWith(
      errorMessage: () => message,
      repairPhase: repairMode() && _isRepairPhase(phase) ? () => phase : null,
    ),
  );
  if (phase == SyncEnrollmentPhase.notEnrolled || _isRepairPhase(phase)) {
    emitStep(ShowIdentifierEntry());
  } else {
    emitStep(ShowProgressResume());
  }
}

Future<void> _refreshEnrollmentRepairPhase({
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required bool Function() isMounted,
  required _EnrollmentStateUpdater updateState,
  required Future<SyncEnrollmentPhase> Function() currentPhase,
}) async {
  final phase = await currentPhase();
  if (!isMounted() || !identical(operation, operations.currentOperation)) {
    return;
  }
  if (_isRepairPhase(phase)) {
    updateState((current) => current.copyWith(repairPhase: () => phase));
  }
}

Future<void> _refreshEnrollmentSyncStatus(AppBoot appBoot) =>
    appBoot.refreshSyncStatus();

Future<SyncEnrollmentPhase> _currentEnrollmentPhase(
  SyncMetadataStore metadataStore,
) async {
  final snapshot = await metadataStore.snapshot();
  return snapshot.phase;
}

bool _isRepairPhase(SyncEnrollmentPhase phase) =>
    phase == SyncEnrollmentPhase.bindingAuthorizationRequired ||
    phase == SyncEnrollmentPhase.sessionReauthRequired;

// MARK: - Cooldown

Duration? _enrollmentCodeCooldownRemaining(
  SyncEnrollmentState currentState,
  DateTime Function() now,
) {
  final endsAt = currentState.codeCooldownEndsAt;
  if (endsAt == null) return null;
  final remaining = endsAt.difference(now());
  return remaining.isNegative ? null : remaining;
}

void _noteEnrollmentCodeRequested({
  required bool Function() isMounted,
  required DateTime Function() now,
  required _EnrollmentStateUpdater updateState,
}) {
  if (!isMounted()) return;
  updateState(
    (current) => current.copyWith(
      codeCooldownEndsAt: () =>
          now().add(SyncEnrollmentNotifier.codeRequestCooldown),
    ),
  );
}

void _extendEnrollmentCooldownFrom({
  required Object error,
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required SyncEnrollmentState Function() readState,
  required DateTime Function() now,
  required _EnrollmentStateUpdater updateState,
}) {
  if (!identical(operation, operations.currentOperation)) return;
  final retryAfter = error is SyncEnrollmentException ? error.retryAfter : null;
  if (retryAfter == null) return;
  final candidate = now().add(retryAfter);
  final current = readState().codeCooldownEndsAt;
  if (current == null || candidate.isAfter(current)) {
    updateState(
      (previous) => previous.copyWith(codeCooldownEndsAt: () => candidate),
    );
  }
}

int _ceilSeconds(Duration remaining) {
  final seconds = (remaining.inMilliseconds / 1000).ceil();
  return seconds < 1 ? 1 : seconds;
}

// MARK: - Failure Copy

String _failureCopy(Object error, bool repairMode) {
  if (error is SyncEnrollmentException) {
    final base = _copyForCode(error.code, repairMode);
    final retryAfter = error.retryAfter;
    if (retryAfter == null) return base;
    return '$base ${_waitCopy(retryAfter)}';
  }
  return repairMode
      ? 'Repair failed. Please try again.'
      : 'Enrollment failed. Please try again.';
}

String _copyForCode(String code, bool repairMode) {
  switch (code) {
    case 'rate_limited':
      return 'Too many codes were requested.';
    case 'invalid_request':
      return repairMode
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
      return repairMode
          ? 'Repair failed. Please try again.'
          : 'Enrollment failed. Please try again.';
  }
}

String _cooldownCopy(Duration remaining) =>
    remaining > SyncEnrollmentNotifier._maxWaitDisplay
    ? _waitCopy(remaining)
    : 'Send a new code in ${_ceilSeconds(remaining)}s.';

String _waitCopy(Duration retryAfter) {
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
