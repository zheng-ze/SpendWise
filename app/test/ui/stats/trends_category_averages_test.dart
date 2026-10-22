import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/settings/display_preferences.dart' as settings;
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_average_comparison.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/stats/trends/trends_category_averages.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

const _interactionTimeout = Timeout(Duration(seconds: 5));
final _period = DateTime.utc(2026, 10);

void main() {
  testWidgets(
    'shows selected amounts and unavailable or zero monthly averages',
    (tester) async {
      await _pumpAverages(tester, mode: TrendsMode.month);

      expect(find.text('Oct 2026'), findsOneWidget);
      expect(find.text('Monthly average'), findsOneWidget);
      expect(find.text('-25.00'), findsOneWidget);
      expect(find.text('-5.00'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('Food'), findsNWidgets(2));
    },
  );

  testWidgets('labels year amounts and averages with the selected year', (
    tester,
  ) async {
    await _pumpAverages(tester, mode: TrendsMode.year);

    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Yearly average'), findsOneWidget);
  });

  testWidgets('category taps report the selected-row index', (tester) async {
    int? openedIndex;
    await _pumpAverages(
      tester,
      mode: TrendsMode.month,
      onOpenCategory: (index) => openedIndex = index,
    );

    await tester.tap(find.text('Dining'));
    expect(openedIndex, 1);
  }, timeout: _interactionTimeout);
}

Future<void> _pumpAverages(
  WidgetTester tester, {
  required TrendsMode mode,
  ValueChanged<int>? onOpenCategory,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSpendWiseTheme(Brightness.light),
      home: Scaffold(
        body: TrendsCategoryAverages(
          breakdown: _breakdown(mode),
          averageComparison: _comparison(mode),
          onOpenCategory: onOpenCategory ?? (_) {},
        ),
      ),
    ),
  );
}

TrendsBreakdown _breakdown(TrendsMode mode) => TrendsBreakdown(
  sourceRevision: 1,
  period: _period,
  kind: CategoryKind.expense,
  mode: mode,
  preferences: (
    chart: settings.BreakdownChart.donut,
    level: settings.BreakdownLevel.categories,
    colours: settings.ChartColours.categoryColours,
  ),
  total: Decimal.fromInt(30),
  rows: [
    _row('Transport', 'transport', '-25.00', mode),
    _row('Dining', 'dining', '-5.00', mode),
  ],
);

TrendsBreakdownRow _row(
  String name,
  String id,
  String amount,
  TrendsMode mode,
) => (
  bucketID: id,
  mainBucketID: id,
  isDirect: false,
  name: name,
  parentContext: 'Food',
  savedHex: null,
  amount: Decimal.parse(amount),
  sharePercent: Decimal.fromInt(50),
  formattedAmount: amount,
  formattedShare: '50.0%',
  navigationTarget: CategoryDetailArgs(
    mainID: id,
    kind: CategoryKind.expense,
    isYearRange: mode == TrendsMode.year,
    initialDate: _period,
  ),
);

TrendsAverageComparison _comparison(TrendsMode mode) => TrendsAverageComparison(
  header: mode == TrendsMode.month ? 'Monthly average' : 'Yearly average',
  rows: [
    TrendsAverageComparisonRow(
      bucketID: 'transport',
      mainBucketID: 'transport',
      isDirect: false,
      mean: null,
      formattedMean: 'Unavailable',
    ),
    TrendsAverageComparisonRow(
      bucketID: 'dining',
      mainBucketID: 'dining',
      isDirect: false,
      mean: Decimal.zero,
      formattedMean: '0.00',
    ),
  ],
);
