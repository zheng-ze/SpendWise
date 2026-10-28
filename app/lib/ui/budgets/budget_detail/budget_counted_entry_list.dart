import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_counted_entries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/daily_list/day_header.dart';
import 'package:spendwise/ui/transactions/daily_list/entry_row.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

// MARK: - BudgetCountedEntryList
class BudgetCountedEntryList extends StatelessWidget {
  const BudgetCountedEntryList({
    super.key,
    required this.ledger,
    required this.state,
    required this.counted,
  });

  final Ledger ledger;
  final LedgerState state;
  final List<BudgetCountedEntry> counted;

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, List<BudgetCountedEntry>>{};
    for (final row in counted) {
      (byDay[startOfDayUtc(row.entry.date)] ??= []).add(row);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        for (final day in days) ...[
          DayHeader(day: day, net: -budgetCountedTotal(byDay[day]!)),
          for (final row in byDay[day]!.reversed)
            EntryRow(
              row: transactionRow(row.entry, state),
              ledger: ledger,
              state: state,
            ),
        ],
      ],
    );
  }
}
