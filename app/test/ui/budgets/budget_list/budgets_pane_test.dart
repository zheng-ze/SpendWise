import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';

final _modeFixture = StateProvider<ShellLayoutMode>(
  (ref) => ShellLayoutMode.phone,
);

final _food = TransactionCategory(
  id: 'c0000000-0000-0000-0000-000000000001',
  name: 'Food',
  kind: CategoryKind.expense,
  colorHex: '#00AA00',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'restaurant',
);

Budget _budget({required String id, String? categoryID, int limit = 100}) =>
    Budget(
      id: id,
      categoryID: categoryID,
      limitEvents: [
        LimitEvent(
          effectiveFromMonth: null,
          value: Decimal.fromInt(limit),
          kind: LimitEventKind.defaultLimit,
        ),
      ],
      createdAtMonth: const YearMonth(2026, 1),
    );

Ledger _ledger() => Ledger(
  state: LedgerState(
    categories: {_food.id: _food},
    budgets: {
      'b1': _budget(id: 'b1'),
      'b2': _budget(id: 'b2', categoryID: _food.id, limit: 50),
    },
  ),
);

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required ShellLayoutMode mode,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final observer = MoneyNavigatorObserver();
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(_ledger()),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
      todayProvider.overrideWithValue(DateTime.utc(2026, 3, 3)),
      selectedMonthProvider.overrideWith((ref) => DateTime.utc(2026, 3)),
      moneyNavigatorObserverProvider.overrideWithValue(observer),
      shellLayoutModeProvider.overrideWith((ref) => ref.watch(_modeFixture)),
    ],
  );
  addTearDown(container.dispose);
  container.read(_modeFixture.notifier).state = mode;
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.money;
  container.read(moneySegmentProvider.notifier).state = MoneySegment.budgets;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: AppShell(
          bodies: {
            ShellDestination.money: (_) => MoneyFlow(moneyObserver: observer),
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

bool _hasDetailOwners(ProviderContainer container, String budgetID) =>
    container.exists(budgetDetailViewModelProvider(budgetID)) ||
    container.exists(budgetDetailContextProvider(budgetID)) ||
    container.exists(budgetLimitViewModelProvider(budgetID));

void main() {
  testWidgets(
    'open selection shows one pane and selecting another budget replaces it',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);

      await tester.tap(find.byKey(const ValueKey('budget-b2')));
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');
      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
      expect(find.byType(BudgetDetailScreen), findsNothing);

      final selected = container.read(selectedBudgetProvider);
      await tester.tap(find.byKey(const ValueKey('budget-b2')));
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetProvider), selected);

      await tester.tap(find.text('S\$100.00'));
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetProvider)?.budgetID, 'b1');
      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
      expect(_hasDetailOwners(container, 'b2'), isFalse);
      expect(container.exists(budgetDetailViewModelProvider('b1')), isTrue);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Close clears the selection and releases the detail owners of the budget',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await tester.tap(find.byKey(const ValueKey('budget-b2')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(shellDetailCloseKey));
      await tester.pumpAndSettle();

      expect(container.read(selectedBudgetProvider), isNull);
      expect(find.byKey(shellDetailPaneKey), findsNothing);
      expect(_hasDetailOwners(container, 'b2'), isFalse);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Edit in the pane opens the existing limit history screen', (
    tester,
  ) async {
    await _pumpShell(tester, mode: ShellLayoutMode.open);
    await tester.tap(find.byKey(const ValueKey('budget-b2')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(BudgetLimitScreen), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('phone selection opens one page and updates it in place', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.phone);
    await tester.tap(find.byKey(const ValueKey('budget-b2')));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(find.byKey(shellDetailPaneKey), findsNothing);

    container.read(selectedBudgetProvider.notifier).select('b1');
    await tester.pumpAndSettle();

    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(container.exists(budgetDetailViewModelProvider('b2')), isFalse);
    expect(container.exists(budgetDetailViewModelProvider('b1')), isTrue);
  }, timeout: uiTestTimeout);

  testWidgets('phone and open conversion keeps one detail and its selection', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.phone);
    await tester.tap(find.byKey(const ValueKey('budget-b2')));
    await tester.pumpAndSettle();

    container.read(_modeFixture.notifier).state = ShellLayoutMode.open;
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsNothing);
    expect(find.byKey(shellDetailPaneKey), findsOneWidget);
    expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');

    container.read(_modeFixture.notifier).state = ShellLayoutMode.phone;
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(find.byKey(shellDetailPaneKey), findsNothing);
    expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');
  }, timeout: uiTestTimeout);

  testWidgets(
    'Back on the phone page clears the selection and releases owners',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.phone);
      await tester.tap(find.byKey(const ValueKey('budget-b2')));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(container.read(selectedBudgetProvider), isNull);
      expect(_hasDetailOwners(container, 'b2'), isFalse);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'open to phone with history open restores one page after history closes',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await tester.tap(find.byKey(const ValueKey('budget-b2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      container.read(_modeFixture.notifier).state = ShellLayoutMode.phone;
      await tester.pumpAndSettle();
      expect(find.byType(BudgetLimitScreen), findsOneWidget);
      expect(find.byType(BudgetDetailScreen), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(BudgetLimitScreen), findsNothing);
      expect(find.byType(BudgetDetailScreen), findsOneWidget);
      expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Add hides the pane while the selection and detail owners remain',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await tester.tap(find.byKey(const ValueKey('budget-b2')));
      await tester.pumpAndSettle();

      container.read(accountSheetPresentedProvider.notifier).state = true;
      await tester.pumpAndSettle();
      expect(find.byKey(shellDetailPaneKey), findsNothing);
      expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');
      expect(container.exists(budgetDetailViewModelProvider('b2')), isTrue);

      container.read(accountSheetPresentedProvider.notifier).state = false;
      await tester.pumpAndSettle();
      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );
}
