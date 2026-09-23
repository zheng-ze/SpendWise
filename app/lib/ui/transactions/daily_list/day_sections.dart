import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

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

  return [
    for (final day in days)
      _section(day, byDay[day]!.reversed.toList(), state, sourceScope),
  ];
}

DaySection _section(
  DateTime day,
  List<Entry> dayEntries,
  LedgerState state,
  Set<String>? sourceScope,
) {
  final rows = [
    for (final entry in dayEntries)
      transactionRow(entry, state, scopeIDs: sourceScope),
  ];

  final totals = _totals(dayEntries, state);

  return DaySection(
    date: day,
    rows: rows,
    income: totals.income,
    expenses: totals.expenses,
  );
}

({Decimal income, Decimal expenses}) _totals(
  List<Entry> dayEntries,
  LedgerState state,
) {
  final sourceIDs = state.moneySources.keys.toSet();
  var income = Decimal.zero;
  var expenses = Decimal.zero;

  for (final entry in dayEntries) {
    final contribution = Accounting.totals(entry, state, sourceIDs: sourceIDs);
    income += contribution.income;
    expenses += contribution.expense;
  }

  return (income: income, expenses: expenses);
}
