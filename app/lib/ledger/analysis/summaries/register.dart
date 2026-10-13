import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/entry_record.dart';
import 'package:spendwise/ledger/analysis/scope.dart';

export 'package:spendwise/ledger/analysis/summaries/recent.dart';

// MARK: - Days

@immutable
class RegisterDay {
  const RegisterDay({
    required this.date,
    required this.entries,
    required this.income,
    required this.expense,
    required this.net,
    required this.moved,
  });

  final DateTime date;
  final List<EntryRecord> entries;
  final Decimal income;
  final Decimal expense;
  final Decimal net;
  final Decimal moved;

  @override
  bool operator ==(Object other) {
    return other is RegisterDay &&
        other.date == date &&
        other.entries == entries &&
        other.income == income &&
        other.expense == expense &&
        other.net == net &&
        other.moved == moved;
  }

  @override
  int get hashCode => Object.hash(date, entries, income, expense, net, moved);
}

// MARK: - Queries

List<RegisterDay> registerDays({
  required LedgerState ledger,
  required DateRange window,
  Set<String>? sourceIDs,
  EntryKind? kind,
}) {
  final range = normalizedWindow(window);
  final complete = ledger.moneySources.keys.toSet();
  final scope = normalizedScope(sourceIDs);
  final byDay = <DateTime, List<Entry>>{};
  for (final entry in ledger.entries.values) {
    if (!entry.lifecycle.isActive) continue;
    if (!inScope(entry, scope)) continue;
    if (kind != null && entry.kind != kind) continue;
    if (!range.contains(entry.date)) continue;
    final day = startOfDayUtc(entry.date);
    (byDay[day] ??= []).add(entry);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return List.unmodifiable([
    for (final day in days)
      registerDay(
        ledger,
        day,
        byDay[day]!.reversed.toList(),
        complete: complete,
        scope: scope,
      ),
  ]);
}

RegisterDay registerDay(
  LedgerState ledger,
  DateTime day,
  List<Entry> dayEntries, {
  required Set<String> complete,
  Set<String>? scope,
}) {
  final totals = registerTotals(
    ledger,
    dayEntries,
    complete: complete,
    scope: scope,
  );
  return RegisterDay(
    date: day,
    entries: List.unmodifiable([
      for (final entry in dayEntries) entryRecord(ledger, entry),
    ]),
    income: totals.income,
    expense: totals.expense,
    net: totals.net,
    moved: totals.moved,
  );
}

({Decimal income, Decimal expense, Decimal net, Decimal moved}) registerTotals(
  LedgerState ledger,
  List<Entry> entries, {
  required Set<String> complete,
  Set<String>? scope,
}) {
  var income = Decimal.zero;
  var expense = Decimal.zero;
  var moved = Decimal.zero;
  for (final entry in entries) {
    final contribution = Accounting.totals(entry, ledger, sourceIDs: complete);
    income += contribution.income;
    expense += contribution.expense;
    if (entry.isTransfer) {
      final applies = scope == null
          ? Accounting.applies(entry, complete)
          : entry.touches(scope);
      if (applies) moved += entry.amount.abs();
    }
  }
  return (
    income: income,
    expense: expense,
    net: income - expense,
    moved: moved,
  );
}
