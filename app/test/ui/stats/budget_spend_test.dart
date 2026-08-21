import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/stats/budget_spend.dart';

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

  final month = const YearMonth(2026, 7);

  Budget budget(String? categoryID) => Budget(
    categoryID: categoryID,
    limitEvents: [
      LimitEvent(
        kind: LimitEventKind.defaultLimit,
        value: dec('100'),
        effectiveFromMonth: null,
      ),
    ],
    createdAtMonth: month,
  );

  AnalysisItem item(String? bucketID, String amount, {CategoryKind? kind}) =>
      AnalysisItem(
        bucketID: bucketID,
        amount: dec(amount),
        date: DateTime.utc(2026, 7, 15),
        kind: kind ?? CategoryKind.expense,
      );

  test('a parent budget picks up each child\'s spend that month', () {
    final items = [item(foodID, '30'), item(hawkerID, '20')];

    final spend = budgetSpend(budget(foodID), month, items, state);

    expect(spend, dec('50'));
  });

  test('a budget on a subcategory and a budget on its parent both count the '
      'shared child entry independently', () {
    final items = [item(hawkerID, '20')];

    final parentSpend = budgetSpend(budget(foodID), month, items, state);
    final childSpend = budgetSpend(budget(hawkerID), month, items, state);

    expect(parentSpend, dec('20'));
    expect(childSpend, dec('20'));
  });

  test('an overall budget sums every category including uncategorized', () {
    final items = [
      item(foodID, '30'),
      item(transportID, '10'),
      item(null, '5'),
    ];

    final spend = budgetSpend(budget(null), month, items, state);

    expect(spend, dec('45'));
  });

  test('a month with no matching spend returns zero, not an error', () {
    final spend = budgetSpend(budget(foodID), month, <AnalysisItem>[], state);

    expect(spend, Decimal.zero);
  });

  test('an income item does not count toward any budget, even overall', () {
    final items = [item(null, '999', kind: CategoryKind.income)];

    final spend = budgetSpend(budget(null), month, items, state);

    expect(spend, Decimal.zero);
  });
}
