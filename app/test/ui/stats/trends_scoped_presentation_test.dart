import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/trends/trends_breakdown_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_scoped_presentation.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';

import 'trends_test_support.dart';

final _today = DateTime.utc(2026, 10, 4);
const _foodID = '33333333-3333-3333-3333-333333333333';
const _diningID = '77777777-7777-7777-7777-777777777777';

void main() {
  test(
    'whole period selects its rows, range, total and category source',
    () async {
      final harness = await _rankedHarness();
      final presentation = resolveTrendsScopedPresentation(
        harness.ready,
        TrendsBreakdownScope.wholePeriod,
      );

      expect(presentation.breakdown.rows.first.mainBucketID, _diningID);
      expect(presentation.header.title, 'Expense breakdown');
      expect(presentation.header.range, 'Whole displayed range');
      expect(presentation.header.total, '-S\$900.00');
      expect(
        presentation.categorySource,
        TrendsCategoryDetailSource.wholePeriod,
      );
    },
  );

  test(
    'selected period selects its rows, headline, total and category source',
    () async {
      final harness = await _rankedHarness();
      final presentation = resolveTrendsScopedPresentation(
        harness.ready,
        TrendsBreakdownScope.selectedPeriod,
      );

      expect(presentation.breakdown.rows.first.mainBucketID, _foodID);
      expect(presentation.header.title, 'Expense breakdown');
      expect(presentation.header.range, 'October 2026');
      expect(presentation.header.total, '-S\$100.00');
      expect(
        presentation.categorySource,
        TrendsCategoryDetailSource.selectedPeriod,
      );
    },
  );

  test('selected no-record period formats breakdown total when headline amount is null', () async {
    final harness = await _rankedHarness();
    harness.viewModel.selectSlot(1);
    await harness.settle();
    expect(harness.ready.headline.amount, isNull);

    final presentation = resolveTrendsScopedPresentation(
      harness.ready,
      TrendsBreakdownScope.selectedPeriod,
    );

    expect(presentation.header.range, 'February 2026');
    expect(presentation.header.total, '-S\$0.00');
    expect(presentation.breakdown.total, Decimal.zero);
  });
}

Future<TrendsHarness> _rankedHarness() async {
  final ledger = emptyTrendsLedger();
  ledger.addCategory(
    TransactionCategory(
      id: _diningID,
      name: 'Dining',
      kind: CategoryKind.expense,
      colorHex: '#FF0000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  addTrendsEntry(
    ledger,
    '-500',
    DateTime.utc(2026, 1, 10),
    categoryID: _diningID,
  );
  addTrendsEntry(
    ledger,
    '-300',
    DateTime.utc(2026, 9, 11),
    categoryID: _foodID,
  );
  addTrendsEntry(
    ledger,
    '-100',
    DateTime.utc(2026, 10, 1),
    categoryID: _foodID,
  );
  return readyHarness(ledger: ledger, today: _today);
}
