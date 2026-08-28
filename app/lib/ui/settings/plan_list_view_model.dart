import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';

/// Ascending by next occurrence, ended plans (no next occurrence) last.
/// Ties break by name, so the order is deterministic even between two
/// plans with the same next occurrence date.
List<RecurringPlan> sortedPlans(
  List<RecurringPlan> plans,
  LedgerState state,
  DateTime now,
) {
  final sorted = [...plans];
  sorted.sort((a, b) {
    final aNext = a.nextOccurrence(onOrAfter: now);
    final bNext = b.nextOccurrence(onOrAfter: now);

    final dateComparison = switch ((aNext, bNext)) {
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
      (final aDate?, final bDate?) => aDate.compareTo(bDate),
    };
    if (dateComparison != 0) return dateComparison;

    return a.template.name.compareTo(b.template.name);
  });
  return sorted;
}

sealed class PlanListStep {}

class PlanFormRequested extends PlanListStep {
  PlanFormRequested(this.plan);

  final RecurringPlan plan;
}

class DeleteConfirmationRequested extends PlanListStep {
  DeleteConfirmationRequested(this.plan);

  final RecurringPlan plan;
}

class PlanListViewState {
  const PlanListViewState({
    required this.plans,
    required this.ledgerState,
    required this.editing,
    this.step,
  });

  final List<RecurringPlan> plans;
  final LedgerState ledgerState;
  final bool editing;
  final PlanListStep? step;

  PlanListViewState copyWith({
    List<RecurringPlan>? plans,
    LedgerState? ledgerState,
    bool? editing,
    PlanListStep? Function()? step,
  }) {
    return PlanListViewState(
      plans: plans ?? this.plans,
      ledgerState: ledgerState ?? this.ledgerState,
      editing: editing ?? this.editing,
      step: step == null ? this.step : step(),
    );
  }
}

abstract class PlanListViewModel {
  void toggleEditing();
  void requestEditPlan(RecurringPlan plan);

  /// Deletes without asking again: [SwipeToDeleteRow] already confirmed.
  void deletePlan(String id);

  /// Used by the edit-mode row icon, which has not confirmed yet.
  void requestDeletePlan(String id);
  void applyDeleteConfirmed(bool confirmed);
  void clearStep();
}

class PlanListNotifier extends AsyncNotifier<PlanListViewState>
    with LedgerBackedNotifier<PlanListViewState>
    implements PlanListViewModel {
  @override
  Future<PlanListViewState> build() async {
    final currentLedger = ledger;
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _buildState(currentLedger, editing: false);
  }

  void _onLedgerChanged() {
    final current = state.value;
    state = AsyncData(_buildState(ledger, editing: current?.editing ?? false));
  }

  PlanListViewState _buildState(
    Ledger ledger, {
    required bool editing,
    PlanListStep? step,
  }) {
    final ledgerState = ledger.state;
    return PlanListViewState(
      plans: sortedPlans(
        ledgerState.plans.values.toList(),
        ledgerState,
        DateTime.now(),
      ),
      ledgerState: ledgerState,
      editing: editing,
      step: step,
    );
  }

  @override
  void toggleEditing() {
    updateState((current) => current.copyWith(editing: !current.editing));
  }

  @override
  void requestEditPlan(RecurringPlan plan) =>
      _emitStep(PlanFormRequested(plan));

  @override
  void deletePlan(String id) => ledger.deletePlan(id);

  @override
  void requestDeletePlan(String id) {
    final plan = state.value?.ledgerState.plans[id];
    if (plan == null) return;
    _emitStep(DeleteConfirmationRequested(plan));
  }

  @override
  void applyDeleteConfirmed(bool confirmed) {
    final current = state.value;
    if (current == null) return;
    final step = current.step;
    if (step is! DeleteConfirmationRequested) return;
    if (confirmed) ledger.deletePlan(step.plan.id);
  }

  void _emitStep(PlanListStep step) =>
      updateState((current) => current.copyWith(step: () => step));

  @override
  void clearStep() =>
      updateState((current) => current.copyWith(step: () => null));
}

final planListViewModelProvider =
    AsyncNotifierProvider<PlanListNotifier, PlanListViewState>(
      PlanListNotifier.new,
    );
