import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_spend.dart';
import 'package:spendwise/ledger/analysis/insights/usual_baseline.dart';

// MARK: - Results

@immutable
class BudgetForecast {
  const BudgetForecast({
    required this.budgetID,
    required this.categoryID,
    required this.limit,
    required this.spentSoFar,
    required this.monthlyAverage,
    required this.projected,
    required this.overBy,
  });

  final String? budgetID;

  final String? categoryID;

  final Decimal limit;

  final Decimal spentSoFar;

  final Decimal monthlyAverage;

  final Decimal projected;

  final Decimal? overBy;

  bool get isOver => overBy != null;

  bool get isDerivedCap => budgetID == null;

  @override
  bool operator ==(Object other) {
    return other is BudgetForecast &&
        other.budgetID == budgetID &&
        other.categoryID == categoryID &&
        other.limit == limit &&
        other.spentSoFar == spentSoFar &&
        other.monthlyAverage == monthlyAverage &&
        other.projected == projected &&
        other.overBy == overBy;
  }

  @override
  int get hashCode => Object.hash(
    budgetID,
    categoryID,
    limit,
    spentSoFar,
    monthlyAverage,
    projected,
    overBy,
  );
}

@immutable
class BudgetForecasts {
  BudgetForecasts({
    required this.month,
    required this.completeMonthCount,
    required this.allSpending,
    required List<BudgetForecast> categoryBudgets,
  }) : categoryBudgets = List.unmodifiable(categoryBudgets);

  final DateTime month;

  final int completeMonthCount;

  final BudgetForecast? allSpending;

  final List<BudgetForecast> categoryBudgets;

  bool get hasBaseline => completeMonthCount >= usualMinimumCompleteMonths;

  int get overCount {
    final all = allSpending;
    final allOver = all != null && all.isOver ? 1 : 0;
    return allOver + categoryBudgets.where((f) => f.isOver).length;
  }

  @override
  bool operator ==(Object other) {
    return other is BudgetForecasts &&
        other.month == month &&
        other.completeMonthCount == completeMonthCount &&
        other.allSpending == allSpending &&
        listEquals(other.categoryBudgets, categoryBudgets);
  }

  @override
  int get hashCode => Object.hash(
    month,
    completeMonthCount,
    allSpending,
    Object.hashAll(categoryBudgets),
  );
}

// MARK: - Projection

BudgetForecasts budgetForecasts({
  required LedgerState state,
  required List<AnalysisItem> items,
  required DateTime? firstRecordMonth,
  required DateTime today,
}) {
  final day = startOfDayUtc(today);
  final month = DateTime.utc(day.year, day.month, 1);
  final firstMonth = firstRecordMonth == null
      ? null
      : DateTime.utc(firstRecordMonth.year, firstRecordMonth.month, 1);
  final baselineMonths = usualBaselineMonths(
    firstRecordMonth: firstMonth,
    today: day,
  );
  final monthCount = baselineMonths.length;
  if (monthCount < usualMinimumCompleteMonths) {
    return BudgetForecasts(
      month: month,
      completeMonthCount: monthCount,
      allSpending: null,
      categoryBudgets: const [],
    );
  }

  final elapsed = DateRange(month, day.add(const Duration(days: 1)));
  final elapsedItems = [
    for (final item in items)
      if (elapsed.contains(item.date)) item,
  ];
  final baselineWindow = DateRange(baselineMonths.first, month);
  final baselineItems = [
    for (final item in items)
      if (baselineWindow.contains(item.date)) item,
  ];
  final thisMonth = YearMonth.fromUtc(month);
  final timing = _Timing(
    monthCount: monthCount,
    daysInMonth: monthWindow(month).end.difference(month).inDays,
    daysAfterToday: monthWindow(month).end.difference(elapsed.end).inDays,
  );

  final budgets = state.budgets.values;
  final unscoped = budgets.where((b) => b.categoryID == null).firstOrNull;
  final scoped = budgets.where((b) => b.categoryID != null).toList()
    ..sort((a, b) => normalizedID(a.id).compareTo(normalizedID(b.id)));
  final allSpending = _allSpendingForecast(
    unscoped: unscoped,
    scoped: scoped,
    state: state,
    spentSoFar: monthExpenseSpend(thisMonth, elapsedItems),
    baselineTotal: _baselineTotal(
      baselineMonths,
      baselineItems,
      monthExpenseSpend,
    ),
    timing: timing,
  );
  final categoryForecasts = [
    for (final budget in scoped)
      _categoryForecast(
        budget: budget,
        state: state,
        month: thisMonth,
        baselineMonths: baselineMonths,
        elapsedItems: elapsedItems,
        baselineItems: baselineItems,
        timing: timing,
      ),
  ];

  return BudgetForecasts(
    month: month,
    completeMonthCount: monthCount,
    allSpending: allSpending,
    categoryBudgets: categoryForecasts,
  );
}

// MARK: - Helpers

class _Timing {
  const _Timing({
    required this.monthCount,
    required this.daysInMonth,
    required this.daysAfterToday,
  });

  final int monthCount;

  final int daysInMonth;

  final int daysAfterToday;
}

Decimal _baselineTotal(
  List<DateTime> months,
  List<AnalysisItem> items,
  Decimal Function(YearMonth month, List<AnalysisItem> items) spendOf,
) {
  var total = Decimal.zero;
  for (final month in months) {
    total += spendOf(YearMonth.fromUtc(month), items);
  }
  return total;
}

BudgetForecast _categoryForecast({
  required Budget budget,
  required LedgerState state,
  required YearMonth month,
  required List<DateTime> baselineMonths,
  required List<AnalysisItem> elapsedItems,
  required List<AnalysisItem> baselineItems,
  required _Timing timing,
}) {
  final spentSoFar = budgetSpend(budget, month, elapsedItems, state);
  final baselineTotal = _baselineTotal(
    baselineMonths,
    baselineItems,
    (m, list) => budgetSpend(budget, m, list, state),
  );
  return _forecast(
    budgetID: budget.id,
    categoryID: budget.categoryID,
    limit: budget.limit,
    spentSoFar: spentSoFar,
    baselineTotal: baselineTotal,
    timing: timing,
  );
}

BudgetForecast? _allSpendingForecast({
  required Budget? unscoped,
  required List<Budget> scoped,
  required LedgerState state,
  required Decimal spentSoFar,
  required Decimal baselineTotal,
  required _Timing timing,
}) {
  final limit = unscoped?.limit ?? derivedAllSpendingCap(scoped, state);
  if (limit == null) return null;
  return _forecast(
    budgetID: unscoped?.id,
    categoryID: null,
    limit: limit,
    spentSoFar: spentSoFar,
    baselineTotal: baselineTotal,
    timing: timing,
  );
}

BudgetForecast _forecast({
  required String? budgetID,
  required String? categoryID,
  required Decimal limit,
  required Decimal spentSoFar,
  required Decimal baselineTotal,
  required _Timing timing,
}) {
  final span = timing.monthCount * timing.daysInMonth;
  final numerator =
      spentSoFar * Decimal.fromInt(span) +
      baselineTotal * Decimal.fromInt(timing.daysAfterToday);
  final projected = roundedCents(numerator, span);
  return BudgetForecast(
    budgetID: budgetID,
    categoryID: categoryID,
    limit: limit,
    spentSoFar: spentSoFar,
    monthlyAverage: roundedCents(baselineTotal, timing.monthCount),
    projected: projected,
    overBy: projected > limit ? projected - limit : null,
  );
}
