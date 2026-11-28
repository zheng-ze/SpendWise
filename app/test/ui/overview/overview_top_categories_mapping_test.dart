import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart';
import 'package:spendwise/ui/overview/overview_top_categories_mapping.dart';

import 'overview_fixture.dart';

const _diningID = '66666666-6666-4666-8666-666666666666';
const _transportID = '77777777-7777-4777-8777-777777777777';
const _travelID = '88888888-8888-4888-8888-888888888888';

final _october = DateTime.utc(2026, 10);

Decimal _d(String value) => Decimal.parse(value);

LedgerState _state() {
  final state = emptyState();
  for (final (id, name) in [
    (_diningID, 'Dining'),
    (_transportID, 'Transport'),
    (_travelID, 'Travel'),
  ]) {
    state.addCategory(
      TransactionCategory(
        id: id,
        name: name,
        kind: CategoryKind.expense,
        colorHex: '#112233',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'restaurant',
      ),
    );
  }
  return state;
}

BreakdownRow _row(String? bucketID, String amount) => BreakdownRow(
  bucketID: bucketID,
  mainBucketID: bucketID,
  isDirect: false,
  amount: _d(amount),
  sharePercent: _d('1'),
);

PeriodBreakdown _breakdown(List<BreakdownRow> rows) => PeriodBreakdown(
  window: DateRange(_october, DateTime.utc(2026, 11)),
  kind: CategoryKind.expense,
  level: BreakdownLevel.categories,
  total: _d('100'),
  rows: rows,
);

OverviewTopCategories _map(List<BreakdownRow> rows) =>
    overviewTopCategories(_breakdown(rows), _state(), _october);

void main() {
  test('rows keep read order and are capped at three', () {
    final result = _map([
      _row(_diningID, '83.90'),
      _row(groceriesID, '73.50'),
      _row(_transportID, '10.00'),
      _row(_travelID, '5.00'),
    ]);

    final names = [for (final row in result.rows) row.name];
    expect(names, ['Dining', 'Groceries', 'Transport']);
  });

  test('amounts are negative and bars are relative to the top row', () {
    final result = _map([
      _row(_diningID, '83.90'),
      _row(groceriesID, '73.50'),
      _row(_transportID, '10.00'),
    ]);

    final amounts = [for (final row in result.rows) row.amount];
    final ratios = [for (final row in result.rows) row.barRatio];
    expect(amounts, ['-83.90', '-73.50', '-10.00']);
    expect(ratios[0], 1.0);
    expect(ratios[1], closeTo(0.876, 0.001));
    expect(ratios[2], closeTo(0.119, 0.001));
  });

  test('the caption names the month so far and the label keeps its color', () {
    final result = _map([_row(_diningID, '83.90')]);

    final row = result.rows.single;
    expect(result.caption, 'October so far');
    expect(row.symbolName, 'restaurant');
    expect(row.savedHex, '#112233');
  });

  test('one and two rows render unpadded', () {
    final one = _map([_row(_diningID, '20.00')]);
    final two = _map([_row(_diningID, '20.00'), _row(groceriesID, '10.00')]);

    expect(one.rows, hasLength(1));
    expect(one.rows.single.barRatio, 1.0);
    expect(two.rows, hasLength(2));
    expect(two.rows.last.barRatio, 0.5);
  });

  test('an empty breakdown has no rows and keeps the caption', () {
    final result = _map(const []);

    expect(result.rows, isEmpty);
    expect(result.caption, 'October so far');
  });

  test('uncategorized and transfer buckets keep the History labels', () {
    final transferID = syntheticTransferExpenseBucketID(AccountType.savings);

    final result = _map([_row(null, '30'), _row(transferID, '20')]);

    expect(result.rows[0].name, 'Uncategorized');
    expect(result.rows[0].symbolName, 'help_outline');
    expect(result.rows[0].savedHex, isNull);
    expect(result.rows[1].name, 'Savings transfers');
    expect(result.rows[1].symbolName, 'swap_horiz');
  });
}
