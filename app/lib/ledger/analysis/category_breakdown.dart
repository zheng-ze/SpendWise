import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

enum BreakdownLevel { categories, subcategories }

const _shareTenths = 1000;

typedef _SizedBucket = ({
  String? bucketID,
  String? mainBucketID,
  bool isDirect,
  Decimal amount,
});

@immutable
class BreakdownRow {
  const BreakdownRow({
    required this.bucketID,
    required this.mainBucketID,
    required this.isDirect,
    required this.amount,
    required this.sharePercent,
  });

  final String? bucketID;

  final String? mainBucketID;

  final bool isDirect;

  final Decimal amount;

  final Decimal sharePercent;

  @override
  bool operator ==(Object other) {
    return other is BreakdownRow &&
        other.bucketID == bucketID &&
        other.mainBucketID == mainBucketID &&
        other.isDirect == isDirect &&
        other.amount == amount &&
        other.sharePercent == sharePercent;
  }

  @override
  int get hashCode =>
      Object.hash(bucketID, mainBucketID, isDirect, amount, sharePercent);
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
  final total = selected.fold(Decimal.zero, (sum, item) => sum + item.amount);
  final sized =
      switch (level) {
          BreakdownLevel.categories => _categoryAmounts(selected, state),
          BreakdownLevel.subcategories => _subcategoryAmounts(selected, state),
        }.where((bucket) => bucket.amount > Decimal.zero).toList()
        ..sort(_compareSized);
  final shares = _largestRemainderShares(sized, total);
  return PeriodBreakdown(
    window: window,
    kind: kind,
    level: level,
    total: total,
    rows: List.unmodifiable([
      for (var index = 0; index < sized.length; index++)
        BreakdownRow(
          bucketID: sized[index].bucketID,
          mainBucketID: sized[index].mainBucketID,
          isDirect: sized[index].isDirect,
          amount: sized[index].amount,
          sharePercent: shares[index],
        ),
    ]),
  );
}

List<_SizedBucket> _categoryAmounts(
  List<AnalysisItem> items,
  LedgerState state,
) => [
  for (final entry in Accounting.rollUp(items, state).entries)
    (
      bucketID: entry.key,
      mainBucketID: entry.key,
      isDirect: false,
      amount: entry.value,
    ),
];

List<_SizedBucket> _subcategoryAmounts(
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
  return [
    for (final entry in sums.entries)
      (
        bucketID: entry.key,
        mainBucketID: Accounting.mainBucketID(entry.key, state),
        isDirect: entry.key != null && parentIDs.contains(entry.key),
        amount: entry.value,
      ),
  ];
}

List<Decimal> _largestRemainderShares(
  List<_SizedBucket> buckets,
  Decimal total,
) {
  if (buckets.isEmpty) return [];
  final bases = <BigInt>[];
  final remainders = <Decimal>[];
  for (final bucket in buckets) {
    final scaled = bucket.amount * Decimal.fromInt(_shareTenths);
    bases.add(scaled ~/ total);
    remainders.add(scaled % total);
  }
  var missing =
      _shareTenths - bases.fold(BigInt.zero, (sum, base) => sum + base).toInt();
  final order = List<int>.generate(buckets.length, (index) => index)
    ..sort((a, b) {
      final byRemainder = remainders[b].compareTo(remainders[a]);
      if (byRemainder != 0) return byRemainder;
      return _compareBucketIdentity(
        buckets[a].bucketID,
        buckets[a].isDirect,
        buckets[b].bucketID,
        buckets[b].isDirect,
      );
    });
  for (var rank = 0; rank < missing; rank++) {
    bases[order[rank]] += BigInt.one;
  }
  return [for (final base in bases) Decimal.fromBigInt(base).shift(-1)];
}

int _compareSized(_SizedBucket a, _SizedBucket b) {
  final byAmount = b.amount.compareTo(a.amount);
  if (byAmount != 0) return byAmount;
  return _compareBucketIdentity(a.bucketID, a.isDirect, b.bucketID, b.isDirect);
}

int _compareBucketIdentity(
  String? aID,
  bool aDirect,
  String? bID,
  bool bDirect,
) {
  if (aID != bID) {
    if (aID == null) return 1;
    if (bID == null) return -1;
    final byID = aID.compareTo(bID);
    if (byID != 0) return byID;
  }
  if (aDirect == bDirect) return 0;
  return aDirect ? 1 : -1;
}
