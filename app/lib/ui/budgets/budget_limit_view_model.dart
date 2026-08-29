import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';

/// Which limit a [PickLimitRequested] step is asking the Flow to edit: the
/// ongoing default, or one specific month's override.
sealed class LimitEditTarget {}

class DefaultLimitTarget extends LimitEditTarget {
  DefaultLimitTarget(this.current, this.effectiveFromMonth);

  final Decimal current;
  final YearMonth effectiveFromMonth;
}

class MonthLimitTarget extends LimitEditTarget {
  MonthLimitTarget(this.month, this.current);

  final YearMonth month;
  final Decimal current;
}

sealed class BudgetLimitStep {}

class PickLimitRequested extends BudgetLimitStep {
  PickLimitRequested(this.target);

  final LimitEditTarget target;
}

class BudgetLimitViewState
    implements HasStep<BudgetLimitViewState, BudgetLimitStep> {
  const BudgetLimitViewState({
    required this.budget,
    required this.displayedYear,
    this.error,
    this.step,
  });

  final Budget? budget;
  final DateTime displayedYear;
  final LedgerError? error;
  @override
  final BudgetLimitStep? step;

  Decimal? get defaultLimit {
    final currentBudget = budget;
    if (currentBudget == null) return null;
    return currentBudget.limitEvents
        .where((event) => event.kind == LimitEventKind.defaultLimit)
        .map((event) => event.value)
        .lastOrNull;
  }

  List<YearMonth> get months => [
    for (var i = 11; i >= 0; i--) YearMonth(displayedYear.year, i + 1),
  ];

  BudgetLimitViewState copyWith({
    Budget? Function()? budget,
    DateTime? displayedYear,
    LedgerError? Function()? error,
    BudgetLimitStep? Function()? step,
  }) {
    return BudgetLimitViewState(
      budget: budget == null ? this.budget : budget(),
      displayedYear: displayedYear ?? this.displayedYear,
      error: error == null ? this.error : error(),
      step: step == null ? this.step : step(),
    );
  }

  @override
  BudgetLimitViewState withStep(BudgetLimitStep? Function() step) =>
      copyWith(step: step);
}

abstract class BudgetLimitViewModel {
  void changeYear(DateTime year);
  void requestEditDefault();
  void requestEditMonth(YearMonth month);
  void applyPickedLimit(Decimal? amount);
  void clearStep();
}

class BudgetLimitNotifier extends AsyncNotifier<BudgetLimitViewState>
    with
        LedgerBackedNotifier<BudgetLimitViewState>,
        StepEmitting<BudgetLimitViewState, BudgetLimitStep>
    implements BudgetLimitViewModel {
  BudgetLimitNotifier(this._budgetID);

  final String _budgetID;

  @override
  Future<BudgetLimitViewState> build() async {
    final currentLedger = ledger;
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));

    return BudgetLimitViewState(
      budget: currentLedger.state.budgets[_budgetID],
      displayedYear: DateTime.utc(startOfDayUtc(DateTime.now()).year),
    );
  }

  void _onLedgerChanged() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(budget: () => ledger.state.budgets[_budgetID]),
    );
  }

  @override
  void changeYear(DateTime year) =>
      updateState((s) => s.copyWith(displayedYear: DateTime.utc(year.year)));

  @override
  void requestEditDefault() {
    final current = state.value;
    if (current == null || current.budget == null) return;

    final now = startOfDayUtc(DateTime.now());
    final nextMonth = YearMonth.fromUtc(DateTime.utc(now.year, now.month + 1));
    final target = DefaultLimitTarget(
      current.defaultLimit ?? Decimal.zero,
      nextMonth,
    );
    emitStep(PickLimitRequested(target));
  }

  @override
  void requestEditMonth(YearMonth month) {
    final current = state.value;
    final budget = current?.budget;
    if (budget == null) return;

    final target = MonthLimitTarget(month, effectiveLimit(budget, month));
    emitStep(PickLimitRequested(target));
  }

  // A picker outcome can arrive after the sheet that opened it was
  // dismissed, so this must no-op rather than update a gone provider.
  @override
  void applyPickedLimit(Decimal? amount) {
    if (!ref.mounted) return;
    final current = state.value;
    final step = current?.step;
    if (step is! PickLimitRequested) return;
    clearStep();
    if (amount == null || amount <= Decimal.zero) return;

    try {
      switch (step.target) {
        case DefaultLimitTarget(:final effectiveFromMonth):
          ledger.updateBudgetAmount(_budgetID, amount, effectiveFromMonth);
        case MonthLimitTarget(:final month):
          ledger.setBudgetMonthOverride(_budgetID, month, amount);
      }
      updateState((s) => s.copyWith(error: () => null));
    } on LedgerError catch (error) {
      updateState((s) => s.copyWith(error: () => error));
    }
  }

}

final budgetLimitViewModelProvider =
    AsyncNotifierProvider.family<
      BudgetLimitNotifier,
      BudgetLimitViewState,
      String
    >(BudgetLimitNotifier.new);
