import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/trends/trends_detail_metadata.dart';
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
const _narrowOpenSize = Size(600, 480);
const _travelID = '77777777-7777-7777-7777-777777777777';
const _octoberTitle = 'October 2026';
const _julyTitle = 'July 2026';
final _testToday = DateTime.utc(2026, 10, 15);

class _TrendsApp extends StatelessWidget {
  const _TrendsApp({
    required this.container,
    required this.mode,
    required this.addPresented,
    required this.size,
  });

  final ProviderContainer container;
  final ShellLayoutMode mode;
  final bool addPresented;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final scope = ShellPaneScope(
      mode: mode,
      safeBodyWidth: size.width,
      addPresented: addPresented,
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
    '-50',
    DateTime.utc(2026, 7, 3),
    categoryID: _travelID,
  );
  addTrendsEntry(ledger, '-10', DateTime.utc(2026, 10, 3));
  addTrendsEntry(
    ledger,
    '-50',
    DateTime.utc(2026, 10, 2),
    categoryID: _travelID,
  );
  return ledger;
}

Future<_Setup> _pumpOpen(
  WidgetTester tester,
  Ledger ledger, {
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
  final app = _TrendsApp(
    container: container,
    mode: ShellLayoutMode.open,
    addPresented: false,
    size: size,
  );
  await tester.pumpWidget(app);
  await tester.runAsync(() => settle(runner, ledger));
  await tester.pumpAndSettle();
  return (container: container, ledger: ledger, runner: runner);
}

Future<void> _setShell(
  WidgetTester tester,
  ProviderContainer container, {
  required ShellLayoutMode mode,
  required bool addPresented,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  final app = _TrendsApp(
    container: container,
    mode: mode,
    addPresented: addPresented,
    size: size,
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Element _screenElement(WidgetTester tester) =>
    tester.element(find.byType(TrendsScreen));

Finder _paneText(String text) => find.descendant(
  of: find.byKey(shellDetailPaneKey),
  matching: find.text(text),
);

void main() {
  testWidgets(
    'trends-selected and phone-trends keep the July selection across folding',
    (tester) async {
      final setup = await _pumpOpen(tester, _datedLedger());
      final container = setup.container;
      final july = monthSerial(DateTime.utc(2026, 7));
      await tester.tap(find.bySemanticsLabel(_julyTitle));
      await tester.pumpAndSettle();
      final screenElement = _screenElement(tester);
      expect(container.read(trendsIntentProvider).selected, july);
      expect(container.read(trendsDetailMetadataProvider).title, _julyTitle);
      expect(_paneText(_julyTitle), findsWidgets);
      expect(find.byType(TrendsHeadlineView), findsOneWidget);

      await _setShell(
        tester,
        container,
        mode: ShellLayoutMode.phone,
        addPresented: false,
        size: _phoneSize,
      );
      expect(identical(screenElement, _screenElement(tester)), isTrue);
      expect(container.read(trendsIntentProvider).selected, july);
      expect(find.byKey(shellDetailPaneKey), findsNothing);
      expect(find.byType(TrendsHeadlineView), findsOneWidget);

      await _setShell(
        tester,
        container,
        mode: ShellLayoutMode.open,
        addPresented: false,
        size: _openSize,
      );
      expect(identical(screenElement, _screenElement(tester)), isTrue);
      expect(container.read(trendsIntentProvider).selected, july);
      expect(_paneText(_julyTitle), findsWidgets);
      expect(find.byType(TrendsHeadlineView), findsOneWidget);
      expect(find.byType(CategoryDetailScreen), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'whole-period category drill-down opens the whole-period row once and survives refresh',
    (tester) async {
      final setup = await _pumpOpen(tester, _rankedLedger());
      final container = setup.container;
      final viewModel = container.read(trendsViewModelProvider.notifier);
      final selected = container.read(trendsIntentProvider).selected;
      final screen = find.byType(TrendsScreen);
      final tappable = find.byType(InkWell);
      final food = find.text('Food');
      final wholePeriodRow = find.descendant(
        of: screen,
        matching: find.descendant(of: tappable, matching: food),
      );
      await tester.ensureVisible(wholePeriodRow);
      await tester.tap(wholePeriodRow);
      await tester.pumpAndSettle();
      final detail = find.byType(CategoryDetailScreen);
      final openedArgs = tester.widget<CategoryDetailScreen>(detail).args;
      expect(openedArgs.mainID, foodCategoryID);
      expect(openedArgs.initialDate, DateTime.utc(2026, 10));
      final detailElement = tester.element(detail);

      viewModel.requestCategoryDetail(
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

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(detail, findsNothing);
      expect(container.read(trendsIntentProvider).selected, selected);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'retained-data failure and Retry replace stale totals in page and pane',
    (tester) async {
      final setup = await _pumpOpen(tester, _datedLedger());
      final container = setup.container;
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
      expect(_paneText(_octoberTitle), findsWidgets);

      setup.runner.pending.last.completeError(StateError('compute failed'));
      await tester.pumpAndSettle();
      expect(stale, findsNothing);
      expect(find.text('Retry'), findsWidgets);
      expect(_paneText(_octoberTitle), findsWidgets);
      expect(container.read(trendsIntentProvider).selected, selected);

      await tester.tap(find.text('Retry').first);
      await tester.pumpAndSettle();
      await tester.runAsync(() => settle(setup.runner, setup.ledger));
      await tester.pumpAndSettle();
      expect(stale, findsNothing);
      expect(refreshed, findsWidgets);
      expect(find.text('Retry'), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Add hides and restores the trends-selected period detail pane', (
    tester,
  ) async {
    final setup = await _pumpOpen(tester, _datedLedger());
    final pane = find.byKey(shellDetailPaneKey);
    expect(find.byKey(shellDetailPaneKey, skipOffstage: false), findsOneWidget);
    expect(pane, findsOneWidget);
    await _setShell(
      tester,
      setup.container,
      mode: ShellLayoutMode.open,
      addPresented: true,
      size: _openSize,
    );
    expect(pane, findsNothing);
    await _setShell(
      tester,
      setup.container,
      mode: ShellLayoutMode.open,
      addPresented: false,
      size: _openSize,
    );
    expect(pane, findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets(
    'the detail pane lists category rows without overflowing at the narrowest open window',
    (tester) async {
      await _pumpOpen(tester, _rankedLedger(), size: _narrowOpenSize);
      expect(tester.takeException(), isNull);
      expect(_paneText('Travel'), findsWidgets);
    },
    timeout: uiTestTimeout,
  );
}
