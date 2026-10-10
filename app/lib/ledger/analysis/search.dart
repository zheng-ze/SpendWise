import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/entry_record.dart';
import 'package:spendwise/ledger/analysis/register.dart';

@immutable
class SearchMonth {
  const SearchMonth({
    required this.month,
    required this.matches,
    required this.income,
    required this.expense,
    required this.net,
    required this.moved,
  });

  final YearMonth month;
  final List<EntryRecord> matches;
  final Decimal income;
  final Decimal expense;
  final Decimal net;
  final Decimal moved;

  @override
  bool operator ==(Object other) {
    return other is SearchMonth &&
        other.month == month &&
        other.matches == matches &&
        other.income == income &&
        other.expense == expense &&
        other.net == net &&
        other.moved == moved;
  }

  @override
  int get hashCode => Object.hash(month, matches, income, expense, net, moved);
}

List<SearchMonth> searchEntries({
  required LedgerState ledger,
  required String query,
  DateRange? window,
  Set<String>? sourceIDs,
  EntryKind? kind,
}) {
  final range = window == null ? null : normalizedWindow(window);
  final complete = ledger.moneySources.keys.toSet();
  final scope = normalizedScope(sourceIDs);
  final needle = query.trim().toLowerCase();
  final indexed = <({int index, Entry entry})>[];
  var index = 0;
  for (final entry in ledger.entries.values) {
    if (entry.lifecycle.isActive &&
        inScope(entry, scope) &&
        (kind == null || entry.kind == kind) &&
        (range == null || range.contains(entry.date)) &&
        _matches(ledger, entry, needle)) {
      indexed.add((index: index, entry: entry));
    }
    index++;
  }
  indexed.sort((a, b) {
    final byDate = b.entry.date.compareTo(a.entry.date);
    if (byDate != 0) return byDate;
    return b.index.compareTo(a.index);
  });
  final byMonth = <YearMonth, List<Entry>>{};
  for (final item in indexed) {
    final month = YearMonth.fromUtc(item.entry.date);
    (byMonth[month] ??= []).add(item.entry);
  }
  final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
  return List.unmodifiable([
    for (final month in months)
      _searchMonth(
        ledger,
        month,
        byMonth[month]!,
        complete: complete,
        scope: scope,
      ),
  ]);
}

SearchMonth _searchMonth(
  LedgerState ledger,
  YearMonth month,
  List<Entry> matches, {
  required Set<String> complete,
  Set<String>? scope,
}) {
  final totals = registerTotals(
    ledger,
    matches,
    complete: complete,
    scope: scope,
  );
  return SearchMonth(
    month: month,
    matches: List.unmodifiable([
      for (final entry in matches) entryRecord(ledger, entry),
    ]),
    income: totals.income,
    expense: totals.expense,
    net: totals.net,
    moved: totals.moved,
  );
}

bool _matches(LedgerState ledger, Entry entry, String needle) {
  if (needle.isEmpty) return true;
  if (entry.name.toLowerCase().contains(needle)) return true;
  final category = entry.categoryID == null
      ? null
      : ledger.categories[entry.categoryID];
  if (category != null) {
    if (category.name.toLowerCase().contains(needle)) return true;
    final parentID = category.parentID;
    final parent = parentID == null ? null : ledger.categories[parentID];
    if (parent != null && parent.name.toLowerCase().contains(needle)) {
      return true;
    }
  }
  final source = ledger.sourceName(entry.sourceID);
  if (source != null && source.toLowerCase().contains(needle)) return true;
  final destination = ledger.sourceName(entry.destinationID);
  if (destination != null && destination.toLowerCase().contains(needle)) {
    return true;
  }
  return false;
}
