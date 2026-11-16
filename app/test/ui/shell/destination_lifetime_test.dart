import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_month.dart'
    show startOfMonthUtc;
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/money/money_segment.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/settings/settings_root_screen.dart';
import 'package:spendwise/ui/stats/trends_flow.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/transactions/trends_detail_action.dart';

import '../../support/shell_sheet_harness.dart';
import '../budgets/budget_shell_test_support.dart';
import '../overview/overview_fixture.dart';
import '../../support/ui_test_timeout.dart';

void main() {
  testWidgets(
    'History keeps its previous month after opening Trends and going Back',
    (tester) async {
      final container = _emptyLedgerContainer();
      addTearDown(container.dispose);
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.history;
      await pumpShellApp(
        tester,
        container,
        bodies: {ShellDestination.history: (_) => const TransactionsFlow()},
      );

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final previousMonth = formatMonthLabel(
        DateTime.utc(now.year, now.month - 1),
      );
      expect(find.text(previousMonth), findsOneWidget);

      await tester.tap(find.text(trendsDetailActionLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text(previousMonth), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Overview View History opens History at the current month without Trends',
    (tester) async {
      final ledger = Ledger(state: emptyState());
      final container = overviewContainer(ledger);
      void selectHistory() {
        container.read(selectedDestinationProvider.notifier).state =
            ShellDestination.history;
      }

      void ignoreBudgets() {}

      await pumpShellApp(
        tester,
        container,
        bodies: {
          ShellDestination.overview: (_) => OverviewFlow(
            onHistorySelected: selectHistory,
            onBudgetsSelected: ignoreBudgets,
          ),
          ShellDestination.history: (_) => const TransactionsFlow(),
        },
      );
      await tester.runAsync(() => settleAnalysis(container, ledger));
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.history;
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(trendsDetailActionLabel));
      await tester.pumpAndSettle();
      expect(find.byType(TrendsFlow), findsOneWidget);

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.overview;
      await tester.pumpAndSettle();
      await tester.tap(find.text(overviewHistoryLink));
      await tester.pumpAndSettle();

      final today = container.read(todayProvider);
      final currentMonth = formatMonthLabel(startOfMonthUtc(today));
      expect(find.text(currentMonth), findsOneWidget);
      expect(find.byType(TrendsFlow), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Settings returns to its root after leaving it from Categories', (
    tester,
  ) async {
    final container = _emptyLedgerContainer();
    addTearDown(container.dispose);
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.settings;
    await pumpShellApp(
      tester,
      container,
      bodies: {
        ShellDestination.history: (_) => const SizedBox.shrink(),
        ShellDestination.settings: (_) => const SettingsFlow(),
      },
    );
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryListScreen), findsOneWidget);

    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.history;
    await tester.pumpAndSettle();
    expect(find.byType(SettingsFlow), findsNothing);
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.settings;
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(CategoryListScreen), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets(
    'Money returns to Accounts with no selected budget after leaving it',
    (tester) async {
      final container = await _pumpMoneyAndHistory(tester, buildShellLedger());
      await _selectBudgetB2(tester, container);
      expect(container.read(selectedBudgetProvider), 'b2');

      await _leaveAndReturnToMoney(tester, container);

      expect(container.read(moneySegmentProvider), MoneySegment.accounts);
      expect(container.read(selectedBudgetProvider.exists), isFalse);
      await tester.tap(find.text('Budgets'));
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetProvider), isNull);
      expect(find.byType(BudgetDetailScreen), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a budget deleted while Money was unmounted leaves no stale detail',
    (tester) async {
      final ledger = buildShellLedger();
      final container = await _pumpMoneyAndHistory(tester, ledger);
      await _selectBudgetB2(tester, container);

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.history;
      await tester.pumpAndSettle();
      ledger.deleteBudget('b2');
      await tester.pumpAndSettle();
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.money;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budgets'));
      await tester.pumpAndSettle();

      expect(container.read(selectedBudgetProvider), isNull);
      expect(find.byType(BudgetDetailScreen), findsNothing);
      expect(find.byKey(const ValueKey('budget-b2')), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Overview Set a monthly cap opens Money at Budgets',
    (tester) async {
      final ledger = _noCapLedgerWithEntryToday();
      final container = buildShellContainer(ledger: ledger);
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.overview;
      void openBudgets() => container
          .read(moneySegmentProvider.notifier)
          .openAt(MoneySegment.budgets);
      void ignoreHistory() {}
      await pumpShellApp(
        tester,
        container,
        bodies: {
          ShellDestination.overview: (_) => OverviewFlow(
            onHistorySelected: ignoreHistory,
            onBudgetsSelected: openBudgets,
          ),
          ShellDestination.money: (_) => const MoneyFlow(),
        },
      );
      await tester.runAsync(() => settleAnalysis(container, ledger));
      await tester.pumpAndSettle();
      expect(container.read(moneySegmentProvider), MoneySegment.accounts);

      await tester.tap(find.text(overviewNoCapLink));
      await tester.pumpAndSettle();

      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.money,
      );
      expect(container.read(moneySegmentProvider), MoneySegment.budgets);
      expect(find.byType(BudgetsFlow), findsOneWidget);
      expect(container.read(selectedBudgetProvider), isNull);
    },
    timeout: uiTestTimeout,
  );
}

Ledger _noCapLedgerWithEntryToday() {
  final state = emptyState();
  final today = DateTime.utc(2026, 3, 3);
  state.addEntry(entry(1, '-5.00', today, categoryID: groceriesID));
  return Ledger(state: state);
}

ProviderContainer _emptyLedgerContainer() {
  final ledger = Ledger(state: LedgerState());
  return ProviderContainer(
    overrides: [ledgerProvider.overrideWithValue(ledger)],
  );
}

Future<ProviderContainer> _pumpMoneyAndHistory(
  WidgetTester tester,
  Ledger ledger,
) async {
  useShellWindow(tester, const Size(1024, 800));
  final container = buildShellContainer(ledger: ledger);
  container.read(budgetShellModeFixture.notifier).state = ShellLayoutMode.open;
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.money;
  await pumpShellApp(
    tester,
    container,
    bodies: {
      ShellDestination.money: (_) => const MoneyFlow(),
      ShellDestination.history: (_) => const SizedBox.shrink(),
    },
  );
  return container;
}

Future<void> _selectBudgetB2(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.tap(find.text('Budgets'));
  await tester.pumpAndSettle();
  await tapBudget(tester, 'b2');
}

Future<void> _leaveAndReturnToMoney(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.history;
  await tester.pumpAndSettle();
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.money;
  await tester.pumpAndSettle();
}
