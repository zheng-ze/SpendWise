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
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
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
const _saveLabel = 'Save';
const _trayInteriorOffset = Offset(2, 2);
const _editLabel = 'Edit';
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
  final providerOverrides = <Override>[
    ledgerProvider.overrideWith((ref) => ref.watch(_ledgerFixture)),
    analysisComputeRunnerProvider.overrideWithValue(
      runner ?? syncComputeRunner,
    ),
    todayProvider.overrideWithValue(DateTime.utc(2026, 3, 3)),
    selectedMonthProvider.overrideWith((ref) => DateTime.utc(2026, 3)),
    shellLayoutModeProvider.overrideWith((ref) => ref.watch(_modeFixture)),
    ...overrides,
  ];
  final container = ProviderContainer(overrides: providerOverrides);
  addTearDown(container.dispose);
  container.read(_ledgerFixture.notifier).state = ledger;
  return container;
}

void _useWideView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

ProviderContainer _shellContainer({
  required Ledger ledger,
  ComputeRunner? runner,
}) {
  final observer = MoneyNavigatorObserver();
  return _container(
    ledger: ledger,
    runner: runner,
    overrides: [moneyNavigatorObserverProvider.overrideWithValue(observer)],
  );
}

Widget _shellApp(ProviderContainer container) {
  final observer = container.read(moneyNavigatorObserverProvider);
  final bodies = <ShellDestination, WidgetBuilder>{
    ShellDestination.money: (_) => MoneyFlow(moneyObserver: observer),
  };
  final shell = AppShell(bodies: bodies);
  return MaterialApp(
    builder: buildShellAppContent,
    navigatorObservers: [AppSheetRouteObserver()],
    home: shell,
  );
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required ShellLayoutMode mode,
  ComputeRunner? runner,
  Ledger? ledger,
}) async {
  _useWideView(tester);
  final container = _shellContainer(
    ledger: ledger ?? _ledger(),
    runner: runner,
  );
  container.read(_modeFixture.notifier).state = mode;
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.money;
  container.read(moneySegmentProvider.notifier).state = MoneySegment.budgets;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _shellApp(container),
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

Entry _entry(int index) => Entry(
  amount: Decimal.parse('-1'),
  name: 'Entry ${(index + 1).toString().padLeft(2, '0')}',
  sourceID: _account.id,
  categoryID: _food.id,
  date: DateTime.utc(2026, 3, 1 + index % 28),
);

Widget _flowHost(ProviderContainer container, {required bool showFlow}) {
  final body = showFlow ? const BudgetsFlow() : const SizedBox();
  final app = MaterialApp(home: Scaffold(body: body));
  return UncontrolledProviderScope(container: container, child: app);
}

Future<void> _openHistoryFromPane(WidgetTester tester) async {
  await _tapBudget(tester, 'b2');
  await tester.tap(find.text(_editLabel));
  await tester.pumpAndSettle();
}

void _selectSegment(ProviderContainer container, MoneySegment segment) {
  container.read(moneySegmentProvider.notifier).state = segment;
}

void main() {
  testWidgets(
    'open selection shows one pane and selecting another budget replaces it',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);

      await _tapBudget(tester, 'b2');
      expect(container.read(selectedBudgetProvider), 'b2');
      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
      expect(find.byType(BudgetDetailScreen), findsNothing);

      final selected = container.read(selectedBudgetProvider);
      await _tapBudget(tester, 'b2');
      expect(container.read(selectedBudgetProvider), selected);

      await tester.tap(find.text('S\$100.00'));
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetProvider), 'b1');
      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
      expect(_hasDetailOwners(container, 'b2'), isFalse);
      expect(container.exists(budgetDetailViewModelProvider('b1')), isTrue);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'empty list space clears the selection and releases the detail owners',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');

      expect(find.byKey(shellDetailCloseKey), findsNothing);
      await tester.tap(find.text('Category budgets'));
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

  testWidgets(
    'phone selection replaces the managed page without stacking pages',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.phone);
      await _tapBudget(tester, 'b2');
      expect(find.byType(BudgetDetailScreen), findsOneWidget);
      expect(find.byKey(shellDetailPaneKey), findsNothing);

      container.read(selectedBudgetProvider.notifier).select('b1');
      await tester.pumpAndSettle();

      expect(find.byType(BudgetDetailScreen), findsOneWidget);
      expect(container.exists(budgetDetailViewModelProvider('b2')), isFalse);
      expect(container.exists(budgetDetailViewModelProvider('b1')), isTrue);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('desktop presents the selected budget as a page', (tester) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.desktop);
    await _tapBudget(tester, 'b2');
    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(find.byKey(shellDetailPaneKey), findsNothing);
    expect(container.read(selectedBudgetProvider), 'b2');
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
    'Back followed by unfolding before the exit finishes still clears the selection',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.phone);
      await _tapBudget(tester, 'b2');

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 50));
      container.read(_modeFixture.notifier).state = ShellLayoutMode.open;
      await tester.pump();
      await tester.pumpAndSettle();

      expect(container.read(selectedBudgetProvider), isNull);
      expect(find.byKey(shellDetailPaneKey), findsNothing);
      expect(_hasDetailOwners(container, 'b2'), isFalse);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Add hides the pane while the selection and detail owners remain',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');

      final sheet = AppSheetRoute<void>(
        presentation: AppSheetPresentation.open,
        builder: (_) =>
            const AppSheet(header: Text('Form'), body: Text('Draft')),
      );
      Navigator.of(
        tester.element(find.byType(AppShell)),
        rootNavigator: true,
      ).push(sheet);
      await tester.pumpAndSettle();
      expect(find.byKey(shellDetailPaneKey), findsNothing);
      expect(container.read(selectedBudgetProvider), 'b2');
      expect(container.exists(budgetDetailViewModelProvider('b2')), isTrue);
      expect(container.exists(budgetDetailContextProvider('b2')), isTrue);
      expect(container.exists(budgetLimitViewModelProvider('b2')), isTrue);

      sheet.navigator!.pop();
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
      final sheet = AppSheetRoute<void>(
        presentation: AppSheetPresentation.open,
        builder: (_) =>
            const AppSheet(header: Text('Form'), body: Text('Draft')),
      );
      Navigator.of(
        tester.element(find.byType(AppShell)),
        rootNavigator: true,
      ).push(sheet);
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

      sheet.navigator!.pop();
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetProvider), 'b2');
      expect(_inPane(find.text(_groceriesName)), findsOneWidget);
      expect(container.exists(budgetDetailContextProvider('b2')), isTrue);
      expect(container.exists(budgetLimitViewModelProvider('b2')), isTrue);
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
      expect(container.read(selectedBudgetProvider), 'b2');
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
      await tester.pumpWidget(_flowHost(container, showFlow: true));
      await tester.pumpAndSettle();
      await _tapBudget(tester, 'b2');
      expect(find.byType(BudgetDetailScreen), findsOneWidget);

      _rootNavigator(
        tester,
      ).push(MaterialPageRoute<void>(builder: (_) => const Text(_newerLabel)));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_flowHost(container, showFlow: false));
      await tester.pumpAndSettle();

      expect(find.byType(BudgetDetailScreen), findsNothing);
      expect(find.text(_newerLabel), findsOneWidget);
      expect(_hasDetailOwners(container, 'b2'), isFalse);
      expect(container.read(selectedBudgetProvider), 'b2');
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Back with a pane clears the selection and releases its owners', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
    await _tapBudget(tester, 'b2');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(container.read(selectedBudgetProvider), isNull);
    expect(find.byKey(shellDetailPaneKey), findsNothing);
    expect(_hasDetailOwners(container, 'b2'), isFalse);
  }, timeout: uiTestTimeout);

  testWidgets('Back pops open history before it clears the pane selection', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
    await _openHistoryFromPane(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(BudgetLimitScreen), findsNothing);
    expect(container.read(selectedBudgetProvider), 'b2');
    expect(find.byKey(shellDetailPaneKey), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('Back in an inactive Money segment leaves the selection alone', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
    await _tapBudget(tester, 'b2');
    _selectSegment(container, MoneySegment.accounts);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(container.read(selectedBudgetProvider), 'b2');
  }, timeout: uiTestTimeout);

  testWidgets(
    'selecting another budget while the page exits presents one page and keeps the new selection',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.phone);
      await _tapBudget(tester, 'b2');

      final outgoing = ModalRoute.of(
        tester.element(find.byType(BudgetDetailScreen)),
      );
      _rootNavigator(tester).pop();
      container.read(selectedBudgetProvider.notifier).select('b1');
      await tester.pumpAndSettle();

      expect(container.read(selectedBudgetProvider), 'b1');
      expect(find.byType(BudgetDetailScreen), findsOneWidget);
      expect(container.exists(budgetDetailViewModelProvider('b1')), isTrue);
      final incoming = ModalRoute.of(
        tester.element(find.byType(BudgetDetailScreen)),
      );
      expect(identical(incoming, outgoing), isFalse);
      expect(_hasDetailOwners(container, 'b2'), isFalse);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a detail Step arriving while Budgets is inactive waits and runs when Budgets returns',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');
      _selectSegment(container, MoneySegment.accounts);
      await tester.pumpAndSettle();

      container
          .read(budgetDetailViewModelProvider('b2').notifier)
          .requestLimitEdit();
      await tester.pumpAndSettle();
      expect(find.byType(BudgetLimitScreen), findsNothing);

      _selectSegment(container, MoneySegment.budgets);
      await tester.pumpAndSettle();
      expect(find.byType(BudgetLimitScreen), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('a month and year chosen before a conversion are kept after it', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
    await _tapBudget(tester, 'b2');
    final notifier = container.read(budgetDetailContextProvider('b2').notifier);
    notifier.selectMonth(DateTime.utc(2026, 1));
    notifier.changeYear(DateTime.utc(2025));
    await tester.pumpAndSettle();
    final before = container.read(budgetDetailContextProvider('b2'));

    container.read(_modeFixture.notifier).state = ShellLayoutMode.phone;
    await tester.pumpAndSettle();
    expect(container.read(budgetDetailContextProvider('b2')), before);
    container.read(_modeFixture.notifier).state = ShellLayoutMode.open;
    await tester.pumpAndSettle();
    expect(container.read(budgetDetailContextProvider('b2')), before);
    container.read(_modeFixture.notifier).state = ShellLayoutMode.desktop;
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(container.read(selectedBudgetProvider), 'b2');
    expect(container.read(budgetDetailContextProvider('b2')), before);
  }, timeout: uiTestTimeout);

  testWidgets(
    'a rapid open to phone to open reversal keeps exactly one pane and no page',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');

      container.read(_modeFixture.notifier).state = ShellLayoutMode.phone;
      await tester.pump();
      container.read(_modeFixture.notifier).state = ShellLayoutMode.open;
      await tester.pumpAndSettle();

      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
      expect(find.byType(BudgetDetailScreen), findsNothing);
      expect(container.read(selectedBudgetProvider), 'b2');
    },
    timeout: uiTestTimeout,
  );
  testWidgets('tray padding and All spending title keep the selection', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
    await _tapBudget(tester, 'b2');
    final selected = container.read(selectedBudgetProvider);
    final tray = find.byKey(const ValueKey('budget-tray-b2'));
    await tester.tapAt(tester.getTopLeft(tray) + _trayInteriorOffset);
    await tester.pumpAndSettle();
    expect(container.read(selectedBudgetProvider), selected);
    await tester.tap(find.text('All spending'));
    await tester.pumpAndSettle();
    expect(container.read(selectedBudgetProvider), 'b1');
  }, timeout: uiTestTimeout);

  testWidgets('empty list space keeps a phone or desktop selection', (
    tester,
  ) async {
    final container = _container(ledger: _ledger());
    final app = MaterialApp(home: Scaffold(body: const BudgetsRoot()));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: app),
    );
    await tester.pumpAndSettle();
    await _tapBudget(tester, 'b2');
    await tester.tap(find.text('Category budgets'));
    await tester.pumpAndSettle();
    expect(container.read(selectedBudgetProvider), 'b2');
    container.read(_modeFixture.notifier).state = ShellLayoutMode.desktop;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category budgets'));
    await tester.pumpAndSettle();
    expect(container.read(selectedBudgetProvider), 'b2');
  }, timeout: uiTestTimeout);

  testWidgets('an inactive limit Step is retained until Budgets returns', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
    await _tapBudget(tester, 'b2');
    _selectSegment(container, MoneySegment.accounts);
    await tester.pumpAndSettle();
    final viewModel = container.read(
      budgetLimitViewModelProvider('b2').notifier,
    );
    viewModel.requestEditDefault();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, _saveLabel), findsNothing);
    expect(
      container.read(budgetLimitViewModelProvider('b2')).requireValue.step,
      isA<PickLimitRequested>(),
    );
    _selectSegment(container, MoneySegment.budgets);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, _saveLabel), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets(
    'a delayed editor result after selection replacement cannot mutate',
    (tester) async {
      final ledger = _ledger();
      final container = await _pumpShell(
        tester,
        mode: ShellLayoutMode.open,
        ledger: ledger,
      );
      await _openHistoryFromPane(tester);
      await tester.tap(find.text(_defaultBudgetRowLabel));
      await tester.pumpAndSettle();
      container.read(selectedBudgetProvider.notifier).select('b1');
      await tester.pump();
      _rootNavigator(tester).pop(Decimal.fromInt(75));
      await tester.pumpAndSettle();
      expect(ledger.state.budgets['b2']!.limitEvents, hasLength(1));
      expect(ledger.state.budgets['b1']!.limitEvents, hasLength(1));
      expect(container.read(selectedBudgetProvider), 'b1');
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a delayed editor result after ledger replacement cannot mutate either ledger',
    (tester) async {
      final oldLedger = _ledger();
      final container = await _pumpShell(
        tester,
        mode: ShellLayoutMode.open,
        ledger: oldLedger,
      );
      await _openHistoryFromPane(tester);
      await tester.tap(find.text(_defaultBudgetRowLabel));
      await tester.pumpAndSettle();
      final replacement = _ledger();
      container.read(_ledgerFixture.notifier).state = replacement;
      _rootNavigator(tester).pop(Decimal.fromInt(75));
      await tester.pumpAndSettle();
      expect(oldLedger.state.budgets['b2']!.limitEvents, hasLength(1));
      expect(replacement.state.budgets['b2']!.limitEvents, hasLength(1));
      expect(container.read(selectedBudgetProvider), isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('reopening after terminal closure uses the new Money month', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
    await _tapBudget(tester, 'b2');
    await tester.tap(find.text('Category budgets'));
    await tester.pumpAndSettle();
    expect(_hasDetailOwners(container, 'b2'), isFalse);
    container.read(selectedMonthProvider.notifier).state = DateTime.utc(
      2027,
      2,
    );
    await tester.pumpAndSettle();
    await _tapBudget(tester, 'b2');
    final context = container.read(budgetDetailContextProvider('b2'));
    expect(context.selectedMonth, DateTime.utc(2027, 2));
    expect(context.displayedYear, DateTime.utc(2027));
  }, timeout: uiTestTimeout);
  testWidgets('Add budget preserves the pane selection', (tester) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
    await _tapBudget(tester, 'b2');
    await tester.tap(find.text('Add budget'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetForm), findsOneWidget);
    expect(container.read(selectedBudgetProvider), 'b2');
  }, timeout: uiTestTimeout);
  testWidgets('the pane header shows the selected budget category', (
    tester,
  ) async {
    await _pumpShell(tester, mode: ShellLayoutMode.open);
    await _tapBudget(tester, 'b2');

    expect(find.text('Food'), findsWidgets);
    expect(find.byKey(shellDetailPaneKey), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('a phone tap selects the budget and pushes exactly one page', (
    tester,
  ) async {
    final container = await _pumpShell(tester, mode: ShellLayoutMode.phone);
    await _tapBudget(tester, 'b2');

    expect(container.read(selectedBudgetProvider), 'b2');
    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(find.byKey(shellDetailPaneKey), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets(
    'folding pushes the page for the selected budget and unfolding removes it',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.open);
      await _tapBudget(tester, 'b2');

      container.read(_modeFixture.notifier).state = ShellLayoutMode.phone;
      await tester.pumpAndSettle();
      expect(find.byType(BudgetDetailScreen), findsOneWidget);
      expect(find.byKey(shellDetailPaneKey), findsNothing);
      expect(container.read(selectedBudgetProvider), 'b2');

      container.read(_modeFixture.notifier).state = ShellLayoutMode.open;
      await tester.pumpAndSettle();
      expect(find.byType(BudgetDetailScreen), findsNothing);
      expect(find.byKey(shellDetailPaneKey), findsOneWidget);
      expect(container.read(selectedBudgetProvider), 'b2');
      expect(container.exists(budgetDetailViewModelProvider('b2')), isTrue);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'replacing the ledger removes the phone page and clears the selection',
    (tester) async {
      final container = await _pumpShell(tester, mode: ShellLayoutMode.phone);
      await _tapBudget(tester, 'b2');

      container.read(_ledgerFixture.notifier).state = _ledger();
      await tester.pumpAndSettle();

      expect(find.byType(BudgetDetailScreen), findsNothing);
      expect(container.read(selectedBudgetProvider), isNull);
      expect(_hasDetailOwners(container, 'b2'), isFalse);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a ledger notification while editing cannot start a second limit operation',
    (tester) async {
      final ledger = _ledger();
      await _pumpShell(tester, mode: ShellLayoutMode.open, ledger: ledger);
      await _openHistoryFromPane(tester);
      await tester.tap(find.text(_defaultBudgetRowLabel));
      await tester.pumpAndSettle();
      ledger.addEntry(_entry(0));
      await tester.pumpAndSettle();
      _rootNavigator(tester).pop(Decimal.fromInt(75));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, _saveLabel), findsNothing);
      final events = ledger.state.budgets['b2']!.limitEvents;
      expect(events, hasLength(2));
      expect(events.last.value, Decimal.fromInt(75));
      expect(find.byType(BudgetLimitScreen), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );
}
