import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/stats/analysis/analysis_scan.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  const foodID = 'a0000000-0000-0000-0000-000000000001';

  AnalysisItem item(Decimal amount, {String? bucketID}) => AnalysisItem(
    bucketID: bucketID ?? foodID,
    amount: amount,
    date: DateTime.utc(2026, 7, 1),
    kind: CategoryKind.expense,
  );

  test('reuses the cached filtered list when the revision is unchanged', () {
    final scan = AnalysisScan();
    final first = [item(dec('10'))];
    final second = [item(dec('99'))];

    final firstResult = scan.scan(
      items: first,
      itemsRevision: 1,
      kind: CategoryKind.expense,
      buckets: {foodID},
    );
    final secondResult = scan.scan(
      items: second,
      itemsRevision: 1,
      kind: CategoryKind.expense,
      buckets: {foodID},
    );

    expect(identical(secondResult, firstResult), true);
    expect(secondResult.single.amount, dec('10'));
  });

  test('recomputes and reflects new items when the revision bumps', () {
    final scan = AnalysisScan();
    final first = [item(dec('10'))];
    final second = [item(dec('99'))];

    scan.scan(
      items: first,
      itemsRevision: 1,
      kind: CategoryKind.expense,
      buckets: {foodID},
    );
    final secondResult = scan.scan(
      items: second,
      itemsRevision: 2,
      kind: CategoryKind.expense,
      buckets: {foodID},
    );

    expect(secondResult.single.amount, dec('99'));
  });

  test('recomputes when the kind changes even with the same revision', () {
    final scan = AnalysisScan();
    final items = [
      item(dec('10')),
      AnalysisItem(
        bucketID: foodID,
        amount: dec('20'),
        date: DateTime.utc(2026, 7, 1),
        kind: CategoryKind.income,
      ),
    ];

    final expenseResult = scan.scan(
      items: items,
      itemsRevision: 1,
      kind: CategoryKind.expense,
      buckets: {foodID},
    );
    final incomeResult = scan.scan(
      items: items,
      itemsRevision: 1,
      kind: CategoryKind.income,
      buckets: {foodID},
    );

    expect(expenseResult.single.amount, dec('10'));
    expect(incomeResult.single.amount, dec('20'));
  });

  test(
    'recomputes when the bucket filter changes even with the same revision',
    () {
      final scan = AnalysisScan();
      const otherID = 'a0000000-0000-0000-0000-000000000002';
      final items = [item(dec('10')), item(dec('30'), bucketID: otherID)];

      final foodResult = scan.scan(
        items: items,
        itemsRevision: 1,
        kind: CategoryKind.expense,
        buckets: {foodID},
      );
      final otherResult = scan.scan(
        items: items,
        itemsRevision: 1,
        kind: CategoryKind.expense,
        buckets: {otherID},
      );

      expect(foodResult.single.amount, dec('10'));
      expect(otherResult.single.amount, dec('30'));
    },
  );
}
