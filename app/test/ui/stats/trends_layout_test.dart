import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/stats/trends_flow.dart';
import 'package:spendwise/ui/stats/trends_screen.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../ledger/analysis_test_support.dart';
import '../../support/ui_test_timeout.dart';
import 'trends_test_support.dart';

const _openSize = Size(960, 720);
const _phoneSize = Size(320, 760);
const _narrowDesktopSize = Size(600, 700);
const _travelID = '77777777-7777-7777-7777-777777777777';
const _julyTitle = 'July 2026';
final _testToday = DateTime.utc(2026, 10, 15);

class _TrendsApp extends StatelessWidget {
  const _TrendsApp({
    required this.container,
    required this.mode,
    required this.size,
  });

  final ProviderContainer container;
  final ShellLayoutMode mode;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final scope = ShellPaneScope(
      mode: mode,
      splitOffset: size.width / 2,
      sheetPresented: false,
      sheetCovered: false,
      child: const TrendsFlow(),
    );
    final app = MaterialApp(
      theme: buildSpendWiseTheme(Brightness.light),
      home: scope,
    );
    return UncontrolledProviderScope(container: container, child: app);
  }
}

typedef _Setup = ({
  ProviderContainer container,
  Ledger ledger,
  ManualRunner runner,
});

Ledger _datedLedger() {
  final ledger = emptyTrendsLedger();
  addTrendsEntry(ledger, '-40', DateTime.utc(2026, 7, 4));
  addTrendsEntry(ledger, '-25', DateTime.utc(2026, 10, 2));
  return ledger;
}

Ledger _rankedLedger() {
  final ledger = emptyTrendsLedger();
  ledger.addCategory(
    TransactionCategory(
      id: _travelID,
      name: 'Travel',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  addTrendsEntry(ledger, '-100', DateTime.utc(2026, 7, 2));
  addTrendsEntry(
    ledger,
    '-150',
    DateTime.utc(2026, 7, 3),
    categoryID: _travelID,
  );
  addTrendsEntry(ledger, '-150', DateTime.utc(2026, 10, 3));
  addTrendsEntry(
    ledger,
    '-10',
    DateTime.utc(2026, 10, 2),
    categoryID: _travelID,
  );
  return ledger;
}

Future<_Setup> _pumpFlow(
  WidgetTester tester,
  Ledger ledger, {
  required ShellLayoutMode mode,
  bool resolveInitialRead = true,
  Size size = _openSize,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final runner = ManualRunner();
  final container = TrendsHarness(
    ledger: ledger,
    today: _testToday,
    runner: runner.call,
  ).container;
  await tester.pumpWidget(
    _TrendsApp(container: container, mode: mode, size: size),
  );
  if (resolveInitialRead) {
    await tester.runAsync(() => settle(runner, ledger));
    await tester.pumpAndSettle();
  } else {
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
  }
  return (container: container, ledger: ledger, runner: runner);
}

Future<void> _setShell(
  WidgetTester tester,
  ProviderContainer container, {
  required ShellLayoutMode mode,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    _TrendsApp(container: container, mode: mode, size: size),
  );
  await tester.pumpAndSettle();
}

Element _screenElement(WidgetTester tester) =>
    tester.element(find.byType(TrendsScreen));

Finder _sharedBreakdownRow(String scopeLabel, String category) {
  final scopeCard = find.ancestor(
    of: find.text(scopeLabel),
    matching: find.byType(TrendsCard),
  );
  return find.descendant(
    of: scopeCard.first,
    matching: find.descendant(
      of: find.byType(InkWell),
      matching: find.text(category),
    ),
  );
}

Future<void> _selectJuly(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(_julyTitle));
  await tester.pumpAndSettle();
}

Future<void> _selectMonthScope(WidgetTester tester) async {
  final scope = find.text('Selected month');
  await tester.ensureVisible(scope);
  await tester.tap(scope);
  await tester.pumpAndSettle();
}

Future<void> _tapCategoryDetailBack(WidgetTester tester) async {
  final detail = find.byType(CategoryDetailScreen);
  final back = find.descendant(of: detail, matching: find.text('Trends'));
  await tester.tap(back);
  await tester.pumpAndSettle();
}

void _expectKindAndModeControls(WidgetTester tester) {
  expect(find.text('Expense'), findsOneWidget);
  expect(find.text('Income'), findsOneWidget);
  expect(find.text('Month by month'), findsOneWidget);
  expect(find.text('Year by year'), findsOneWidget);
}

void main() {
  testWidgets(
    'open mode keeps kind and mode controls during loading and empty-data failure',
    (tester) async {
      final setup = await _pumpFlow(
        tester,
        _datedLedger(),
        mode: ShellLayoutMode.open,
        resolveInitialRead: false,
      );
      _expectKindAndModeControls(tester);

      setup.runner.pending.last.completeError(StateError('compute failed'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load your spending"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      _expectKindAndModeControls(tester);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'empty month chart selects a future month and pages to its next year',
    (tester) async {
      final setup = await _pumpFlow(
        tester,
        emptyTrendsLedger(),
        mode: ShellLayoutMode.open,
      );
      final before = setup.container.read(trendsIntentProvider);
      expect(find.text('See where your money goes'), findsOneWidget);
      _expectKindAndModeControls(tester);

      await tester.tap(find.bySemanticsLabel('December 2026'));
      await tester.pumpAndSettle();
      expect(
        setup.container.read(trendsIntentProvider).selected,
        monthSerial(DateTime.utc(2026, 12)),
      );

      await tester.tap(find.bySemanticsLabel('Previous'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pumpAndSettle();

      final after = setup.container.read(trendsIntentProvider);
      expect(before.selected, monthSerial(DateTime.utc(2026, 10)));
      expect(after.selected, monthSerial(DateTime.utc(2027, 12)));
      expect(after.spreadEnd, monthSerial(DateTime.utc(2027, 12)));
      expect(find.text('See where your money goes'), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'folding retains the Trends screen, selected period and breakdown scope',
    (tester) async {
      final setup = await _pumpFlow(
        tester,
        _datedLedger(),
        mode: ShellLayoutMode.open,
      );
      final container = setup.container;
      final july = monthSerial(DateTime.utc(2026, 7));
      await _selectJuly(tester);
      await _selectMonthScope(tester);
      final screenElement = _screenElement(tester);
      expect(container.read(trendsIntentProvider).selected, july);
      expect(
        container.read(trendsBreakdownScopeProvider),
        TrendsBreakdownScope.selectedPeriod,
      );

      await _setShell(
        tester,
        container,
        mode: ShellLayoutMode.phone,
        size: _phoneSize,
      );
      expect(identical(screenElement, _screenElement(tester)), isTrue);
      expect(container.read(trendsIntentProvider).selected, july);
      expect(
        container.read(trendsBreakdownScopeProvider),
        TrendsBreakdownScope.selectedPeriod,
      );
      expect(find.byType(CategoryDetailScreen), findsNothing);

      await _setShell(
        tester,
        container,
        mode: ShellLayoutMode.open,
        size: _openSize,
      );
      expect(identical(screenElement, _screenElement(tester)), isTrue);
      expect(container.read(trendsIntentProvider).selected, july);
      expect(
        container.read(trendsBreakdownScopeProvider),
        TrendsBreakdownScope.selectedPeriod,
      );
      expect(find.text(_julyTitle), findsWidgets);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'whole-period category drill-down opens once and survives refresh and return',
    (tester) async {
      final setup = await _pumpFlow(
        tester,
        _rankedLedger(),
        mode: ShellLayoutMode.open,
      );
      final container = setup.container;
      final selected = container.read(trendsIntentProvider).selected;
      final wholePeriodRow = _sharedBreakdownRow(
        'Whole displayed range',
        'Food',
      );
      await tester.ensureVisible(wholePeriodRow);
      await tester.tap(wholePeriodRow);
      await tester.pumpAndSettle();
      final detail = find.byType(CategoryDetailScreen);
      final openedArgs = tester.widget<CategoryDetailScreen>(detail).args;
      expect(openedArgs.mainID, foodCategoryID);
      expect(openedArgs.initialDate, DateTime.utc(2026, 10));
      final detailElement = tester.element(detail);

      container
          .read(trendsViewModelProvider.notifier)
          .requestCategoryDetail(
            0,
            source: TrendsCategoryDetailSource.wholePeriod,
          );
      await tester.pumpAndSettle();
      expect(detail, findsOneWidget);

      setup.ledger.addEntry(
        Entry(
          id: testId(9301),
          amount: Decimal.parse('-12'),
          name: 'refresh',
          sourceID: checkingSourceID,
          categoryID: foodCategoryID,
          date: DateTime.utc(2026, 10, 12),
        ),
      );
      await tester.runAsync(() => settle(setup.runner, setup.ledger));
      await tester.pumpAndSettle();
      expect(detail, findsOneWidget);
      expect(identical(detailElement, tester.element(detail)), isTrue);
      expect(container.read(trendsIntentProvider).selected, selected);

      await _tapCategoryDetailBack(tester);
      expect(detail, findsNothing);
      expect(container.read(trendsIntentProvider).selected, selected);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('retained-data failure and Retry preserve selection and scope', (
    tester,
  ) async {
    final setup = await _pumpFlow(
      tester,
      _datedLedger(),
      mode: ShellLayoutMode.open,
    );
    final container = setup.container;
    await _selectMonthScope(tester);
    final selected = container.read(trendsIntentProvider).selected;
    final stale = find.textContaining('25.00');
    final refreshed = find.textContaining('37.00');
    expect(stale, findsWidgets);

    setup.ledger.addEntry(
      Entry(
        id: testId(9302),
        amount: Decimal.parse('-12'),
        name: 'refresh',
        sourceID: checkingSourceID,
        categoryID: foodCategoryID,
        date: DateTime.utc(2026, 10, 12),
      ),
    );
    await tester.pumpAndSettle();
    expect(stale, findsNothing);

    setup.runner.pending.last.completeError(StateError('compute failed'));
    await tester.pumpAndSettle();
    expect(stale, findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    _expectKindAndModeControls(tester);
    expect(container.read(trendsIntentProvider).selected, selected);
    expect(
      container.read(trendsBreakdownScopeProvider),
      TrendsBreakdownScope.selectedPeriod,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => settle(setup.runner, setup.ledger));
    await tester.pumpAndSettle();
    expect(stale, findsNothing);
    expect(refreshed, findsWidgets);
    expect(find.text('Retry'), findsNothing);
    expect(container.read(trendsIntentProvider).selected, selected);
    expect(
      container.read(trendsBreakdownScopeProvider),
      TrendsBreakdownScope.selectedPeriod,
    );
  }, timeout: uiTestTimeout);

  testWidgets(
    'desktop Flow scope routes the displayed ranking and survives narrow resize',
    (tester) async {
      final setup = await _pumpFlow(
        tester,
        _rankedLedger(),
        mode: ShellLayoutMode.desktop,
        size: _openSize,
      );
      final container = setup.container;
      await _selectJuly(tester);
      await _selectMonthScope(tester);
      final july = monthSerial(DateTime.utc(2026, 7));
      final screenElement = _screenElement(tester);
      expect(container.read(trendsIntentProvider).selected, july);

      await _setShell(
        tester,
        container,
        mode: ShellLayoutMode.desktop,
        size: _narrowDesktopSize,
      );
      expect(identical(screenElement, _screenElement(tester)), isTrue);
      expect(container.read(trendsIntentProvider).selected, july);
      expect(
        container.read(trendsBreakdownScopeProvider),
        TrendsBreakdownScope.selectedPeriod,
      );

      final selectedPeriodRow = _sharedBreakdownRow('Selected month', 'Travel');
      await tester.ensureVisible(selectedPeriodRow);
      await tester.tap(selectedPeriodRow);
      await tester.pumpAndSettle();
      final args = tester
          .widget<CategoryDetailScreen>(find.byType(CategoryDetailScreen))
          .args;
      expect(args.mainID, _travelID);
      expect(args.initialDate, DateTime.utc(2026, 7));

      await _tapCategoryDetailBack(tester);
      final yearMode = find.text('Year by year');
      await tester.ensureVisible(yearMode);
      await tester.tap(yearMode);
      await tester.pumpAndSettle();
      expect(container.read(trendsIntentProvider).mode, TrendsMode.year);
    },
    timeout: uiTestTimeout,
  );
}
