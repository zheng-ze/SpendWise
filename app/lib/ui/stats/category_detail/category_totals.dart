import 'package:domain/domain.dart';

// MARK: - CategoryTotals
class CategoryTotals {
  const CategoryTotals({
    required this.mainTotal,
    required this.childTotals,
    required this.directTotal,
    required this.scopeTotal,
  });

  final Decimal mainTotal;
  final Map<String, Decimal> childTotals;
  final Decimal directTotal;
  final Decimal scopeTotal;

  factory CategoryTotals.compute({
    required Iterable<AnalysisItem> scanned,
    required List<TransactionCategory> children,
    required DateRange window,
    required Set<String?> scopedBuckets,
  }) {
    final windowed = scanned.where((item) => window.contains(item.date));

    final mainTotal = windowed.fold(
      Decimal.zero,
      (sum, item) => sum + item.amount,
    );
    final childTotals = {
      for (final category in children)
        category.id: _sumBucket(windowed, category.id),
    };
    final childSum = childTotals.values.fold(
      Decimal.zero,
      (sum, amount) => sum + amount,
    );
    final directTotal = mainTotal - childSum;

    final scopeTotal = windowed
        .where((item) => scopedBuckets.contains(item.bucketID))
        .fold(Decimal.zero, (sum, item) => sum + item.amount);

    return CategoryTotals(
      mainTotal: mainTotal,
      childTotals: childTotals,
      directTotal: directTotal,
      scopeTotal: scopeTotal,
    );
  }
}

// MARK: - Helpers
Decimal _sumBucket(Iterable<AnalysisItem> items, String bucketID) {
  return items
      .where((item) => item.bucketID == bucketID)
      .fold(Decimal.zero, (sum, item) => sum + item.amount);
}
