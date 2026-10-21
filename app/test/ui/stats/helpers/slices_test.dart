import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/stats/helpers/slices.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  const foodID = 'a0000000-0000-0000-0000-000000000001';
  const hawkerID = 'a0000000-0000-0000-0000-000000000002';
  const transportID = 'a0000000-0000-0000-0000-000000000003';

  final state = LedgerState(
    categories: {
      foodID: TransactionCategory(
        id: foodID,
        name: 'Food',
        kind: CategoryKind.expense,
        colorHex: '#FF0000',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'restaurant',
      ),
      hawkerID: TransactionCategory(
        id: hawkerID,
        name: 'Hawker',
        kind: CategoryKind.expense,
        colorHex: '#00FF00',
        includeInAnalysis: true,
        parentID: foodID,
        symbol: 'ramen_dining',
      ),
      transportID: TransactionCategory(
        id: transportID,
        name: 'Transport',
        kind: CategoryKind.expense,
        colorHex: '#0000FF',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'directions_bus',
      ),
    },
  );

  final window = DateRange(DateTime.utc(2026, 7), DateTime.utc(2026, 8));

  AnalysisItem item(String? bucketID, String amount, {CategoryKind? kind}) =>
      AnalysisItem(
        bucketID: bucketID,
        amount: dec(amount),
        date: DateTime.utc(2026, 7, 15),
        kind: kind ?? CategoryKind.expense,
      );

  test('rolls subcategories into parents and sorts by total descending', () {
    final items = [
      item(transportID, '10'),
      item(foodID, '30'),
      item(hawkerID, '20'),
    ];

    final result = slices(items, CategoryKind.expense, window, state);

    expect(result.map((slice) => slice.bucketID), [foodID, transportID]);
    expect(result.first.bucketID, foodID);
    expect(result.first.amount, dec('50'));
  });

  test('buckets null category as uncategorized', () {
    final items = [item(null, '15')];

    final result = slices(items, CategoryKind.expense, window, state);

    expect(result.single.bucketID, null);
    expect(result.single.amount, dec('15'));
    expect(result.single.name, 'Uncategorized');
  });

  test('excludes items of the other kind and outside the window', () {
    final wrongKind = item(foodID, '40', kind: CategoryKind.income);
    final outOfWindow = AnalysisItem(
      bucketID: foodID,
      amount: dec('40'),
      date: DateTime.utc(2026, 6, 15),
      kind: CategoryKind.expense,
    );
    final inWindow = item(foodID, '25');

    final result = slices(
      [wrongKind, outOfWindow, inWindow],
      CategoryKind.expense,
      window,
      state,
    );

    expect(result.single.amount, dec('25'));
  });

  test('computes fraction of the total', () {
    final items = [item(foodID, '30'), item(transportID, '70')];

    final result = slices(items, CategoryKind.expense, window, state);

    final food = result.firstWhere((s) => s.bucketID == foodID);
    final transport = result.firstWhere((s) => s.bucketID == transportID);
    expect(food.fraction, dec('0.3'));
    expect(transport.fraction, dec('0.7'));
  });

  test('zero total guards fractions instead of throwing or producing NaN', () {
    final items = [item(foodID, '0')];

    final result = slices(items, CategoryKind.expense, window, state);

    expect(result.single.amount, Decimal.zero);
    expect(result.single.fraction, Decimal.zero);
  });

  test('a synthetic bucket keeps its own ID and label', () {
    final syntheticID = syntheticTransferExpenseBucketID(AccountType.savings);
    final items = [item(syntheticID, '15')];

    final result = slices(items, CategoryKind.expense, window, state);

    expect(result.single.bucketID, syntheticID);
    expect(result.single.name, isNot('Uncategorized'));
  });
}
