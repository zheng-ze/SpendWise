import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_counted_entries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/daily_list/day_header.dart';
import 'package:spendwise/ui/transactions/daily_list/entry_row.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

// MARK: - Constants
const _registerDayGap = 10.0;

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
        for (final (index, day) in days.indexed) ...[
          if (index > 0) const SizedBox(height: _registerDayGap),
          _BudgetDayGroup(
            day: day,
            rows: byDay[day]!,
            ledger: ledger,
            state: state,
          ),
        ],
      ],
    );
  }
}

// MARK: - BudgetDayGroup
class _BudgetDayGroup extends StatelessWidget {
  const _BudgetDayGroup({
    required this.day,
    required this.rows,
    required this.ledger,
    required this.state,
  });

  final DateTime day;
  final List<BudgetCountedEntry> rows;
  final Ledger ledger;
  final LedgerState state;

  @override
  Widget build(BuildContext context) {
    final newestFirst = rows.reversed.toList();
    return Column(
      children: [
        DayHeader.register(day: day, net: -budgetCountedTotal(rows)),
        for (final (index, row) in newestFirst.indexed)
          EntryRow(
            row: transactionRow(row.entry, state),
            ledger: ledger,
            state: state,
            registerStyle: true,
            isLastInDay: index == newestFirst.length - 1,
          ),
      ],
    );
  }
}
