import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
import 'package:spendwise/ui/budgets/budget_list/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';

final _modeFixture = StateProvider<ShellLayoutMode>(
  (ref) => ShellLayoutMode.phone,
);

final _ledgerFixture = StateProvider<Ledger?>((ref) => null);

final _food = TransactionCategory(
  id: 'c0000000-0000-0000-0000-000000000001',
  name: 'Food',
  kind: CategoryKind.expense,
  colorHex: '#00AA00',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'restaurant',
);

final _account = Account(
  id: 'a0000000-0000-0000-0000-000000000001',
  name: 'Checking',
  type: AccountType.checking,
);

const _budgetDetailTryAgain = 'Try again';
const _groceriesName = 'Groceries';
const _defaultBudgetRowLabel = 'Default Budget';
const _limitFieldAmount = '75';
const _saveLabel = 'Save';
const _editLabel = 'Edit';
const _coverLabel = 'Cover';
const _newerLabel = 'Newer';

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
    moneySources: {_account.id: MoneySource.account(_account)},
    categories: {_food.id: _food},
    budgets: {
      'b1': _budget(id: 'b1'),
      'b2': _budget(id: 'b2', categoryID: _food.id, limit: 50),
    },
  ),
);

ProviderContainer _container({
  required Ledger ledger,
  ComputeRunner? runner,
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWith((ref) => ref.watch(_ledgerFixture)),
      analysisComputeRunnerProvider.overrideWithValue(
        runner ?? syncComputeRunner,
      ),
      todayProvider.overrideWithValue(DateTime.utc(2026, 3, 3)),
      selectedMonthProvider.overrideWith((ref) => DateTime.utc(2026, 3)),
      shellLayoutModeProvider.overrideWith((ref) => ref.watch(_modeFixture)),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  container.read(_ledgerFixture.notifier).state = ledger;
  return container;
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required ShellLayoutMode mode,
  ComputeRunner? runner,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final observer = MoneyNavigatorObserver();
  final container = _container(
    ledger: _ledger(),
    runner: runner,
    overrides: [moneyNavigatorObserverProvider.overrideWithValue(observer)],
  );
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

Future<void> _tapBudget(WidgetTester tester, String budgetID) async {
  await tester.tap(find.byKey(ValueKey('budget-$budgetID')));
  await tester.pumpAndSettle();
}

Finder _inPane(Finder finder) =>
    find.descendant(of: find.byKey(shellDetailPaneKey), matching: finder);

bool _hasDetailOwners(ProviderContainer container, String budgetID) =>
    container.exists(budgetDetailViewModelProvider(budgetID)) ||
    container.exists(budgetDetailContextProvider(budgetID)) ||
    container.exists(budgetLimitViewModelProvider(budgetID));

NavigatorState _rootNavigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

void main() {
  testWidgets(
    'open selection shows one pane and selecting another budget replaces it',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);

      await _tapBudget(tester, 'b2');
      expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');
      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
      expect(find.byType(BudgetDetailScreen), findsNothing);

      final selected = container.read(selectedBudgetProvider);
      await _tapBudget(tester, 'b2');
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
      await _tapBudget(tester, 'b2');

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
    await _tapBudget(tester, 'b2');

    await tester.tap(find.text(_editLabel));
    await tester.pumpAndSettle();

    expect(find.byType(BudgetLimitScreen), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('phone selection opens one page and updates it in place', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.phone);
    await _tapBudget(tester, 'b2');
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
    await _tapBudget(tester, 'b2');

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

  testWidgets('desktop presents the detail as a page and open as a pane', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.desktop);
    await _tapBudget(tester, 'b2');
    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(find.byKey(shellDetailPaneKey), findsNothing);

    container.read(_modeFixture.notifier).state = ShellLayoutMode.open;
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsNothing);
    expect(find.byKey(shellDetailPaneKey), findsOneWidget);
    expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');

    container.read(_modeFixture.notifier).state = ShellLayoutMode.desktop;
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');
  }, timeout: uiTestTimeout);

  testWidgets(
    'Back on the phone page clears the selection and releases owners',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.phone);
      await _tapBudget(tester, 'b2');

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
      await _tapBudget(tester, 'b2');
      await tester.tap(find.text(_editLabel));
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
    'open to phone under an unrelated cover restores one page when it closes',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');
      _rootNavigator(
        tester,
      ).push(MaterialPageRoute<void>(builder: (_) => const Text(_coverLabel)));
      await tester.pumpAndSettle();

      container.read(_modeFixture.notifier).state = ShellLayoutMode.phone;
      await tester.pumpAndSettle();
      expect(find.byType(BudgetDetailScreen), findsNothing);

      _rootNavigator(tester).pop();
      await tester.pumpAndSettle();
      expect(find.byType(BudgetDetailScreen), findsOneWidget);
      expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Add hides the pane while the selection and detail owners remain',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');

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

  testWidgets(
    'a ledger commit made while Add hides the pane is visible on return',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');
      container.read(accountSheetPresentedProvider.notifier).state = true;
      await tester.pumpAndSettle();

      container
          .read(ledgerProvider)!
          .addEntry(
            Entry(
              amount: Decimal.parse('-12'),
              name: _groceriesName,
              sourceID: _account.id,
              categoryID: _food.id,
              date: DateTime.utc(2026, 3, 2),
            ),
          );
      await tester.pumpAndSettle();

      container.read(accountSheetPresentedProvider.notifier).state = false;
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');
      expect(_inPane(find.text(_groceriesName)), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a retry from the pane keeps the selected budget, month and year',
    (tester) async {
      var fail = false;
      final container = await _pumpShell(
        tester,
        mode: ShellLayoutMode.open,
        runner: (state) async {
          if (fail) throw StateError('Data unavailable');
          return syncComputeRunner(state);
        },
      );
      await _tapBudget(tester, 'b2');
      final notifier = container.read(
        budgetDetailContextProvider('b2').notifier,
      );
      notifier.selectMonth(DateTime.utc(2026, 1));
      notifier.changeYear(DateTime.utc(2025));
      await tester.pumpAndSettle();
      final before = container.read(budgetDetailContextProvider('b2'));

      fail = true;
      container
          .read(ledgerProvider)!
          .updateBudgetAmount(
            'b2',
            Decimal.fromInt(60),
            const YearMonth(2026, 1),
          );
      await tester.pumpAndSettle();
      expect(_inPane(find.text(_budgetDetailTryAgain)), findsOneWidget);

      fail = false;
      await tester.tap(_inPane(find.text(_budgetDetailTryAgain)));
      await tester.pumpAndSettle();

      expect(_inPane(find.text(_budgetDetailTryAgain)), findsNothing);
      expect(container.read(budgetDetailContextProvider('b2')), before);
      expect(container.read(selectedBudgetProvider)?.budgetID, 'b2');
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a completed history route from a replaced selection keeps the newer owners',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');
      await tester.tap(find.text(_editLabel));
      await tester.pumpAndSettle();

      container.read(selectedBudgetProvider.notifier).select('b1');
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(BudgetLimitScreen), findsNothing);
      expect(container.read(selectedBudgetProvider)?.budgetID, 'b1');
      expect(container.exists(budgetDetailViewModelProvider('b1')), isTrue);
      expect(container.exists(budgetLimitViewModelProvider('b1')), isTrue);
      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'replacing the ledger session clears the selection and releases its owners',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');

      container.read(_ledgerFixture.notifier).state = _ledger();
      await tester.pumpAndSettle();

      expect(container.read(selectedBudgetProvider), isNull);
      expect(find.byKey(shellDetailPaneKey), findsNothing);
      expect(_hasDetailOwners(container, 'b2'), isFalse);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a delayed limit editor result after a ledger replacement does not mutate',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');
      await tester.tap(find.text(_editLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_defaultBudgetRowLabel));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), _limitFieldAmount);

      container.read(_ledgerFixture.notifier).state = _ledger();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, _saveLabel));
      await tester.pumpAndSettle();

      final limit = effectiveLimit(
        container.read(ledgerProvider)!.state.budgets['b2']!,
        const YearMonth(2026, 3),
      );
      expect(limit, Decimal.fromInt(50));
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a pending Budgets step is not consumed while Accounts is active and runs when Budgets returns',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      container.read(moneySegmentProvider.notifier).state =
          MoneySegment.accounts;
      await tester.pumpAndSettle();

      container.read(budgetsListViewModelProvider.notifier).requestNewBudget();
      await tester.pumpAndSettle();
      expect(find.byType(BudgetForm), findsNothing);
      expect(
        container.read(budgetsListViewModelProvider).requireValue.step,
        isA<BudgetFormRequested>(),
      );

      container.read(moneySegmentProvider.notifier).state =
          MoneySegment.budgets;
      await tester.pumpAndSettle();
      expect(find.byType(BudgetForm), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'disposing the flow removes its page and keeps a newer unrelated route',
    (tester) async {
      final container = _container(ledger: _ledger());
      Widget host({required bool showFlow}) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: showFlow ? const BudgetsFlow() : const SizedBox(),
          ),
        ),
      );
      await tester.pumpWidget(host(showFlow: true));
      await tester.pumpAndSettle();
      await _tapBudget(tester, 'b2');
      expect(find.byType(BudgetDetailScreen), findsOneWidget);

      _rootNavigator(
        tester,
      ).push(MaterialPageRoute<void>(builder: (_) => const Text(_newerLabel)));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(showFlow: false));
      await tester.pumpAndSettle();

      expect(find.byType(BudgetDetailScreen), findsNothing);
      expect(find.text(_newerLabel), findsOneWidget);
      expect(_hasDetailOwners(container, 'b2'), isFalse);
    },
    timeout: uiTestTimeout,
  );
}
