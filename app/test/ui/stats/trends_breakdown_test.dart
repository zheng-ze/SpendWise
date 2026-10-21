import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/common/charts/donut_chart.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_section.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/common/charts/category_map.dart';

import '../../support/ui_test_timeout.dart';
import 'trends_test_support.dart';

final _today = DateTime.utc(2026, 10, 3);

void main() {
  _frameTests();
  _preferenceTests();
  _boundaryTests();
  _rankTests();
  _longNameTests();
  testWidgets('tr-oct-map shows ranked categories and tiny map labels', (
    tester,
  ) async {
    await pumpTrends(
      tester,
      ledger: seededTrendsLedger(_today),
      today: _today,
      preferences: DisplayPreferences(
        breakdownChart: BreakdownChart.categoryMap,
      ),
    );

    expect(find.text('Expense breakdown'), findsOneWidget);
    expect(find.text('By category'), findsOneWidget);
    _expectRows(
      tester,
      names: _octoberNames,
      amounts: _octoberAmounts,
      shares: _octoberShares,
      total: '167.40',
    );
    expect(find.text('-83.90'), findsOneWidget);
    expect(find.text('-73.50'), findsOneWidget);
    expect(find.text('-10.00'), findsOneWidget);
    final map = tester.widget<CategoryMap>(find.byType(CategoryMap));
    expect(map.tiles.map((tile) => tile.label), [
      'Dining',
      'Groceries',
      'Transport',
    ]);
    expect(map.tiles.map((tile) => tile.share), [0.501, 0.439, 0.06]);
    expect(map.onSelect, isNull);
    expect(map.selectedIndex, isNull);
    expect(find.text('Transport 6.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);
}

const _octoberNames = ['Dining', 'Groceries', 'Transport'];
const _octoberAmounts = ['83.90', '73.50', '10.00'];
const _octoberShares = ['50.1%', '43.9%', '6.0%'];
const _subNames = [
  'Dining',
  'Supermarket',
  'Fresh Market',
  'Direct to Groceries',
  'Transport',
];
const _subAmounts = ['83.90', '42.50', '18.60', '12.40', '10.00'];
const _subShares = ['50.1%', '25.4%', '11.1%', '7.4%', '6.0%'];
const _julyAmounts = ['432.00', '324.00', '144.00'];
const _yearAmounts = ['3009.60', '2257.20', '1003.20'];
const _sampleShares = ['48.0%', '36.0%', '16.0%'];
const _swatchExtent = 10.0;
const _scrollStep = 200.0;
const _shareTotal = '100';
const _tinyAmount = '0.01';

Finder get _section => find.byType(TrendsBreakdownSection);

Finder _inSection(Finder matching) =>
    find.descendant(of: _section, matching: matching);

TrendsReadyBody _ready(WidgetTester tester) {
  final context = tester.element(find.byType(TrendsBreakdownSection));
  final container = ProviderScope.containerOf(context);
  final body = container.read(trendsViewModelProvider).requireValue;
  if (body is TrendsReadyBody) return body;
  throw StateError('Expected a ready Trends body, found $body');
}

Future<void> _selectPeriod(WidgetTester tester, String label) async {
  final slot = find.bySemanticsLabel(label);
  await tester.ensureVisible(slot);
  await tester.tap(slot);
  await tester.pumpAndSettle();
}

Future<void> _chooseIncome(WidgetTester tester) async {
  await tester.tap(find.text('Income'));
  await tester.pumpAndSettle();
}

void _expectRows(
  WidgetTester tester, {
  required List<String> names,
  required List<String> amounts,
  required List<String> shares,
  required String total,
  bool income = false,
}) {
  final body = _ready(tester);
  final rows = body.breakdown.rows;
  expect(rows.map((row) => row.name), names);
  expect(rows.map((row) => row.amount), amounts.map(Decimal.parse));
  expect(rows.map((row) => row.formattedShare), shares);
  final signedAmounts = [
    for (final amount in amounts)
      '${income ? '+' : '-'}${formatMoney(Decimal.parse(amount), symbol: false)}',
  ];
  expect(rows.map((row) => row.formattedAmount), signedAmounts);
  final sum = rows.fold(Decimal.zero, (sum, row) => sum + row.amount);
  final share = rows.fold(Decimal.zero, (sum, row) => sum + row.sharePercent);
  expect(sum, Decimal.parse(total));
  expect(body.breakdown.total, sum);
  expect(share, Decimal.parse(_shareTotal));
  expect(body.bars[body.selectedIndex].value, sum.toDouble());
  for (final row in rows) {
    final amount = _inSection(find.text(row.formattedAmount));
    expect(amount, findsOneWidget);
    final text = tester.widget<Text>(amount);
    final colors = income
        ? SpendWiseColors.light.income
        : SpendWiseColors.light.expense;
    expect(text.style?.color, colors);
    final parent = row.parentContext;
    final caption = parent == null
        ? row.formattedShare
        : '${row.formattedShare} / $parent';
    final surface = _rowSurface(row.formattedAmount);
    expect(
      find.descendant(of: surface, matching: find.text(row.name)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: surface, matching: find.text(caption)),
      findsOneWidget,
    );
  }
}

void _expectDonut(WidgetTester tester, List<double> amounts) {
  final donut = tester.widget<DonutChart>(find.byType(DonutChart));
  final first = _ready(tester).breakdown.rows.first;
  expect(donut.segments.map((segment) => segment.value), amounts);
  expect(donut.centerValue, first.name);
  expect(donut.centerLabel, first.formattedShare);
  expect(donut.selectedIndex, isNull);
  expect(donut.onSelect, isNull);
}

String _categoryID(Ledger ledger, String name) =>
    ledger.state.categories.values.singleWhere((c) => c.name == name).id;

Ledger _julyHistory() {
  final ledger = seededTrendsLedger(_today);
  _addSample(ledger, DateTime.utc(2026, 7, 10), _julyAmounts);
  return ledger;
}

void _addSample(Ledger ledger, DateTime day, List<String> amounts) {
  final source = ledger.state.activeAccounts.first.id;
  for (var i = 0; i < _octoberNames.length; i++) {
    ledger.addEntry(
      Entry(
        amount: -Decimal.parse(amounts[i]),
        name: _octoberNames[i],
        sourceID: source,
        categoryID: _categoryID(ledger, _octoberNames[i]),
        date: day,
      ),
    );
  }
}

Ledger _yearHistory() {
  final seed = seededTrendsLedger(_today);
  final ledger = Ledger();
  for (final account in seed.state.activeAccounts) {
    ledger.addAccount(account);
  }
  for (final category in seed.state.categories.values) {
    ledger.addCategory(category);
  }
  _addSample(ledger, DateTime.utc(2024, 7, 1), ['2664', '1998', '888']);
  _addSample(ledger, DateTime.utc(2025, 7, 1), [
    '2858.40',
    '2143.80',
    '952.80',
  ]);
  _addSample(ledger, DateTime.utc(2026, 1, 1), ['1000', '1000', '1000']);
  _addSample(ledger, DateTime.utc(2026, 12, 31), [
    '2009.60',
    '1257.20',
    '3.20',
  ]);
  return ledger;
}

void _frameTests() {
  testWidgets('tr-july reconciles the selected July history', (tester) async {
    await pumpTrends(tester, ledger: _julyHistory(), today: _today);
    await _selectPeriod(tester, 'July 2026');

    _expectRows(
      tester,
      names: _octoberNames,
      amounts: _julyAmounts,
      shares: _sampleShares,
      total: '900',
    );
    expect(_ready(tester).headline.amount, '-S\$900.00');
    _expectDonut(tester, [432, 324, 144]);
    expect(find.byType(TrendsUsualView), findsOneWidget);
    _expectNoSettings();
  }, timeout: uiTestTimeout);

  for (final chart in BreakdownChart.values) {
    final name = chart == BreakdownChart.donut
        ? 'tr-oct-sub-donut'
        : 'tr-oct-sub-map';
    testWidgets('$name preserves the subcategory and Direct split', (
      tester,
    ) async {
      final preferences = DisplayPreferences(
        breakdownChart: chart,
        breakdownLevel: BreakdownLevel.subcategories,
      );
      await pumpTrends(
        tester,
        ledger: seededTrendsLedger(_today),
        today: _today,
        preferences: preferences,
      );

      _expectRows(
        tester,
        names: _subNames,
        amounts: _subAmounts,
        shares: _subShares,
        total: '167.40',
      );
      expect(find.text('By subcategory'), findsOneWidget);
      expect(find.text('25.4% / Groceries'), findsOneWidget);
      expect(find.text('11.1% / Groceries'), findsOneWidget);
      expect(find.text('7.4% / Groceries'), findsOneWidget);
      expect(find.text('50.1%'), findsWidgets);
      if (chart == BreakdownChart.donut) {
        _expectDonut(tester, [83.9, 42.5, 18.6, 12.4, 10]);
      }
      _expectPassiveRows(tester);
      _expectNoSettings();
    }, timeout: uiTestTimeout);
  }

  testWidgets('tr-income shows Salary with a signed bare income amount', (
    tester,
  ) async {
    await pumpTrends(tester, ledger: seededTrendsLedger(_today), today: _today);
    await _chooseIncome(tester);

    _expectRows(
      tester,
      names: ['Salary'],
      amounts: ['3200'],
      shares: ['100.0%'],
      total: '3200',
      income: true,
    );
    expect(find.text('Income breakdown'), findsOneWidget);
    expect(find.text('+3,200.00'), findsOneWidget);
    _expectDonut(tester, [3200]);
    _expectPassiveRows(tester);
  }, timeout: uiTestTimeout);

  testWidgets('tr-no-income shows the successful empty card', (tester) async {
    await pumpTrends(tester, ledger: _julyHistory(), today: _today);
    await _chooseIncome(tester);
    await _selectPeriod(tester, 'July 2026');

    expect(find.text('No income recorded'), findsNWidgets(2));
    final empty = tester.widget<EmptyState>(
      _inSection(find.byType(EmptyState)),
    );
    expect(empty.icon, Icons.attach_money);
    expect(empty.onAction, isNull);
    expect(
      find.text('Income entries in this period will appear here.'),
      findsOneWidget,
    );
    expect(find.byType(DonutChart), findsNothing);
    expect(find.byType(CategoryMap), findsNothing);
    expect(_ready(tester).headline.amount, isNull);
    expect(_ready(tester).breakdown.rows, isEmpty);
  }, timeout: uiTestTimeout);

  testWidgets('tr-year agrees across chart headline and full-year breakdown', (
    tester,
  ) async {
    await pumpTrends(tester, ledger: _yearHistory(), today: _today);
    await tester.tap(find.text('Year by year'));
    await tester.pumpAndSettle();

    _expectRows(
      tester,
      names: _octoberNames,
      amounts: _yearAmounts,
      shares: _sampleShares,
      total: '6270',
    );
    final body = _ready(tester);
    expect(body.headline.title, '2026');
    expect(body.headline.sublabel, 'Spent');
    expect(body.headline.amount, '-S\$6,270.00');
    expect(body.bars.map((bar) => bar.value), [5550, 5955, 6270]);
    expect(body.breakdown.period, DateTime.utc(2026));
    expect(body.breakdown.mode, TrendsMode.year);
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.last.barRods.single.toY, 6270);
    _expectDonut(tester, [3009.60, 2257.20, 1003.20]);
    expect(find.byType(TrendsUsualView), findsNothing);
    expect(find.textContaining('Compared with usual'), findsNothing);
    expect(find.textContaining('January to July'), findsNothing);
    expect(find.textContaining('October is incomplete'), findsNothing);
    _expectNoSettings();
  }, timeout: uiTestTimeout);
}

void _expectNoSettings() {
  expect(find.text('Settings'), findsNothing);
  expect(find.text('Donut'), findsNothing);
  expect(find.text('Category map'), findsNothing);
  expect(find.text('Categories'), findsNothing);
  expect(find.text('Subcategories'), findsNothing);
  expect(find.byType(Switch), findsNothing);
  expect(find.byType(DropdownButton<BreakdownChart>), findsNothing);
}

void _expectPassiveRows(WidgetTester tester) {
  final semantics = tester.ensureSemantics();
  final rows = _ready(tester).breakdown.rows;
  for (final row in rows) {
    final amount = _inSection(find.text(row.formattedAmount));
    final node = tester.getSemantics(amount);
    expect(node.flagsCollection.isButton, isFalse);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
  }
  expect(_inSection(find.byType(Icon)), findsNothing);
  expect(_inSection(find.byType(InkWell)), findsNothing);
  semantics.dispose();
}

typedef _Choice = ({
  BreakdownChart chart,
  BreakdownLevel level,
  ChartColours mode,
});

List<_Choice> _choices() => [
  for (final chart in BreakdownChart.values)
    for (final level in BreakdownLevel.values)
      for (final mode in ChartColours.values)
        (chart: chart, level: level, mode: mode),
];

void _preferenceTests() {
  for (final brightness in Brightness.values) {
    for (final choice in _choices()) {
      _preferenceTest(brightness, choice);
    }
  }
}

void _preferenceTest(Brightness brightness, _Choice choice) {
  testWidgets('$brightness ${choice.chart} ${choice.level} ${choice.mode}', (
    tester,
  ) async {
    final preferences = DisplayPreferences(
      breakdownChart: choice.chart,
      breakdownLevel: choice.level,
      chartColours: choice.mode,
    );
    final ledger = seededTrendsLedger(_today);
    await pumpTrends(
      tester,
      ledger: ledger,
      today: _today,
      brightness: brightness,
      preferences: preferences,
      size: trendsShortPhoneSize,
    );

    final colors = brightness == Brightness.light
        ? SpendWiseColors.light
        : SpendWiseColors.dark;
    final breakdown = _ready(tester).breakdown;
    final isCategory = choice.level == BreakdownLevel.categories;
    expect(
      breakdown.rows.map((row) => row.name),
      isCategory ? _octoberNames : _subNames,
    );
    final chartColors = _chartColors(tester, choice.chart);
    final swatches = _swatches(tester);
    expect(chartColors, swatches);
    _expectMapContrast(tester, choice.chart);
    _expectAmountColor(tester, colors.expense);
    for (var i = 0; i < breakdown.rows.length; i++) {
      final expected = CategoryPalette.resolve(
        savedHex: breakdown.rows[i].savedHex,
        rank: i,
        mode: choice.mode,
        colors: colors,
      );
      expect(swatches[i], expected);
    }
    _expectDirectColor(tester, ledger, choice.mode, colors);
    _expectNoSettings();
    final lastAmount = _inSection(find.text('-10.00'));
    await tester.scrollUntilVisible(lastAmount, _scrollStep);
    expect(lastAmount.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);
}

List<Color> _chartColors(WidgetTester tester, BreakdownChart chart) {
  if (chart == BreakdownChart.donut) {
    final donut = tester.widget<DonutChart>(find.byType(DonutChart));
    expect(donut.onSelect, isNull);
    expect(donut.selectedIndex, isNull);
    expect(find.byType(CategoryMap), findsNothing);
    return [for (final segment in donut.segments) segment.color];
  }
  final map = tester.widget<CategoryMap>(find.byType(CategoryMap));
  expect(map.onSelect, isNull);
  expect(map.selectedIndex, isNull);
  expect(find.byType(DonutChart), findsNothing);
  return [for (final tile in map.tiles) tile.color];
}

Finder _rowSurface(String amount) => find
    .ancestor(
      of: _inSection(find.text(amount)),
      matching: find.byType(Container),
    )
    .first;

List<Color> _swatches(WidgetTester tester) {
  final rows = _ready(tester).breakdown.rows;
  return [for (final row in rows) _rowSwatch(tester, row.formattedAmount)];
}

Color _rowSwatch(WidgetTester tester, String amount) {
  final containers = find.descendant(
    of: _rowSurface(amount),
    matching: find.byType(Container),
  );
  final surfaces = tester.widgetList<Container>(containers);
  final swatch = surfaces.singleWhere(_isSwatch);
  final decoration = swatch.decoration;
  if (decoration case BoxDecoration(color: final color?)) return color;
  throw StateError('Expected a coloured breakdown swatch');
}

bool _isSwatch(Container surface) {
  final constraints = surface.constraints;
  return constraints?.maxWidth == _swatchExtent &&
      constraints?.maxHeight == _swatchExtent;
}

void _expectDirectColor(
  WidgetTester tester,
  Ledger ledger,
  ChartColours mode,
  SpendWiseColors colors,
) {
  final rows = _ready(tester).breakdown.rows;
  final rank = rows.indexWhere((row) => row.isDirect);
  if (rank < 0) return;
  final parent = ledger.state.categories.values.singleWhere(
    (category) => category.name == 'Groceries',
  );
  final expected = CategoryPalette.resolve(
    savedHex: parent.colorHex,
    rank: rank,
    mode: mode,
    colors: colors,
  );
  expect(_chartColors(tester, _ready(tester).breakdown.chart)[rank], expected);
  if (mode == ChartColours.categoryColours) expect(expected, colors.groceries);
}

void _boundaryTests() {
  testWidgets('empty expense card mirrors the selected-kind income copy', (
    tester,
  ) async {
    final ledger = emptyTrendsLedger();
    addTrendsEntry(ledger, '12', _today);
    await pumpTrends(tester, ledger: ledger, today: _today);

    expect(find.text('No expenses recorded'), findsNWidgets(2));
    expect(
      find.text('Expense entries in this period will appear here.'),
      findsOneWidget,
    );
    expect(find.byType(DonutChart), findsNothing);
    expect(find.byType(CategoryMap), findsNothing);
  }, timeout: uiTestTimeout);

  test('TrendsHarness accepts saved display preferences', () async {
    final preferences = DisplayPreferences(
      breakdownChart: BreakdownChart.categoryMap,
      breakdownLevel: BreakdownLevel.subcategories,
      chartColours: ChartColours.contrasting,
    );
    final harness = TrendsHarness(
      ledger: seededTrendsLedger(_today),
      today: _today,
      preferences: preferences,
    );
    await harness.settle();
    expect(harness.ready.breakdown.chart, BreakdownChart.categoryMap);
    expect(harness.ready.breakdown.level, BreakdownLevel.subcategories);
    expect(harness.ready.breakdown.colours, ChartColours.contrasting);
  });

  testWidgets(
    'rounded zero-share map rows remain listed without a block or adjacent label',
    (tester) async {
      final ledger = emptyTrendsLedger();
      addTrendsEntry(ledger, '-1000000', _today);
      addTrendsEntry(
        ledger,
        '-$_tinyAmount',
        _today,
        categoryID: hiddenCategoryID,
      );
      ledger.updateCategory(
        TransactionCategory(
          id: hiddenCategoryID,
          name: 'Hidden',
          kind: CategoryKind.expense,
          colorHex: '#000000',
          includeInAnalysis: true,
          parentID: null,
          symbol: 'tag',
        ),
      );
      await pumpTrends(
        tester,
        ledger: ledger,
        today: _today,
        preferences: DisplayPreferences(
          breakdownChart: BreakdownChart.categoryMap,
        ),
      );

      final map = tester.widget<CategoryMap>(find.byType(CategoryMap));
      expect(map.tiles.map((tile) => tile.share), [1, 0]);
      final blocks = find.descendant(
        of: find.byType(CategoryMap),
        matching: find.byType(Stack),
      );
      expect(tester.widget<Stack>(blocks).children, hasLength(1));
      expect(_inSection(find.text('Hidden')), findsOneWidget);
      expect(find.text('-0.01'), findsOneWidget);
      final insideMap = find.descendant(
        of: find.byType(CategoryMap),
        matching: find.textContaining('Hidden'),
      );
      expect(insideMap, findsNothing);
      expect(find.text('0.0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );
}

const _rankCount = 9;
const _rankAmounts = [
  '900',
  '800',
  '700',
  '600',
  '500',
  '400',
  '300',
  '200',
  '100',
];
const _rankHexes = [
  '#34C759',
  '#30D158',
  '#63E6BE',
  '#FF9500',
  '#5856D6',
  '#007AFF',
  '#000000',
  '#FFFFFF',
  '#123456',
];
const _weights = [0.0, 1 / 14, 2 / 14, 3 / 14, 4 / 14, 5 / 14, 6 / 14, 1 / 2];

Ledger _rankHistory() {
  final ledger = emptyTrendsLedger();
  for (var i = 0; i < _rankCount; i++) {
    final category = TransactionCategory(
      name: 'Rank $i',
      kind: CategoryKind.expense,
      colorHex: _rankHexes[i],
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    );
    ledger.addCategory(category);
    addTrendsEntry(
      ledger,
      '-${_rankAmounts[i]}',
      _today,
      categoryID: category.id,
    );
  }
  return ledger;
}

void _rankTests() {
  for (final brightness in Brightness.values) {
    for (final chart in BreakdownChart.values) {
      for (final mode in ChartColours.values) {
        _rankTest(brightness, chart, mode);
      }
    }
  }
}

void _rankTest(Brightness brightness, BreakdownChart chart, ChartColours mode) {
  testWidgets(
    '$brightness $chart $mode preserves all eight ranks and wraparound',
    (tester) async {
      final colors = brightness == Brightness.light
          ? SpendWiseColors.light
          : SpendWiseColors.dark;
      await pumpTrends(
        tester,
        ledger: _rankHistory(),
        today: _today,
        brightness: brightness,
        preferences: DisplayPreferences(
          breakdownChart: chart,
          chartColours: mode,
        ),
      );
      final chartColors = _chartColors(tester, chart);
      expect(chartColors, hasLength(_rankCount));
      expect(chartColors, _swatches(tester));
      _expectRanks(mode, chartColors, colors);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );
}

void _expectRanks(
  ChartColours mode,
  List<Color> actual,
  SpendWiseColors colors,
) {
  final contrasting = [
    colors.groceries,
    colors.supermarket,
    colors.freshMarket,
    colors.dining,
    colors.transport,
    colors.salary,
    colors.fitness,
    colors.housing,
  ];
  if (mode == ChartColours.contrasting) {
    expect(actual, [...contrasting, colors.groceries]);
    return;
  }
  if (mode == ChartColours.themeShades) {
    final expected = [
      for (final weight in _weights)
        Color.lerp(colors.action, colors.surface, weight),
    ];
    expect(actual, [...expected, colors.action]);
    return;
  }
  expect(actual.take(6), contrasting.take(6));
  for (var rank = 6; rank < _rankCount; rank++) {
    final expected = CategoryPalette.resolve(
      savedHex: _rankHexes[rank],
      rank: rank,
      mode: mode,
      colors: colors,
    );
    expect(actual[rank], expected);
    expect(actual[rank], isNot(colors.selectedMark));
  }
}

void _expectMapContrast(WidgetTester tester, BreakdownChart chart) {
  if (chart != BreakdownChart.categoryMap) return;
  final map = tester.widget<CategoryMap>(find.byType(CategoryMap));
  for (final tile in map.tiles) {
    final share = (tile.share * 100).toStringAsFixed(1);
    final label = find.text('${tile.label}\n$share%');
    if (label.evaluate().isEmpty) continue;
    expect(tester.widget<Text>(label).style?.color, foregroundOn(tile.color));
  }
}

void _expectAmountColor(WidgetTester tester, Color color) {
  for (final row in _ready(tester).breakdown.rows) {
    final amount = _inSection(find.text(row.formattedAmount));
    expect(tester.widget<Text>(amount).style?.color, color);
  }
}

const _longName = 'Household essentials and other long running subscriptions';
const _longAmount = '-123456.78';
const _holeDiameterFraction = 0.68;
const _rectTolerance = 0.5;

Ledger _longNameLedger() {
  final ledger = emptyTrendsLedger();
  ledger.updateCategory(
    TransactionCategory(
      id: foodCategoryID,
      name: _longName,
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  addTrendsEntry(ledger, _longAmount, _today);
  return ledger;
}

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

void _expectInside(Rect inner, Rect outer, String what) {
  final bounds = outer.inflate(_rectTolerance);
  expect(bounds.contains(inner.topLeft), isTrue, reason: '$what top left');
  expect(
    bounds.contains(inner.bottomRight),
    isTrue,
    reason: '$what bottom right',
  );
}

void _expectInsideHole(WidgetTester tester) {
  final chart = _rect(tester, find.byType(DonutChart));
  final radius = chart.width * _holeDiameterFraction / 2 + _rectTolerance;
  final texts = find.descendant(
    of: find.byType(DonutChart),
    matching: find.byType(Text),
  );
  expect(texts, findsNWidgets(2));
  for (final text in texts.evaluate().map((e) => e.widget)) {
    final rect = _rect(tester, find.byWidget(text));
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    for (final corner in corners) {
      expect((corner - chart.center).distance, lessThanOrEqualTo(radius));
    }
  }
}

void _expectRowInsideCard(WidgetTester tester) {
  final breakdown = _ready(tester).breakdown;
  final row = breakdown.rows.first;
  final card = _rect(tester, _inSection(find.byType(TrendsCard)));
  final label = _rect(tester, find.text(_longName).last);
  final share = _rect(tester, find.text(row.formattedShare).last);
  final amount = _rect(tester, find.text(row.formattedAmount));
  _expectInside(label, card, 'label');
  _expectInside(share, card, 'share');
  _expectInside(amount, card, 'amount');
  expect(label.right, lessThanOrEqualTo(amount.left + _rectTolerance));
}

void _longNameTests() {
  for (final chart in BreakdownChart.values) {
    testWidgets('a very long category name stays inside the $chart section', (
      tester,
    ) async {
      await pumpTrends(
        tester,
        ledger: _longNameLedger(),
        today: _today,
        preferences: DisplayPreferences(breakdownChart: chart),
      );

      expect(tester.takeException(), isNull);
      _expectRowInsideCard(tester);
      if (chart == BreakdownChart.donut) _expectInsideHole(tester);
    }, timeout: uiTestTimeout);
  }
}
