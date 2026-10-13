part of '../sync_enrollment_view_model.dart';

// MARK: - Mode Entry

typedef _EnrollmentStateUpdater = void Function(
  SyncEnrollmentState Function(SyncEnrollmentState current) apply,
);

class _EnrollmentOperations {
  Completer<String>? otpCompleter;
  SyncEnrollmentSession? session;
  _EnrollmentOperation? currentOperation;
  Future<void>? abandonedPublication;
  int pendingEnrolls = 0;
  final List<Future<void>> pendingSettlements = [];
}

Future<bool?> _finishEnteringRepairMode({
  required _EnrollmentOperation operation,
  required _EnrollmentOperations operations,
  required _EnrollmentStateUpdater updateState,
  required bool Function() isMounted,
  required Future<SyncEnrollmentPhase> Function() currentPhase,
  required void Function(SyncEnrollmentStep step) emitStep,
}) async {
  updateState(
    (current) => current.copyWith(
      identifier: '',
      errorMessage: () => null,
      cancelled: false,
      repairMode: true,
      explainCodeReplacement: true,
      inFlight: true,
      step: () => null,
    ),
  );
  final SyncEnrollmentPhase phase;
  try {
    phase = await currentPhase();
  } catch (_) {
    if (identical(operation, operations.currentOperation) && isMounted()) {
      updateState((current) => current.copyWith(inFlight: false));
    }
    return false;
  }
  if (!isMounted() || !identical(operation, operations.currentOperation)) {
    return null;
  }
  updateState((current) => current.copyWith(inFlight: false));
  if (_isRepairPhase(phase)) {
    updateState((current) => current.copyWith(repairPhase: () => phase));
  }
  emitStep(ShowIdentifierEntry());
  return _isRepairPhase(phase);
}

// MARK: - Prior Operation Settlement

bool _priorEnrollmentOperationPending(
  SyncEnrollmentState currentState,
  _EnrollmentOperations operations,
) =>
    currentState.inFlight ||
    operations.pendingEnrolls > 0 ||
    operations.abandonedPublication != null ||
    operations.pendingSettlements.isNotEmpty;

Future<void> _settlePriorEnrollmentOperation({
  required SyncEnrollmentState Function() readState,
  required _EnrollmentOperations operations,
}) async {
  while (_priorEnrollmentOperationPending(readState(), operations)) {
    final abandoned = operations.abandonedPublication;
    final waiting = <Future<void>>[
      ...operations.pendingSettlements,
      ?abandoned,
    ];
    if (waiting.isEmpty) {
      await Future<void>.delayed(Duration.zero);
      continue;
    }
    for (final pending in waiting) {
      try {
        await pending;
      } catch (_) {}
    }
  }
}
