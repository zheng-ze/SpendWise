import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_spend.dart';

// MARK: - Constants

const _divisionScale = 12;

// MARK: - Results

@immutable
class CategoryBudgetRow {
  const CategoryBudgetRow({
    required this.budgetID,
    required this.categoryID,
    required this.name,
    required this.parentName,
    required this.limit,
    required this.spend,
  });

  final String budgetID;

  final String categoryID;

  final String name;

  final String? parentName;

  final Decimal limit;

  final Decimal spend;

  Decimal get remaining => limit - spend;

  Decimal get utilizationRatio =>
      (spend / limit).toDecimal(scaleOnInfinitePrecision: _divisionScale);

  @override
  bool operator ==(Object other) {
    return other is CategoryBudgetRow &&
        other.budgetID == budgetID &&
        other.categoryID == categoryID &&
        other.name == name &&
        other.parentName == parentName &&
        other.limit == limit &&
        other.spend == spend;
  }

  @override
  int get hashCode =>
      Object.hash(budgetID, categoryID, name, parentName, limit, spend);
}

@immutable
class AllSpending {
  const AllSpending({
    required this.cap,
    required this.capBudgetID,
    required this.spent,
    required this.dailyAllowance,
  });

  final Decimal? cap;

  final String? capBudgetID;

  final Decimal spent;

  final Decimal? dailyAllowance;

  Decimal? get remaining {
    final limit = cap;
    return limit == null ? null : limit - spent;
  }

  @override
  bool operator ==(Object other) {
    return other is AllSpending &&
        other.cap == cap &&
        other.capBudgetID == capBudgetID &&
        other.spent == spent &&
        other.dailyAllowance == dailyAllowance;
  }

  @override
  int get hashCode => Object.hash(cap, capBudgetID, spent, dailyAllowance);
}

@immutable
class BudgetsOverview {
  BudgetsOverview({
    required this.month,
    required this.allSpending,
    required List<CategoryBudgetRow> categoryBudgets,
  }) : categoryBudgets = List.unmodifiable(categoryBudgets);

  final YearMonth month;

  final AllSpending allSpending;

  final List<CategoryBudgetRow> categoryBudgets;

  bool get hasBudgets =>
      allSpending.capBudgetID != null || categoryBudgets.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is BudgetsOverview &&
        other.month == month &&
        other.allSpending == allSpending &&
        listEquals(other.categoryBudgets, categoryBudgets);
  }

  @override
  int get hashCode =>
      Object.hash(month, allSpending, Object.hashAll(categoryBudgets));
}

// MARK: - Projection

BudgetsOverview budgetsOverview({
  required LedgerState state,
  required List<AnalysisItem> items,
  required YearMonth month,
  required DateTime today,
}) {
  final budgets = state.budgets.values;
  final unscoped = budgets.where((b) => b.categoryID == null).firstOrNull;
  final scoped = budgets.where((b) => b.categoryID != null).toList();
  final rows = [
    for (final b in scoped) _row(b, b.categoryID ?? '', month, items, state),
  ]..sort(_compareUtilization);
  final cap = unscoped == null ? _aggregateCap(scoped, state) : unscoped.limit;
  final spent = monthExpenseSpend(month, items);
  final allSpending = AllSpending(
    cap: cap,
    capBudgetID: unscoped?.id,
    spent: spent,
    dailyAllowance: _dailyAllowance(cap, spent, month, today),
  );

  return BudgetsOverview(
    month: month,
    allSpending: allSpending,
    categoryBudgets: rows,
  );
}

CategoryBudgetRow _row(
  Budget budget,
  String categoryID,
  YearMonth month,
  List<AnalysisItem> items,
  LedgerState state,
) {
  final category = state.categories[categoryID];
  if (category == null) {
    throw StateError('Budget ${budget.id} names a missing category.');
  }
  final parentID = category.parentID;
  return CategoryBudgetRow(
    budgetID: budget.id,
    categoryID: categoryID,
    name: category.name,
    parentName: parentID == null ? null : state.categories[parentID]?.name,
    limit: budget.limit,
    spend: budgetSpend(budget, month, items, state),
  );
}

int _compareUtilization(CategoryBudgetRow a, CategoryBudgetRow b) {
  final byRatio = (b.spend * a.limit).compareTo(a.spend * b.limit);
  if (byRatio != 0) return byRatio;
  final byName = a.name.trim().toLowerCase().compareTo(
    b.name.trim().toLowerCase(),
  );
  if (byName != 0) return byName;
  return normalizedID(a.budgetID).compareTo(normalizedID(b.budgetID));
}

Decimal? _aggregateCap(List<Budget> scoped, LedgerState state) {
  if (scoped.isEmpty) return null;
  final budgeted = {for (final b in scoped) b.categoryID};
  final topLevel = scoped.where(
    (b) => !budgeted.contains(state.categories[b.categoryID]?.parentID),
  );
  return topLevel.fold<Decimal>(Decimal.zero, (sum, b) => sum + b.limit);
}

Decimal? _dailyAllowance(
  Decimal? cap,
  Decimal spent,
  YearMonth month,
  DateTime today,
) {
  if (cap == null) return null;
  final day = startOfDayUtc(today);
  if (day.year != month.year || day.month != month.month) return null;
  final nextMonthStart = DateTime.utc(month.year, month.month + 1);
  final firstFutureDay = day.add(const Duration(days: 1));
  final daysAfterToday = nextMonthStart.difference(firstFutureDay).inDays;
  if (daysAfterToday <= 0) return null;
  final remaining = cap - spent;
  final allowance = remaining > Decimal.zero ? remaining : Decimal.zero;
  return (allowance / Decimal.fromInt(daysAfterToday)).toDecimal(
    scaleOnInfinitePrecision: _divisionScale,
  );
}
