import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';

// MARK: - Helpers

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

// MARK: - Steps
sealed class PlanListStep {}

class PlanFormRequested extends PlanListStep {
  PlanFormRequested(this.plan);

  final RecurringPlan plan;
}

class DeleteConfirmationRequested extends PlanListStep {
  DeleteConfirmationRequested(this.plan);

  final RecurringPlan plan;
}

// MARK: - PlanListViewState
class PlanListViewState implements HasStep<PlanListViewState, PlanListStep> {
  const PlanListViewState({
    required this.plans,
    required this.ledgerState,
    required this.nextOccurrences,
    required this.editing,
    this.step,
  });

  final List<RecurringPlan> plans;
  final LedgerState ledgerState;
  final Map<String, DateTime?> nextOccurrences;
  final bool editing;
  @override
  final PlanListStep? step;

  PlanListViewState copyWith({
    List<RecurringPlan>? plans,
    LedgerState? ledgerState,
    Map<String, DateTime?>? nextOccurrences,
    bool? editing,
    PlanListStep? Function()? step,
  }) {
    return PlanListViewState(
      plans: plans ?? this.plans,
      ledgerState: ledgerState ?? this.ledgerState,
      nextOccurrences: nextOccurrences ?? this.nextOccurrences,
      editing: editing ?? this.editing,
      step: step == null ? this.step : step(),
    );
  }

  @override
  PlanListViewState withStep(PlanListStep? Function() step) =>
      copyWith(step: step);
}

// MARK: - PlanListViewModel
abstract class PlanListViewModel {
  void toggleEditing();
  void requestEditPlan(RecurringPlan plan);

  void deletePlan(String id);

  void requestDeletePlan(String id);
  void applyDeleteConfirmed(bool confirmed);
  void clearStep();
}

// MARK: - PlanListProjection
class PlanListProjection {
  const PlanListProjection({
    required this.plans,
    required this.ledgerState,
    required this.nextOccurrences,
  });

  final List<RecurringPlan> plans;
  final LedgerState ledgerState;
  final Map<String, DateTime?> nextOccurrences;
}

// MARK: - PlanListProjectionNotifier
class PlanListProjectionNotifier extends AsyncNotifier<PlanListProjection>
    with LedgerBackedNotifier<PlanListProjection> {
  @override
  PlanListProjection build() {
    final currentLedger = ledger;
    final today = ref.watch(todayProvider);
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _project(currentLedger, today);
  }

  void _onLedgerChanged() {
    if (!ref.mounted) return;
    state = AsyncData(_project(ledger, ref.read(todayProvider)));
  }

  PlanListProjection _project(Ledger ledger, DateTime today) {
    final ledgerState = ledger.state;
    final plans = sortedPlans(
      ledgerState.plans.values.toList(),
      ledgerState,
      today,
    );
    return PlanListProjection(
      plans: plans,
      ledgerState: ledgerState,
      nextOccurrences: {
        for (final plan in plans)
          plan.id: plan.nextOccurrence(onOrAfter: today),
      },
    );
  }
}

// MARK: - PlanListNotifier
class PlanListNotifier extends AsyncNotifier<PlanListViewState>
    with
        LedgerBackedNotifier<PlanListViewState>,
        StepEmitting<PlanListViewState, PlanListStep>
    implements PlanListViewModel {
  @override
  PlanListViewState build() {
    final projection = ref.watch(planListProjectionProvider);
    if (projection case AsyncError(:final error, :final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    final data = projection.requireValue;
    final current = state.value;
    return PlanListViewState(
      plans: data.plans,
      ledgerState: data.ledgerState,
      nextOccurrences: data.nextOccurrences,
      editing: current?.editing ?? false,
      step: current?.step,
    );
  }

  @override
  void toggleEditing() {
    updateState((current) => current.copyWith(editing: !current.editing));
  }

  @override
  void requestEditPlan(RecurringPlan plan) => emitStep(PlanFormRequested(plan));

  @override
  void deletePlan(String id) => ledger.deletePlan(id);

  @override
  void requestDeletePlan(String id) {
    final plan = state.value?.ledgerState.plans[id];
    if (plan == null) return;
    emitStep(DeleteConfirmationRequested(plan));
  }

  @override
  void applyDeleteConfirmed(bool confirmed) {
    final current = state.value;
    if (current == null) return;
    final step = current.step;
    if (step is! DeleteConfirmationRequested) return;
    if (confirmed) ledger.deletePlan(step.plan.id);
  }
}

// MARK: - Constants
final planListProjectionProvider =
    AsyncNotifierProvider<PlanListProjectionNotifier, PlanListProjection>(
      PlanListProjectionNotifier.new,
    );

final planListViewModelProvider =
    AsyncNotifierProvider.autoDispose<PlanListNotifier, PlanListViewState>(
      PlanListNotifier.new,
    );
