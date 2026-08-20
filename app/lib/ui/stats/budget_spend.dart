import 'package:domain/domain.dart';

import 'package:spendwise/ui/stats/stats_window.dart';

/// The category and its children that count toward [budget]'s spend, or
/// null for an overall budget (every expense category counts).
Set<String>? budgetBucketIDs(Budget budget, LedgerState state) {
  final categoryID = budget.categoryID;
  if (categoryID == null) return null;

  return {
    categoryID,
    for (final category in state.categories.values)
      if (category.parentID == categoryID) category.id,
  };
}

bool _budgetMatches(Budget budget, AnalysisItem item, LedgerState state) {
  if (item.kind != CategoryKind.expense) return false;
  if (budget.categoryID == null) return true;

  final bucketID = item.bucketID;
  if (bucketID == budget.categoryID) return true;
  if (bucketID == null) return false;
  return state.categories[bucketID]?.parentID == budget.categoryID;
}

Decimal budgetSpend(
  Budget budget,
  YearMonth month,
  List<AnalysisItem> items,
  LedgerState state,
) {
  final window = monthWindow(DateTime.utc(month.year, month.month));

  return items
      .where(
        (item) =>
            window.contains(item.date) && _budgetMatches(budget, item, state),
      )
      .fold(Decimal.zero, (sum, item) => sum + item.amount);
}
