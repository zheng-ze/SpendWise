import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_spend.dart';
import 'package:spendwise/ledger/analysis/insights/completeness.dart';

// MARK: - Constants

const _monthsInYear = 12;

// MARK: - Results

@immutable
class BudgetMonthSlot {
  const BudgetMonthSlot({
    required this.month,
    required this.spend,
    required this.limit,
    required this.isOverride,
    required this.recordCount,
    required this.completeness,
  });

  final YearMonth month;

  final Decimal spend;

  final Decimal limit;

  final bool isOverride;

  final int recordCount;

  final PeriodCompleteness completeness;

  @override
  bool operator ==(Object other) {
    return other is BudgetMonthSlot &&
        other.month == month &&
        other.spend == spend &&
        other.limit == limit &&
        other.isOverride == isOverride &&
        other.recordCount == recordCount &&
        other.completeness == completeness;
  }

  @override
  int get hashCode =>
      Object.hash(month, spend, limit, isOverride, recordCount, completeness);
}

@immutable
class BudgetDetailSummary {
  const BudgetDetailSummary({
    required this.categoryID,
    required this.createdAtMonth,
    required this.spent,
    required this.limit,
  });

  final String? categoryID;

  final YearMonth createdAtMonth;

  final Decimal spent;

  final Decimal limit;

  Decimal get remaining => limit - spent;

  @override
  bool operator ==(Object other) {
    return other is BudgetDetailSummary &&
        other.categoryID == categoryID &&
        other.createdAtMonth == createdAtMonth &&
        other.spent == spent &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(categoryID, createdAtMonth, spent, limit);
}

@immutable
class BudgetDetail {
  BudgetDetail({
    required this.budgetID,
    required this.displayedYear,
    required this.selectedMonth,
    required this.summary,
    required List<BudgetMonthSlot> slots,
  }) : slots = List.unmodifiable(slots);

  final String budgetID;

  final int displayedYear;

  final YearMonth selectedMonth;

  final BudgetDetailSummary? summary;

  final List<BudgetMonthSlot> slots;

  @override
  bool operator ==(Object other) {
    return other is BudgetDetail &&
        other.budgetID == budgetID &&
        other.displayedYear == displayedYear &&
        other.selectedMonth == selectedMonth &&
        other.summary == summary &&
        listEquals(other.slots, slots);
  }

  @override
  int get hashCode => Object.hash(
    budgetID,
    displayedYear,
    selectedMonth,
    summary,
    Object.hashAll(slots),
  );
}

// MARK: - Projection

BudgetDetail budgetDetail({
  required LedgerState state,
  required List<AnalysisItem> items,
  required String budgetID,
  required int displayedYear,
  required YearMonth selectedMonth,
  required DateTime today,
}) {
  final budget = state.budgets[budgetID];
  if (budget == null) {
    return BudgetDetail(
      budgetID: budgetID,
      displayedYear: displayedYear,
      selectedMonth: selectedMonth,
      summary: null,
      slots: const [],
    );
  }
  final first = firstRecordMonth(state);
  final slots = [
    for (var m = 1; m <= _monthsInYear; m++)
      _slot(budget, YearMonth(displayedYear, m), items, state, first, today),
  ];
  final summary = BudgetDetailSummary(
    categoryID: budget.categoryID,
    createdAtMonth: budget.createdAtMonth,
    spent: budgetSpend(budget, selectedMonth, items, state),
    limit: effectiveLimit(budget, selectedMonth),
  );

  return BudgetDetail(
    budgetID: budgetID,
    displayedYear: displayedYear,
    selectedMonth: selectedMonth,
    summary: summary,
    slots: slots,
  );
}

BudgetMonthSlot _slot(
  Budget budget,
  YearMonth month,
  List<AnalysisItem> items,
  LedgerState state,
  DateTime? first,
  DateTime today,
) {
  final window = monthWindow(DateTime.utc(month.year, month.month));
  final matching = budgetItems(budget, month, items, state);
  return BudgetMonthSlot(
    month: month,
    spend: matching.fold(Decimal.zero, (sum, item) => sum + item.amount),
    limit: effectiveLimit(budget, month),
    isOverride: budget.limitEvents.any(
      (e) => e.kind == LimitEventKind.override && e.effectiveFromMonth == month,
    ),
    recordCount: matching.length,
    completeness: classifyPeriod(
      window: window,
      firstRecordMonth: first,
      today: today,
    ),
  );
}
