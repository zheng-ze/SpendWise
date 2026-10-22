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
const _transportName = 'Transport';
const _diningName = 'Dining';
const _parentCategoryName = 'Food';
const _transportAmount = '-25.00';
const _diningAmount = '-5.00';
const _unavailableAverage = 'Unavailable';
const _zeroAverage = '0.00';
const _monthPeriodLabel = 'Oct 2026';
const _yearPeriodLabel = '2026';
const _monthlyAverageLabel = 'Monthly average';
const _yearlyAverageLabel = 'Yearly average';
final _period = DateTime.utc(2026, 10);

void main() {
  testWidgets(
    'shows selected amounts and unavailable or zero monthly averages',
    (tester) async {
      await _pumpAverages(tester, mode: TrendsMode.month);

      expect(find.text(_monthPeriodLabel), findsOneWidget);
      expect(find.text(_monthlyAverageLabel), findsOneWidget);
      expect(find.text('-25.00'), findsOneWidget);
      expect(find.text('-5.00'), findsOneWidget);
      expect(find.text(_unavailableAverage), findsOneWidget);
      expect(find.text(_zeroAverage), findsOneWidget);
      expect(find.text(_parentCategoryName), findsNWidgets(2));
    },
  );

  testWidgets('labels year amounts and averages with the selected year', (
    tester,
  ) async {
    await _pumpAverages(tester, mode: TrendsMode.year);

    expect(find.text(_yearPeriodLabel), findsOneWidget);
    expect(find.text(_yearlyAverageLabel), findsOneWidget);
  });

  testWidgets('category taps report the selected-row index', (tester) async {
    int? openedIndex;
    await _pumpAverages(
      tester,
      mode: TrendsMode.month,
      onOpenCategory: (index) => openedIndex = index,
    );

    await tester.tap(find.text(_diningName));
    expect(openedIndex, 1);
  }, timeout: _interactionTimeout);

  testWidgets('preserves the selected-row order', (tester) async {
    await _pumpAverages(tester, mode: TrendsMode.month);

    final transportTop = tester.getTopLeft(find.text(_transportName)).dy;
    final diningTop = tester.getTopLeft(find.text(_diningName)).dy;

    expect(transportTop, lessThan(diningTop));
  });

  testWidgets('keeps each selected amount paired with its average', (
    tester,
  ) async {
    await _pumpAverages(tester, mode: TrendsMode.month);

    final transportRow = _tappableRow(_transportName);
    final diningRow = _tappableRow(_diningName);

    expect(
      find.descendant(of: transportRow, matching: find.text(_transportAmount)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: transportRow,
        matching: find.text(_unavailableAverage),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: diningRow, matching: find.text(_diningAmount)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: diningRow, matching: find.text(_zeroAverage)),
      findsOneWidget,
    );
  });

  testWidgets('category rows without a navigation target report no tap', (
    tester,
  ) async {
    int? openedIndex;
    await _pumpAverages(
      tester,
      mode: TrendsMode.month,
      diningNavigable: false,
      onOpenCategory: (index) => openedIndex = index,
    );

    await tester.tap(find.text(_diningName));

    expect(openedIndex, isNull);
  }, timeout: _interactionTimeout);
}

Finder _tappableRow(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

Future<void> _pumpAverages(
  WidgetTester tester, {
  required TrendsMode mode,
  ValueChanged<int>? onOpenCategory,
  bool diningNavigable = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSpendWiseTheme(Brightness.light),
      home: Scaffold(
        body: TrendsCategoryAverages(
          breakdown: _breakdown(mode, diningNavigable: diningNavigable),
          averageComparison: _comparison(mode),
          onOpenCategory: onOpenCategory ?? (_) {},
        ),
      ),
    ),
  );
}

TrendsBreakdown _breakdown(TrendsMode mode, {bool diningNavigable = true}) =>
    TrendsBreakdown(
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
        _row(_transportName, 'transport', _transportAmount, mode),
        _row(
          _diningName,
          'dining',
          _diningAmount,
          mode,
          navigable: diningNavigable,
        ),
      ],
    );

TrendsBreakdownRow _row(
  String name,
  String id,
  String amount,
  TrendsMode mode, {
  bool navigable = true,
}) => (
  bucketID: id,
  mainBucketID: id,
  isDirect: false,
  name: name,
  parentContext: _parentCategoryName,
  savedHex: null,
  amount: Decimal.parse(amount),
  sharePercent: Decimal.fromInt(50),
  formattedAmount: amount,
  formattedShare: '50.0%',
  navigationTarget: navigable
      ? CategoryDetailArgs(
          mainID: id,
          kind: CategoryKind.expense,
          isYearRange: mode == TrendsMode.year,
          initialDate: _period,
        )
      : null,
);

TrendsAverageComparison _comparison(TrendsMode mode) => TrendsAverageComparison(
  header: mode == TrendsMode.month ? _monthlyAverageLabel : _yearlyAverageLabel,
  rows: [
    TrendsAverageComparisonRow(
      bucketID: 'transport',
      mainBucketID: 'transport',
      isDirect: false,
      mean: null,
      formattedMean: _unavailableAverage,
    ),
    TrendsAverageComparisonRow(
      bucketID: 'dining',
      mainBucketID: 'dining',
      isDirect: false,
      mean: Decimal.zero,
      formattedMean: _zeroAverage,
    ),
  ],
);
