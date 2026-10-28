import 'package:domain/domain.dart';

import 'package:spendwise/ledger/analysis/insights/completeness.dart';

bool _isMonthExpense(AnalysisItem item, DateRange window) =>
    window.contains(item.date) && item.kind == CategoryKind.expense;

bool _budgetMatches(Budget budget, AnalysisItem item, LedgerState state) {
  if (budget.categoryID == null) return true;

  final bucketID = item.bucketID;
  if (bucketID == budget.categoryID) return true;
  if (bucketID == null) return false;
  return state.categories[bucketID]?.parentID == budget.categoryID;
}

// MARK: - Spending

bool budgetCountsItem(
  Budget budget,
  YearMonth month,
  AnalysisItem item,
  LedgerState state,
) =>
    _isMonthExpense(item, monthWindow(DateTime.utc(month.year, month.month))) &&
    _budgetMatches(budget, item, state);

bool budgetCountsItemInAnyMonth(
  Budget budget,
  AnalysisItem item,
  LedgerState state,
) => item.kind == CategoryKind.expense && _budgetMatches(budget, item, state);

List<AnalysisItem> budgetItems(
  Budget budget,
  YearMonth month,
  List<AnalysisItem> items,
  LedgerState state,
) => [
  for (final item in items)
    if (budgetCountsItem(budget, month, item, state)) item,
];

Decimal budgetSpend(
  Budget budget,
  YearMonth month,
  List<AnalysisItem> items,
  LedgerState state,
) => budgetItems(
  budget,
  month,
  items,
  state,
).fold(Decimal.zero, (sum, item) => sum + item.amount);

Decimal monthExpenseSpend(YearMonth month, List<AnalysisItem> items) {
  final window = monthWindow(DateTime.utc(month.year, month.month));

  return items
      .where((item) => _isMonthExpense(item, window))
      .fold(Decimal.zero, (sum, item) => sum + item.amount);
}
