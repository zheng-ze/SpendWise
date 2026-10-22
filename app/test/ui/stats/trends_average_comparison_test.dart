import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/summaries/trends_period.dart';
import 'package:spendwise/settings/display_preferences.dart' as settings;
import 'package:spendwise/ui/stats/trends/trends_average_comparison.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

import 'trends_test_support.dart';

void main() {
  test('joins averages by full identity in selected-row order', () {
    final selected = _breakdown([
      _row('shared', 'main', false),
      _row('shared', 'main', true),
    ]);
    final comparison = projectTrendsAverageComparison(
      breakdown: selected,
      averages: [
        _average('shared', 'main', true, Decimal.fromInt(20)),
        _average('shared', 'main', false, Decimal.fromInt(10)),
      ],
      mode: TrendsMode.month,
      kind: CategoryKind.expense,
    );

    expect(comparison?.header, 'Monthly average');
    expect(comparison?.rows.map((row) => row.isDirect), [false, true]);
    expect(comparison?.rows.map((row) => row.formattedMean), [
      '-10.00',
      '-20.00',
    ]);
  });

  test('preserves a zero mean and renders a null mean as unavailable', () {
    final comparison = projectTrendsAverageComparison(
      breakdown: _breakdown([_row('a', 'a', false), _row('b', 'b', false)]),
      averages: [
        _average('a', 'a', false, Decimal.zero),
        _average('b', 'b', false, null),
      ],
      mode: TrendsMode.year,
      kind: CategoryKind.expense,
    );

    expect(comparison?.header, 'Yearly average');
    expect(comparison?.rows.map((row) => row.formattedMean), [
      '-0.00',
      'Unavailable',
    ]);
  });

  test('rejects a missing selected identity', () {
    final comparison = projectTrendsAverageComparison(
      breakdown: _breakdown([_row('missing', 'missing', false)]),
      averages: [],
      mode: TrendsMode.month,
      kind: CategoryKind.expense,
    );

    expect(comparison, isNull);
  });

  test('rejects a duplicated average identity', () {
    final comparison = projectTrendsAverageComparison(
      breakdown: _breakdown([_row('a', 'a', false)]),
      averages: [
        _average('a', 'a', false, Decimal.one),
        _average('a', 'a', false, Decimal.one),
      ],
      mode: TrendsMode.month,
      kind: CategoryKind.expense,
    );

    expect(comparison, isNull);
  });

  test(
    'ready month and year bodies retain their mode-specific usual data',
    () async {
      final today = DateTime.utc(2026, 10, 3);
      final harness = await readyHarness(
        ledger: seededTrendsLedger(today),
        today: today,
      );

      expect(harness.ready.averageComparison.header, 'Monthly average');
      expect(harness.ready.usual, isNotNull);

      harness.viewModel.setMode(TrendsMode.year);
      await harness.settle();

      expect(harness.ready.averageComparison.header, 'Yearly average');
      expect(harness.ready.usual, isNull);
    },
  );
}

TrendsBreakdown _breakdown(List<TrendsBreakdownRow> rows) => TrendsBreakdown(
  sourceRevision: 1,
  period: DateTime.utc(2026, 10),
  kind: CategoryKind.expense,
  mode: TrendsMode.month,
  preferences: (
    chart: settings.BreakdownChart.donut,
    level: settings.BreakdownLevel.categories,
    colours: settings.ChartColours.categoryColours,
  ),
  total: Decimal.fromInt(30),
  rows: rows,
);

TrendsBreakdownRow _row(String bucketID, String mainBucketID, bool isDirect) =>
    (
      bucketID: bucketID,
      mainBucketID: mainBucketID,
      isDirect: isDirect,
      name: bucketID,
      parentContext: null,
      savedHex: null,
      amount: Decimal.fromInt(1),
      sharePercent: Decimal.fromInt(100),
      formattedAmount: '-1.00',
      formattedShare: '100.0%',
      navigationTarget: null,
    );

CategoryPeriodAverage _average(
  String bucketID,
  String mainBucketID,
  bool isDirect,
  Decimal? mean,
) => CategoryPeriodAverage(
  bucketID: bucketID,
  mainBucketID: mainBucketID,
  isDirect: isDirect,
  numerator: Decimal.zero,
  mean: mean,
);
