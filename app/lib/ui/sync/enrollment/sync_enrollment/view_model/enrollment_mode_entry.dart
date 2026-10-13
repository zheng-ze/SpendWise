// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of '../sync_enrollment_view_model.dart';

// MARK: - Mode Entry

extension SyncEnrollmentModeEntry on SyncEnrollmentNotifier {
  /// Null when a newer operation superseded this read and owns the outcome.
  Future<bool?> enterRepairMode() {
    final settlement = _enterRepairMode();
    final tracked = settlement.then<void>((_) {}, onError: (_) {});
    _pendingSettlements.add(tracked);
    return settlement.whenComplete(() => _pendingSettlements.remove(tracked));
  }

  Future<bool?> _enterRepairMode() async {
    _modeSequence++;
    if (state.inFlight) return state.repairPhase != null;
    _repairMode = true;
    final operation = _EnrollmentOperation();
    _currentOperation = operation;
    _session = null;
    state = state.copyWith(
      identifier: '',
      errorMessage: () => null,
      cancelled: false,
      repairMode: true,
      explainCodeReplacement: true,
      inFlight: true,
      step: () => null,
    );
    final SyncEnrollmentPhase phase;
    try {
      phase = await _currentPhase();
    } catch (_) {
      if (identical(operation, _currentOperation) && ref.mounted) {
        state = state.copyWith(inFlight: false);
      }
      return false;
    }
    if (!ref.mounted || !identical(operation, _currentOperation)) return null;
    state = state.copyWith(inFlight: false);
    if (SyncEnrollmentFailureCopy._isRepairPhase(phase)) {
      state = state.copyWith(repairPhase: () => phase);
    }
    emitStep(ShowIdentifierEntry());
    return SyncEnrollmentFailureCopy._isRepairPhase(phase);
  }

  // MARK: - Prior Operation Settlement

  bool get _priorOperationPending =>
      state.inFlight ||
      _pendingEnrolls > 0 ||
      _abandonedPublication != null ||
      _pendingSettlements.isNotEmpty;

  Future<void> _settlePriorOperation() async {
    while (_priorOperationPending) {
      final abandoned = _abandonedPublication;
      final waiting = <Future<void>>[..._pendingSettlements, ?abandoned];
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
}
