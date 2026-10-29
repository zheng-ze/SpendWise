import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/accounts/account_form/account_form.dart';
import 'package:spendwise/ui/accounts/account_form/account_form_view_model.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/common/lists/responsive_summary_card.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_sheet_occupancy.dart';

import '../../support/ui_test_timeout.dart';

void expectAccountsSummaryConfiguration(
  WidgetTester tester,
  ProviderContainer container, {
  required bool wideComposition,
}) {
  final netWorth = container.read(accountsViewModelProvider).value!.netWorth;
  final summary = tester.widget<ResponsiveSummaryCard>(
    find.descendant(
      of: find.byType(AccountsScreen),
      matching: find.byType(ResponsiveSummaryCard),
    ),
  );

  expect(summary.metrics.map((metric) => metric.label).toList(), [
    'Net worth',
    'Assets',
    'Owed',
  ]);
  expect(summary.metrics.map((metric) => metric.amount).toList(), [
    netWorth.asset - netWorth.liability,
    netWorth.asset,
    netWorth.liability,
  ]);
  expect(summary.metrics.map((metric) => metric.kind).toList(), [
    null,
    null,
    AmountKind.expense,
  ]);
  expect(summary.metrics.map((metric) => metric.emphasis).toList(), [
    SummaryMetricEmphasis.primary,
    SummaryMetricEmphasis.supporting,
    SummaryMetricEmphasis.supporting,
  ]);
  expect(summary.wideComposition, wideComposition);
}

ShellPaneScope _accountsPaneScope(WidgetTester tester) {
  final context = tester.element(find.byType(AccountsScreen));
  return ShellPaneScope.of(context);
}

Future<void> _pumpAccountsShell(
  WidgetTester tester,
  ProviderContainer container,
  MoneyNavigatorObserver observer, {
  String? Function()? moneySourceId,
}) async {
  final shell = AppShell(
    moneySourceId: moneySourceId,
    bodies: {ShellDestination.money: (_) => MoneyFlow(moneyObserver: observer)},
  );
  final app = MaterialApp(builder: buildShellAppContent, home: shell);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in [ShellLayoutMode.open, ShellLayoutMode.desktop]) {
    testWidgets(
      '${mode.name} isolation retains Money, Budgets and Accounts Flows',
      (tester) => _verifyMoneyFlowRetention(tester, mode),
      timeout: uiTestTimeout,
    );
  }

  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Main Checking',
    type: AccountType.checking,
  );
  final card = Account(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Travel Card',
    type: AccountType.card,
  );

  Ledger buildLedger() {
    return Ledger(
      state: LedgerState(
        moneySources: {
          checking.id: MoneySource.account(checking),
          card.id: MoneySource.account(card),
        },
      ),
    );
  }

  Future<ProviderContainer> pumpFlow(WidgetTester tester, Ledger ledger) async {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountsFlow()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('AccountOpened pushes a TransactionsFlow with a tappable back '
      'button, so a platform with no system back gesture can still return to '
      'the accounts list', (tester) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(accountsViewModelProvider.notifier).openAccount(checking.id);
    await tester.pumpAndSettle();

    expect(find.byType(AccountsScreen), findsNothing);

    final backButtonFinder = find.byTooltip('Back');
    expect(backButtonFinder, findsOneWidget);

    await tester.tap(backButtonFinder);
    await tester.pumpAndSettle();

    expect(find.byType(AccountsScreen), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('pocket parent selection uses the Accounts picker sheet', (
    tester,
  ) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(accountsViewModelProvider.notifier).requestNewAccount();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subpocket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.byType(AppPickerSheet), findsOneWidget);
    expect(find.text('Select Account'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets(
    'ignores parent selection after the originating form route is removed',
    (tester) async {
      final container = await pumpFlow(tester, buildLedger());

      container.read(accountsViewModelProvider.notifier).requestNewAccount();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subpocket'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Discarded draft');
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      final formContext = tester.element(find.byType(AccountForm));
      final navigator = Navigator.of(formContext, rootNavigator: true);
      navigator.pop(const PickerChose('a0000000-0000-0000-0000-000000000001'));
      navigator.pop();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AccountForm), findsOneWidget);
      expect(
        container.read(accountFormViewModelProvider).value?.parentId,
        isNull,
      );
      await tester.pumpAndSettle();

      container.read(accountsViewModelProvider.notifier).requestNewAccount();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subpocket'));
      await tester.pumpAndSettle();

      expect(find.text('Select'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'scoped Transactions fills Money content and Back restores Accounts state',
    (tester) async {
      final ledger = buildLedger();
      final observer = MoneyNavigatorObserver();
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(ledger),
          moneyNavigatorObserverProvider.overrideWithValue(observer),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: MoneyFlow(moneyObserver: observer)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Money'), findsOneWidget);
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Plans'), findsOneWidget);

      container
          .read(accountsViewModelProvider.notifier)
          .toggleExpanded(checking.id);
      container
          .read(accountsViewModelProvider.notifier)
          .openAccount(checking.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Money'), findsNothing);
      expect(find.text('Budgets'), findsNothing);
      expect(find.text('Accounts'), findsNothing);
      expect(find.text('Plans'), findsNothing);
      expect(find.text('Main Checking'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Money'), findsOneWidget);
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.byType(AccountsScreen), findsOneWidget);
      expect(container.read(moneySegmentProvider), MoneySegment.accounts);
      expect(
        container.read(accountsViewModelProvider).value?.expandedAccountId,
        checking.id,
      );
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'scoped Transactions route survives Add presentation changes and Back',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final observer = MoneyNavigatorObserver();
      late ProviderContainer container;
      container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(buildLedger()),
          shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
          moneyNavigatorObserverProvider.overrideWithValue(observer),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.money;

      await _pumpAccountsShell(
        tester,
        container,
        observer,
        moneySourceId: container.read(activeMoneySourceProvider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Main Checking'));
      await tester.pumpAndSettle();
      expect(find.text('Main Checking'), findsOneWidget);
      expect(observer.sourceId, checking.id);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsOneWidget);

      await tester.tapAt(const Offset(120, 120));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsNothing);
      expect(find.text('Main Checking'), findsOneWidget);
      expect(observer.sourceId, checking.id);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountsScreen), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('account forms constrain and compact the open Money pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 54, right: 54);
    addTearDown(tester.view.reset);
    final observer = MoneyNavigatorObserver();
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger()),
        shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
        moneyNavigatorObserverProvider.overrideWithValue(observer),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;
    await _pumpAccountsShell(tester, container, observer);
    await tester.pumpAndSettle();

    final viewModel = container.read(accountsViewModelProvider.notifier);
    for (final request in [
      () => viewModel.requestNewAccount(),
      () => viewModel.requestSourceEdit(checking.id),
    ]) {
      request();
      await tester.pumpAndSettle();

      final sheetContext = tester.element(find.byType(AppSheet).last);
      final presentation = ProviderScope.containerOf(sheetContext)
          .read(shellSheetOccupancyProvider);
      expect(presentation.hasSheets, isTrue);
      expect(_accountsPaneScope(tester).addPresented, isTrue);
      expectAccountsSummaryConfiguration(
        tester,
        container,
        wideComposition: false,
      );
      final segments = tester.widget<SegmentedControl<MoneySegment>>(
        find.byType(SegmentedControl<MoneySegment>),
      );
      expect(segments.small, isTrue);
      expect(find.text('Money'), findsNWidgets(2));
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Plans'), findsOneWidget);
      expect(find.text('Main Checking'), findsAtLeastNWidgets(1));
      expect(find.text('Assets'), findsOneWidget);
      expect(find.text('Owed'), findsOneWidget);
      expect(find.text('Travel Card'), findsOneWidget);
      expect(find.textContaining('Payable'), findsOneWidget);
      expect(find.textContaining('Outstanding'), findsOneWidget);

      expect(container.read(moneySegmentProvider), MoneySegment.accounts);
      expect(tester.takeException(), isNull);

      Navigator.of(sheetContext, rootNavigator: true).pop();
      await tester.pump();
      expect(_accountsPaneScope(tester).addPresented, isTrue);
      await tester.pumpAndSettle();
      expect(_accountsPaneScope(tester).addPresented, isFalse);
    }
  }, timeout: uiTestTimeout);

  testWidgets('desktop account forms compact the Accounts summary like open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final observer = MoneyNavigatorObserver();
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger()),
        shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.desktop),
        moneyNavigatorObserverProvider.overrideWithValue(observer),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;

    await _pumpAccountsShell(tester, container, observer);
    await tester.pumpAndSettle();

    container.read(accountsViewModelProvider.notifier).requestNewAccount();
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.text('New Account'), findsOneWidget);
    final sheetContext = tester.element(find.byType(AppSheet).last);
    final presentation = ProviderScope.containerOf(sheetContext)
        .read(shellSheetOccupancyProvider);
    expect(presentation.hasSheets, isTrue);
    expectAccountsSummaryConfiguration(
      tester,
      container,
      wideComposition: false,
    );
    expect(
      tester
          .widget<SegmentedControl<MoneySegment>>(
            find.byType(SegmentedControl<MoneySegment>),
          )
          .small,
      isTrue,
    );
  }, timeout: uiTestTimeout);
}

const _retainedBudgetId = 'b0000000-0000-0000-0000-000000000001';
const _retentionSheetTimeout = Duration(seconds: 5);

Ledger _retentionLedger() {
  final budget = Budget(
    id: _retainedBudgetId,
    categoryID: null,
    limitEvents: [
      LimitEvent(
        effectiveFromMonth: null,
        value: Decimal.fromInt(100),
        kind: LimitEventKind.defaultLimit,
      ),
    ],
    createdAtMonth: const YearMonth(2026, 1),
  );
  return Ledger(state: LedgerState(budgets: {budget.id: budget}));
}

List<State<StatefulWidget>> _moneyFlowStates(WidgetTester tester) => [
  tester.state(find.byType(MoneyFlow, skipOffstage: false)),
  tester.state(find.byType(BudgetsFlow, skipOffstage: false)),
  tester.state(find.byType(AccountsFlow, skipOffstage: false)),
];

void _expectSameFlowStates(
  WidgetTester tester,
  List<State<StatefulWidget>> states,
) {
  final current = _moneyFlowStates(tester);
  for (var index = 0; index < states.length; index++) {
    expect(current[index], same(states[index]));
  }
}

Future<void> _verifyMoneyFlowRetention(
  WidgetTester tester,
  ShellLayoutMode mode,
) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final observer = MoneyNavigatorObserver();
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(_retentionLedger()),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
      shellLayoutModeProvider.overrideWithValue(mode),
      moneyNavigatorObserverProvider.overrideWithValue(observer),
    ],
  );
  addTearDown(container.dispose);
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.money;
  await _pumpAccountsShell(tester, container, observer);
  final states = _moneyFlowStates(tester);
  container.read(moneySegmentProvider.notifier).state = MoneySegment.budgets;
  container.read(selectedBudgetProvider.notifier).select(_retainedBudgetId);
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(AppShell));
  final presentation = mode == ShellLayoutMode.desktop
      ? AppSheetPresentation.desktop
      : AppSheetPresentation.open;
  final route = AppSheetRoute<void>(
    presentation: presentation,
    builder: (_) => const AppSheet(header: Text('Form'), body: Text('Draft')),
  );
  Navigator.of(context, rootNavigator: true).push(route);
  await tester.pumpAndSettle();
  expect(route.dimsBackground, isFalse);
  _expectSameFlowStates(tester, states);
  container.read(moneySegmentProvider.notifier).state = MoneySegment.accounts;
  await tester.pumpAndSettle();
  expect(container.read(selectedBudgetProvider), _retainedBudgetId);
  _expectSameFlowStates(tester, states);
  container.read(moneySegmentProvider.notifier).state = MoneySegment.budgets;
  await tester.pumpAndSettle();
  _expectSameFlowStates(tester, states);
  route.navigator!.pop();
  await tester.pumpAndSettle();
  await route.completed.timeout(_retentionSheetTimeout);
  _expectSameFlowStates(tester, states);
}
