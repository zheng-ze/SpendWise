import 'dart:math' as math;

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/common/charts/category_map.dart';
import 'package:spendwise/ui/common/charts/donut_chart.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_section.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/stats/trends_flow.dart';
import 'package:spendwise/ui/stats/trends_screen.dart';

import '../../ledger/analysis_test_support.dart';
import '../../support/counting_ledger_session.dart';
import '../../support/ui_test_timeout.dart';
import 'trends_test_support.dart';

final _today = DateTime.utc(2026, 10, 3);
final _itemDate = DateTime.utc(2026, 10, 2);

const _unknownBucket = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const _syntheticBucket = 'transfer-expense:savings';
const _itemAmount = '10';
const _flowSize = Size(500, 1000);
const _diningAmount = '-83.90';
const _donutCenterRadiusFactor = 0.34;
const _donutRingFactor = 0.17;
const _fullTurn = 360.0;
const _tierAmounts = ['900', '90', '9', '1'];
const _tierCount = 4;
const _extraDining = '16.10';
const _extraDiningTotal = 'S\$100.00';

CategoryDetailArgs _openedArgs(WidgetTester tester) =>
    tester.widget<CategoryDetailScreen>(find.byType(CategoryDetailScreen)).args;

Finder get _chevrons => find.descendant(
  of: find.byType(TrendsBreakdownSection),
  matching: find.byIcon(Icons.chevron_right),
);

Finder get _detailRoutes =>
    find.byType(CategoryDetailScreen, skipOffstage: false);

Finder _row(String amount) => find.descendant(
  of: find.byType(TrendsBreakdownSection),
  matching: find.text(amount),
);

String _categoryID(Ledger ledger, String name) =>
    ledger.state.categories.values.singleWhere((c) => c.name == name).id;

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TrendsScreen)));

Future<void> _pumpFlow(
  WidgetTester tester, {
  Ledger? ledger,
  ComputeRunner? runner,
  DisplayPreferences? preferences,
}) => pumpTrends(
  tester,
  ledger: ledger ?? seededTrendsLedger(_today),
  today: _today,
  runner: runner,
  preferences: preferences,
  size: _flowSize,
  home: const TrendsFlow(),
);

AnalysisItem _item(String? bucketID) => AnalysisItem(
  kind: CategoryKind.expense,
  amount: Decimal.parse(_itemAmount),
  date: _itemDate,
  bucketID: bucketID,
);

Future<void> _pumpControlled(WidgetTester tester, List<String?> buckets) async {
  final ledger = emptyTrendsLedger();
  addTrendsEntry(ledger, '-1', _today);
  final items = [for (final bucket in buckets) _item(bucket)];
  await _pumpFlow(tester, ledger: ledger, runner: (_) async => items);
}

Future<void> _tapRow(WidgetTester tester, String amount) async {
  await tester.tap(_row(amount));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Ledger _tieredLedger() {
  final ledger = emptyTrendsLedger();
  for (var i = 0; i < _tierCount; i++) {
    final category = TransactionCategory(
      name: 'Tier $i',
      kind: CategoryKind.expense,
      colorHex: '#34C759',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    );
    ledger.addCategory(category);
    addTrendsEntry(
      ledger,
      '-${_tierAmounts[i]}',
      _today,
      categoryID: category.id,
    );
  }
  return ledger;
}

Offset _donutPoint(WidgetTester tester, List<double> values, int index) {
  final total = values.fold(0.0, (sum, value) => sum + value);
  final before = values.take(index).fold(0.0, (sum, value) => sum + value);
  final middle = before + values[index] / 2;
  final angle = middle / total * _fullTurn * math.pi / (_fullTurn / 2);
  final diameter = tester.getSize(find.byType(DonutChart)).width;
  final radius = diameter * (_donutCenterRadiusFactor + _donutRingFactor / 2);
  final center = tester.getCenter(find.byType(DonutChart));
  return center + Offset(math.cos(angle), math.sin(angle)) * radius;
}

Finder get _mapBlocks => find.descendant(
  of: find.byType(CategoryMap),
  matching: find.byType(Positioned),
);

void main() {
  group('rows', () {
    testWidgets('a ranked row opens its category detail and Back returns', (
      tester,
    ) async {
      final ledger = seededTrendsLedger(_today);
      await _pumpFlow(tester, ledger: ledger);
      final container = _container(tester);
      final intent = container.read(trendsIntentProvider);

      await _tapRow(tester, _diningAmount);

      expect(
        _openedArgs(tester),
        CategoryDetailArgs(
          mainID: _categoryID(ledger, 'Dining'),
          kind: CategoryKind.expense,
          isYearRange: false,
          initialDate: DateTime.utc(2026, 10),
        ),
      );
      expect(find.text('Dining'), findsWidgets);

      await _back(tester);

      expect(find.byType(CategoryDetailScreen), findsNothing);
      expect(find.byType(TrendsScreen), findsOneWidget);
      expect(container.read(trendsIntentProvider), intent);
    }, timeout: uiTestTimeout);

    testWidgets('year mode and income map into the opened args', (
      tester,
    ) async {
      await _pumpFlow(tester);
      await tester.tap(find.text('Year by year'));
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      await tester.tap(_chevrons);
      await tester.pumpAndSettle();

      final args = _openedArgs(tester);
      expect(args.kind, CategoryKind.income);
      expect(args.isYearRange, isTrue);
      expect(args.initialDate, DateTime.utc(2026));
    }, timeout: uiTestTimeout);

    testWidgets('subcategory and Direct rows open the main category', (
      tester,
    ) async {
      final ledger = seededTrendsLedger(_today);
      await _pumpFlow(
        tester,
        ledger: ledger,
        preferences: DisplayPreferences(
          breakdownLevel: BreakdownLevel.subcategories,
        ),
      );
      final groceries = _categoryID(ledger, 'Groceries');

      for (final amount in ['-42.50', '-18.60', '-12.40']) {
        await _tapRow(tester, amount);
        expect(_openedArgs(tester).mainID, groceries);
        await _back(tester);
      }
    }, timeout: uiTestTimeout);

    testWidgets('Uncategorized and synthetic rows are inert', (tester) async {
      await _pumpControlled(tester, [null, _syntheticBucket]);
      final semantics = tester.ensureSemantics();

      final amounts = _row('-10.00');
      expect(amounts, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final node = tester.getSemantics(amounts.at(i));
        expect(node.flagsCollection.isButton, isFalse);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
        await tester.tap(amounts.at(i));
        await tester.pumpAndSettle();
      }

      expect(find.byType(CategoryDetailScreen), findsNothing);
      expect(_chevrons, findsNothing);
      semantics.dispose();
    }, timeout: uiTestTimeout);

    testWidgets('an unresolved non-null bucket opens an empty-titled detail', (
      tester,
    ) async {
      await _pumpControlled(tester, [null, _unknownBucket]);
      expect(_chevrons, findsOneWidget);

      await tester.tap(_chevrons);
      await tester.pumpAndSettle();

      expect(_openedArgs(tester).mainID, _unknownBucket);
      final title = find.descendant(
        of: find.byType(AppBar),
        matching: find.text(''),
      );
      expect(title, findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('navigable rows show chevrons and a tap action', (
      tester,
    ) async {
      await _pumpFlow(tester);
      final semantics = tester.ensureSemantics();

      expect(_chevrons, findsNWidgets(3));
      final node = tester.getSemantics(_row(_diningAmount));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    }, timeout: uiTestTimeout);
  });

  group('chart blocks', () {
    testWidgets('donut segments open the tapped category', (tester) async {
      final ledger = seededTrendsLedger(_today);
      await _pumpFlow(tester, ledger: ledger);
      const values = [83.9, 73.5, 10.0];
      const names = ['Dining', 'Groceries', 'Transport'];

      for (var i = 0; i < names.length; i++) {
        await tester.tapAt(_donutPoint(tester, values, i));
        await tester.pumpAndSettle();
        expect(_openedArgs(tester).mainID, _categoryID(ledger, names[i]));
        await _back(tester);
      }
    }, timeout: uiTestTimeout);

    testWidgets('map blocks open the tapped category', (tester) async {
      final ledger = seededTrendsLedger(_today);
      await _pumpFlow(
        tester,
        ledger: ledger,
        preferences: DisplayPreferences(
          breakdownChart: BreakdownChart.categoryMap,
        ),
      );
      const names = ['Dining', 'Groceries', 'Transport'];
      expect(_mapBlocks, findsNWidgets(names.length));

      for (var i = 0; i < names.length; i++) {
        await tester.tapAt(tester.getCenter(_mapBlocks.at(i)));
        await tester.pumpAndSettle();
        expect(_openedArgs(tester).mainID, _categoryID(ledger, names[i]));
        await _back(tester);
      }
    }, timeout: uiTestTimeout);

    testWidgets('the smallest non-zero map block opens its own category', (
      tester,
    ) async {
      final ledger = _tieredLedger();
      await _pumpFlow(
        tester,
        ledger: ledger,
        preferences: DisplayPreferences(
          breakdownChart: BreakdownChart.categoryMap,
        ),
      );
      final blocks = [
        for (var i = 0; i < _tierCount; i++) tester.getRect(_mapBlocks.at(i)),
      ];
      final areas = [for (final rect in blocks) rect.width * rect.height];
      final smallest = areas.indexOf(areas.reduce(math.min));

      await tester.tapAt(blocks[smallest].center);
      await tester.pumpAndSettle();

      expect(smallest, _tierCount - 1);
      expect(_openedArgs(tester).mainID, _categoryID(ledger, 'Tier 3'));
    }, timeout: uiTestTimeout);

    testWidgets('tiny adjacent map labels open the same category', (
      tester,
    ) async {
      final ledger = _tieredLedger();
      await _pumpFlow(
        tester,
        ledger: ledger,
        preferences: DisplayPreferences(
          breakdownChart: BreakdownChart.categoryMap,
        ),
      );
      final label = find.descendant(
        of: find.byType(CategoryMap),
        matching: find.textContaining('Tier 3'),
      );

      await tester.tap(label.last);
      await tester.pumpAndSettle();

      expect(_openedArgs(tester).mainID, _categoryID(ledger, 'Tier 3'));
    }, timeout: uiTestTimeout);

    testWidgets('inert chart marks open nothing', (tester) async {
      await _pumpControlled(tester, [null, _syntheticBucket]);
      const values = [10.0, 10.0];

      await tester.tapAt(_donutPoint(tester, values, 0));
      await tester.tapAt(_donutPoint(tester, values, 1));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryDetailScreen), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('charts never receive a selected index', (tester) async {
      await _pumpFlow(tester);

      final donut = tester.widget<DonutChart>(find.byType(DonutChart));

      expect(donut.selectedIndex, isNull);
      expect(donut.onSelect, isNotNull);
    }, timeout: uiTestTimeout);
  });

  group('route guard', () {
    testWidgets('repeated requests install one detail route', (tester) async {
      await _pumpFlow(tester);
      final viewModel = _container(tester)
          .read(trendsViewModelProvider.notifier);

      viewModel.requestCategoryDetail(0);
      viewModel.requestCategoryDetail(0);
      await tester.pumpAndSettle();

      expect(_detailRoutes, findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('requests during the reverse transition are rejected', (
      tester,
    ) async {
      await _pumpFlow(tester);
      final viewModel = _container(tester)
          .read(trendsViewModelProvider.notifier);
      viewModel.requestCategoryDetail(0);
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 50));
      viewModel.requestCategoryDetail(1);
      await tester.pumpAndSettle();
      expect(_detailRoutes, findsNothing);

      viewModel.requestCategoryDetail(1);
      await tester.pumpAndSettle();
      expect(_detailRoutes, findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('a rebuild with a pending step opens exactly one route', (
      tester,
    ) async {
      await _pumpFlow(tester);
      final container = _container(tester);

      container.read(trendsViewModelProvider.notifier).requestCategoryDetail(0);
      container.invalidate(todayProvider);
      await tester.pumpAndSettle();

      expect(_detailRoutes, findsOneWidget);
      expect(container.read(trendsViewModelProvider).requireValue.step, isNull);
      await _back(tester);
      expect(_detailRoutes, findsNothing);
    }, timeout: uiTestTimeout);
  });

  group('pending step pickup', () {
    testWidgets('a step pending before the flow mounts opens once', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = _flowSize;
      addTearDown(tester.view.reset);
      final harness = TrendsHarness(
        ledger: seededTrendsLedger(_today),
        today: _today,
      );
      await tester.runAsync(harness.settle);
      harness.viewModel.requestCategoryDetail(0);
      expect(harness.step, isNotNull);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const MaterialApp(home: TrendsFlow()),
        ),
      );
      await tester.pumpAndSettle();

      expect(_detailRoutes, findsOneWidget);
      expect(harness.step, isNull);
    }, timeout: uiTestTimeout);
  });

  group('detail lifecycle', () {
    Counted counted({ComputeRunner runner = syncComputeRunner}) =>
        countedSession(state: seededTrendsLedger(_today).state, runner: runner);

    Future<ProviderContainer> pumpCounted(
      WidgetTester tester,
      Counted env,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = _flowSize;
      addTearDown(tester.view.reset);
      final container = containerFor(
        () => env.session,
        overrides: [clockProvider.overrideWithValue(() => _today)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TrendsFlow()),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('closing the detail returns listeners to the Trends baseline', (
      tester,
    ) async {
      final env = counted();
      await pumpCounted(tester, env);
      final baselineLedger = env.ledger.listeners;
      final baselineCache = env.cache.listeners;

      await _tapRow(tester, _diningAmount);
      expect(env.ledger.listeners, baselineLedger + 1);
      expect(env.cache.listeners, baselineCache + 1);

      await _back(tester);
      expect(env.ledger.listeners, baselineLedger);
      expect(env.cache.listeners, baselineCache);

      await _tapRow(tester, _diningAmount);
      env.ledger.addEntry(
        Entry(
          amount: -Decimal.parse(_extraDining),
          name: 'Dinner',
          sourceID: env.ledger.state.activeAccounts.first.id,
          categoryID: _categoryID(env.ledger, 'Dining'),
          date: _today,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_extraDiningTotal), findsWidgets);
    }, timeout: uiTestTimeout);

    testWidgets('closing during a delayed refresh stays inert', (tester) async {
      final runner = ManualRunner();
      final env = counted(runner: runner.call);
      await pumpCounted(tester, env);
      runner.pending.last.complete(Accounting.analysisItems(env.ledger.state));
      await tester.pumpAndSettle();
      final baselineLedger = env.ledger.listeners;
      final baselineCache = env.cache.listeners;
      await _tapRow(tester, _diningAmount);

      await _back(tester);
      env.ledger.addEntry(
        Entry(
          amount: -Decimal.one,
          name: 'Snack',
          sourceID: env.ledger.state.activeAccounts.first.id,
          categoryID: _categoryID(env.ledger, 'Dining'),
          date: _today,
        ),
      );
      runner.pending.last.complete(Accounting.analysisItems(env.ledger.state));
      await tester.pumpAndSettle();

      expect(env.ledger.listeners, baselineLedger);
      expect(env.cache.listeners, baselineCache);
      expect(tester.takeException(), isNull);
    }, timeout: uiTestTimeout);
  });
}
