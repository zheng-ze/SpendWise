import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_spend.dart';

// MARK: - Results

@immutable
class BudgetCountedEntry {
  const BudgetCountedEntry({required this.entry, required this.amount});

  final Entry entry;

  final Decimal amount;
}

// MARK: - Projection

List<BudgetCountedEntry> budgetCountedEntries(
  Budget budget,
  YearMonth month,
  LedgerState state,
) {
  final sourceIDs = state.moneySources.keys.toSet();
  final counted = <BudgetCountedEntry>[];

  for (final entry in state.entries.values) {
    final matching = Accounting.classify(
      entry,
      sourceIDs,
      state,
    ).where((item) => budgetCountsItem(budget, month, item, state));
    if (matching.isEmpty) continue;

    final amount = matching.fold(
      Decimal.zero,
      (sum, item) => sum + item.amount,
    );
    counted.add(BudgetCountedEntry(entry: entry, amount: amount));
  }
  return counted;
}

bool budgetHasCountedEntries(Budget budget, LedgerState state) {
  final sourceIDs = state.moneySources.keys.toSet();
  bool countsAnyItem(Entry entry) => Accounting.classify(
    entry,
    sourceIDs,
    state,
  ).any((item) => budgetCountsItemInAnyMonth(budget, item, state));

  return state.entries.values.any(countsAnyItem);
}

Decimal budgetCountedTotal(List<BudgetCountedEntry> counted) =>
    counted.fold(Decimal.zero, (sum, row) => sum + row.amount);
