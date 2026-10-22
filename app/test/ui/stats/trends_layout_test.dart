import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
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

Future<({ProviderContainer container, Ledger ledger, ManualRunner runner})>
_pumpOpen(WidgetTester tester, {bool addPresented = false}) async {
  tester.view.physicalSize = _openSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ledger = emptyTrendsLedger();
  addTrendsEntry(ledger, '-40', DateTime.utc(2026, 7, 4));
  addTrendsEntry(ledger, '-25', DateTime.utc(2026, 10, 2));
  final runner = ManualRunner();
  final container = TrendsHarness(
    ledger: ledger,
    today: _testToday,
    runner: runner.call,
  ).container;
  await tester.pumpWidget(
    _TrendsApp(
      container: container,
      mode: ShellLayoutMode.open,
      addPresented: addPresented,
      size: _openSize,
    ),
  );
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
  await tester.pumpWidget(
    _TrendsApp(
      container: container,
      mode: mode,
      addPresented: addPresented,
      size: size,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'period selection survives open, phone and open presentation changes',
    (tester) async {
      final setup = await _pumpOpen(tester);
      await tester.tap(find.bySemanticsLabel('July 2026'));
      await tester.pumpAndSettle();
      final selected = setup.container.read(trendsIntentProvider).selected;
      final screenElement = tester.element(find.byType(TrendsScreen));
      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
      expect(find.byType(TrendsScreen), findsOneWidget);

      await _setShell(
        tester,
        setup.container,
        mode: ShellLayoutMode.phone,
        addPresented: false,
        size: _phoneSize,
      );
      await _setShell(
        tester,
        setup.container,
        mode: ShellLayoutMode.open,
        addPresented: false,
        size: _openSize,
      );

      expect(
        identical(screenElement, tester.element(find.byType(TrendsScreen))),
        isTrue,
      );
      expect(setup.container.read(trendsIntentProvider).selected, selected);
      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
      expect(find.byType(CategoryDetailScreen), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'whole-period category drill-down is single-route and survives refresh',
    (tester) async {
      final setup = await _pumpOpen(tester);
      final viewModel = setup.container.read(trendsViewModelProvider.notifier);
      final selected = setup.container.read(trendsIntentProvider).selected;
      final category = find.descendant(
        of: find.byType(TrendsScreen),
        matching: find.descendant(
          of: find.byType(InkWell),
          matching: find.text('Food'),
        ),
      );
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryDetailScreen), findsOneWidget);

      viewModel.requestCategoryDetail(
        0,
        source: TrendsCategoryDetailSource.wholePeriod,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CategoryDetailScreen), findsOneWidget);

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
      expect(find.byType(CategoryDetailScreen), findsOneWidget);
      expect(setup.container.read(trendsIntentProvider).selected, selected);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CategoryDetailScreen), findsNothing);
      expect(setup.container.read(trendsIntentProvider).selected, selected);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'retained-data failure and Retry clear financial totals from both panes',
    (tester) async {
      final setup = await _pumpOpen(tester);
      expect(find.textContaining('25.00'), findsWidgets);
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
      setup.runner.pending.last.completeError(StateError('compute failed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('25.00'), findsNothing);

      await tester.tap(find.text('Retry').first);
      await tester.pumpAndSettle();
      await tester.runAsync(() => settle(setup.runner, setup.ledger));
      await tester.pumpAndSettle();
      expect(find.textContaining('25.00'), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Add hides and restores the retained period detail pane', (
    tester,
  ) async {
    final setup = await _pumpOpen(tester);
    expect(find.byKey(shellDetailPaneKey, skipOffstage: false), findsOneWidget);
    expect(find.byKey(shellDetailPaneKey), findsOneWidget);
    await _setShell(
      tester,
      setup.container,
      mode: ShellLayoutMode.open,
      addPresented: true,
      size: _openSize,
    );
    expect(find.byKey(shellDetailPaneKey), findsNothing);
    await _setShell(
      tester,
      setup.container,
      mode: ShellLayoutMode.open,
      addPresented: false,
      size: _openSize,
    );
    expect(find.byKey(shellDetailPaneKey), findsOneWidget);
  }, timeout: uiTestTimeout);
}
