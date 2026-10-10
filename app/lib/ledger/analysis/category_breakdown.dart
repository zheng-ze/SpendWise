import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

enum BreakdownLevel { categories, subcategories }

@immutable
class BreakdownRow {
  const BreakdownRow({
    required this.bucketID,
    required this.mainBucketID,
    required this.isDirect,
    required this.amount,
  });

  final String? bucketID;

  final String? mainBucketID;

  final bool isDirect;

  final Decimal amount;

  @override
  bool operator ==(Object other) {
    return other is BreakdownRow &&
        other.bucketID == bucketID &&
        other.mainBucketID == mainBucketID &&
        other.isDirect == isDirect &&
        other.amount == amount;
  }

  @override
  int get hashCode => Object.hash(bucketID, mainBucketID, isDirect, amount);
}

@immutable
class PeriodBreakdown {
  const PeriodBreakdown({
    required this.window,
    required this.kind,
    required this.level,
    required this.total,
    required this.rows,
  });

  final DateRange window;

  final CategoryKind kind;

  final BreakdownLevel level;

  final Decimal total;

  final List<BreakdownRow> rows;

  @override
  bool operator ==(Object other) {
    return other is PeriodBreakdown &&
        other.window == window &&
        other.kind == kind &&
        other.level == level &&
        other.total == total &&
        listEquals(other.rows, rows);
  }

  @override
  int get hashCode =>
      Object.hash(window, kind, level, total, Object.hashAll(rows));
}

PeriodBreakdown categoryBreakdown({
  required Iterable<AnalysisItem> items,
  required LedgerState state,
  required DateRange window,
  required CategoryKind kind,
  required BreakdownLevel level,
}) {
  final selected = items
      .where((item) => item.kind == kind && window.contains(item.date))
      .toList();
  final rows = switch (level) {
    BreakdownLevel.categories => _categoryRows(selected, state),
    BreakdownLevel.subcategories => _subcategoryRows(selected, state),
  }.where((row) => row.amount > Decimal.zero).toList()..sort(_compareRows);
  return PeriodBreakdown(
    window: window,
    kind: kind,
    level: level,
    total: selected.fold(Decimal.zero, (sum, item) => sum + item.amount),
    rows: List.unmodifiable(rows),
  );
}

Iterable<BreakdownRow> _categoryRows(
  List<AnalysisItem> items,
  LedgerState state,
) => Accounting.rollUp(items, state).entries.map(
  (entry) => BreakdownRow(
    bucketID: entry.key,
    mainBucketID: entry.key,
    isDirect: false,
    amount: entry.value,
  ),
);

Iterable<BreakdownRow> _subcategoryRows(
  List<AnalysisItem> items,
  LedgerState state,
) {
  final parentIDs = {
    for (final category in state.categories.values) category.parentID,
  };
  final sums = <String?, Decimal>{};
  for (final item in items) {
    final bucketID = normalizedOptionalID(item.bucketID);
    sums[bucketID] = (sums[bucketID] ?? Decimal.zero) + item.amount;
  }
  return sums.entries.map(
    (entry) => BreakdownRow(
      bucketID: entry.key,
      mainBucketID: Accounting.mainBucketID(entry.key, state),
      isDirect: entry.key != null && parentIDs.contains(entry.key),
      amount: entry.value,
    ),
  );
}

int _compareRows(BreakdownRow a, BreakdownRow b) {
  final byAmount = b.amount.compareTo(a.amount);
  if (byAmount != 0) return byAmount;
  final aID = a.bucketID;
  final bID = b.bucketID;
  if (aID != bID) {
    if (aID == null) return 1;
    if (bID == null) return -1;
    return aID.compareTo(bID);
  }
  if (a.isDirect == b.isDirect) return 0;
  return a.isDirect ? 1 : -1;
}
