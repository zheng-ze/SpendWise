import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ui/transactions/transaction_row.dart';

@immutable
class DaySection {
  const DaySection({
    required this.date,
    required this.rows,
    required this.income,
    required this.expenses,
  });

  final DateTime date;
  final List<TransactionRow> rows;
  final Decimal income;
  final Decimal expenses;
}

List<DaySection> daySections(
  Iterable<Entry> entries,
  LedgerState state, {
  DateRange? interval,
  Set<String>? sourceScope,
}) {
  final scoped = sourceScope == null
      ? entries
      : entries.where((entry) => entry.touches(sourceScope));

  final byDay = <DateTime, List<Entry>>{};
  for (final entry in scoped) {
    if (interval != null && !interval.contains(entry.date)) continue;

    final day = startOfDayUtc(entry.date);
    (byDay[day] ??= []).add(entry);
  }

  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

  // A domain entry only carries a calendar day, not a time of day, so there
  // is no timestamp to sort same-day rows by. Input order is treated as
  // creation order and reversed, since insertion order is what LedgerState
  // preserves as entries are added.
  return [
    for (final day in days) _section(day, byDay[day]!.reversed.toList(), state),
  ];
}

DaySection _section(DateTime day, List<Entry> dayEntries, LedgerState state) {
  final rows = [for (final entry in dayEntries) transactionRow(entry, state)];

  final totals = _totals(dayEntries);

  return DaySection(
    date: day,
    rows: rows,
    income: totals.income,
    expenses: totals.expenses,
  );
}

/// Section totals apply only this entry-level flag, never a category gate.
({Decimal income, Decimal expenses}) _totals(List<Entry> dayEntries) {
  var income = Decimal.zero;
  var expenses = Decimal.zero;

  for (final entry in dayEntries) {
    if (entry.isTransfer || !entry.includeInAnalysis) continue;

    if (entry.amount < Decimal.zero) {
      expenses -= entry.amount;
    } else {
      income += entry.amount;
    }
  }

  return (income: income, expenses: expenses);
}
