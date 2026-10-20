import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/account_form/account_form.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/common/inputs/month_year_selector.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/settings/plan/plan_list_screen.dart';
import 'package:spendwise/ui/settings/plan/plan_list_view_model.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/stats_flow.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../support/ui_test_timeout.dart';
import '../../support/add_sheet_dismiss.dart';

const _phoneSize = Size(480, 844);
const _geometryPhoneSize = Size(402, 874);
const _pixelRatio = 1.0;
const _openSize = Size(960, 844);
final _today = DateTime.utc(2026, 10, 3);

Ledger _seedLedger() {
  final state = LedgerState()..apply(seedChanges(today: _today));
  return Ledger(state: state);
}

class _MoneyShell extends ConsumerWidget {
  const _MoneyShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bodies = <ShellDestination, WidgetBuilder>{
      ShellDestination.money: (_) =>
          MoneyFlow(moneyObserver: ref.read(moneyNavigatorObserverProvider)),
      ShellDestination.trends: (_) => const StatsFlow(),
      ShellDestination.settings: (_) => const SettingsFlow(),
    };
    return HeroMode(
      enabled: false,
      child: AppShell(
        bodies: bodies,
        moneySourceId: ref.read(activeMoneySourceProvider),
      ),
    );
  }
}

Future<ProviderContainer> _pumpMoney(
  WidgetTester tester,
  Ledger ledger, {
  Size size = _phoneSize,
}) async {
  tester.view.devicePixelRatio = _pixelRatio;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(ledger),
      shellPlatformProvider.overrideWithValue((
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      )),
      clockProvider.overrideWithValue(() => _today),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
    ],
  );
  addTearDown(container.dispose);
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.money;
  final app = MaterialApp(
    theme: buildSpendWiseTheme(Brightness.light),
    builder: buildShellAppContent,
    home: const _MoneyShell(),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _segment(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _addSource(
  WidgetTester tester,
  ProviderContainer container,
  String? expected,
) async {
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
  expect(
    container.read(entryFormViewModelProvider(null)).value?.sourceId,
    expected,
  );
  await dismissAddSheet(tester);
  await tester.pumpAndSettle();
}

Future<void> _selectRetained(
  WidgetTester tester,
  ProviderContainer container,
  MoneySegment segment,
) async {
  container.read(moneySegmentProvider.notifier).state = segment;
  await tester.pumpAndSettle();
}

Future<void> _destination(
  WidgetTester tester,
  ProviderContainer container,
  ShellDestination destination,
) async {
  container.read(selectedDestinationProvider.notifier).state = destination;
  await tester.pumpAndSettle();
}

void _expectRoot({required bool month}) {
  final flow = find.byType(MoneyFlow);
  expect(
    find.descendant(of: flow, matching: find.text('Money')),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: flow,
      matching: find.byType(SegmentedControl<MoneySegment>),
    ),
    findsOneWidget,
  );
  expect(find.byType(MonthYearSelector), month ? findsOneWidget : findsNothing);
}

Ledger _geometryLedger() {
  final account = Account(name: 'Wallet', type: AccountType.cash);
  final plan = RecurringPlan(
    template: EntryTemplate(
      amount: Decimal.parse('-10'),
      name: 'Rent',
      sourceID: account.id,
    ),
    frequency: RecurrenceFrequency.monthly,
    anchor: _today,
    lastResolvedDate: _today,
  );
  final state = LedgerState(
    moneySources: {account.id: MoneySource.account(account)},
    plans: {plan.id: plan},
  );
  return Ledger(state: state);
}

double _segmentTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(SegmentedControl<MoneySegment>)).dy;

Future<double> _rootGeometry(WidgetTester tester, Ledger ledger) async {
  await _pumpMoney(tester, ledger, size: _geometryPhoneSize);
  final top = _segmentTop(tester);
  await _segment(tester, 'Accounts');
  expect(_segmentTop(tester), top);
  await _segment(tester, 'Plans');
  expect(_segmentTop(tester), top);
  return top;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Money header keeps its segment top at 402 points with empty Plans',
    (tester) async {
      await _rootGeometry(tester, Ledger());
      expect(find.text('Edit'), findsNothing);
      expect(find.text('No recurring plans yet'), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Money header keeps its segment top at 402 points through Plans Edit and Done',
    (tester) async {
      final top = await _rootGeometry(tester, _geometryLedger());
      await _segment(tester, 'Edit');
      expect(_segmentTop(tester), top);
      await _segment(tester, 'Done');
      expect(_segmentTop(tester), top);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Money roots share chrome and lazily retain existing children', (
    tester,
  ) async {
    await _pumpMoney(tester, _seedLedger());
    expect(find.byType(BudgetsFlow), findsOneWidget);
    expect(find.byType(AccountsFlow, skipOffstage: false), findsNothing);
    expect(find.byType(PlanListScreen, skipOffstage: false), findsNothing);
    final control = tester.widget<SegmentedControl<MoneySegment>>(
      find.byType(SegmentedControl<MoneySegment>),
    );
    expect(control.options.map((option) => option.label), [
      'Budgets',
      'Accounts',
      'Plans',
    ]);
    _expectRoot(month: true);
    await _segment(tester, 'Accounts');
    final accountsState = tester.state(find.byType(AccountsFlow));
    expect(find.text('Accounts'), findsOneWidget);
    _expectRoot(month: false);
    await tester.tap(find.byTooltip('Add account'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountForm), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _segment(tester, 'Plans');
    expect(find.text('Recurring Plans'), findsNothing);
    _expectRoot(month: false);
    expect(
      find.descendant(
        of: find.byType(MoneyFlow),
        matching: find.byIcon(Icons.add),
      ),
      findsNothing,
    );
    expect(find.text('Add plan'), findsNothing);
    final plansState = tester.state(find.byType(PlanListScreen));
    await _segment(tester, 'Edit');
    expect(find.text('Done'), findsOneWidget);
    await _segment(tester, 'Done');
    await _segment(tester, 'Accounts');
    expect(tester.state(find.byType(AccountsFlow)), same(accountsState));
    await _segment(tester, 'Plans');
    expect(tester.state(find.byType(PlanListScreen)), same(plansState));
  }, timeout: uiTestTimeout);

  testWidgets(
    'Money Plans Edit delete preserves existing confirmation contract',
    (tester) async {
      final ledger = _seedLedger();
      final container = await _pumpMoney(tester, ledger);
      await _segment(tester, 'Plans');
      final plan = ledger.state.plans.values.first;
      await _segment(tester, 'Edit');
      final row = find.widgetWithText(ListTile, plan.template.name);
      await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.remove_circle)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete ${plan.template.name}?'), findsOneWidget);
      await _segment(tester, 'Delete');
      expect(ledger.state.plans.containsKey(plan.id), isFalse);
      expect(
        find.text('Delete ${plan.template.name}?', skipOffstage: false),
        findsNothing,
      );
      expect(container.read(planListViewModelProvider).value?.step, isNull);
      await _segment(tester, 'Accounts');
      expect(container.read(moneySegmentProvider), MoneySegment.accounts);
      await _segment(tester, 'Plans');
      expect(
        find.text('Delete ${plan.template.name}?', skipOffstage: false),
        findsNothing,
      );
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Accounts scoped source and navigator survive segment destination and size changes',
    (tester) async {
      final ledger = _seedLedger();
      final container = await _pumpMoney(tester, ledger);
      final observer = container.read(moneyNavigatorObserverProvider);
      await _segment(tester, 'Accounts');
      final accounts = tester.state(find.byType(AccountsFlow));
      final state = container.read(accountsViewModelProvider).value!;
      final account = state.sections
          .expand((section) => section.rows)
          .firstWhere((row) => row.pockets.isNotEmpty);
      container
          .read(accountsViewModelProvider.notifier)
          .openAccount(account.id);
      await tester.pumpAndSettle();
      final scoped = tester.state(find.byType(TransactionsFlow));
      expect(observer.sourceId, account.id);
      await _addSource(tester, container, account.id);
      await _selectRetained(tester, container, MoneySegment.budgets);
      expect(container.read(activeMoneySourceProvider)(), isNull);
      await _addSource(tester, container, null);
      await _selectRetained(tester, container, MoneySegment.plans);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(observer.sourceId, account.id);
      await _addSource(tester, container, null);
      await _destination(tester, container, ShellDestination.settings);
      expect(find.text('Recurring Plans'), findsNothing);
      expect(container.read(activeMoneySourceProvider)(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(observer.sourceId, account.id);
      await _destination(tester, container, ShellDestination.money);
      await _selectRetained(tester, container, MoneySegment.accounts);
      tester.view.physicalSize = _openSize;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(AccountsFlow)), same(accounts));
      expect(tester.state(find.byType(TransactionsFlow)), same(scoped));
      expect(container.read(moneyNavigatorObserverProvider), same(observer));
      expect(container.read(activeMoneySourceProvider)(), account.id);
      await _addSource(tester, container, account.id);
      tester.view.physicalSize = _phoneSize;
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedControl<MoneySegment>), findsOneWidget);
      expect(observer.sourceId, isNull);
      container
          .read(accountsViewModelProvider.notifier)
          .openPocket(account.pockets.first.id);
      await tester.pumpAndSettle();
      await _addSource(tester, container, account.pockets.first.id);
      await _destination(tester, container, ShellDestination.history);
      await _addSource(tester, container, null);
      await _destination(tester, container, ShellDestination.trends);
      await _addSource(tester, container, null);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Money keeps Budgets access and selected month across Trends', (
    tester,
  ) async {
    final ledger = _seedLedger();
    ledger.addBudget(null, Decimal.parse('1200'), now: _today);
    final container = await _pumpMoney(tester, ledger);
    final money = tester.state(find.byType(BudgetsFlow));
    expect(find.text('Overall'), findsOneWidget);
    await tester.tap(find.text('Overall'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(container.read(effectiveMonthProvider), DateTime.utc(2026, 9));
    await _destination(tester, container, ShellDestination.trends);
    expect(container.read(effectiveMonthProvider), DateTime.utc(2026, 9));
    await _destination(tester, container, ShellDestination.money);
    expect(tester.state(find.byType(BudgetsFlow)), same(money));
    expect(container.read(effectiveMonthProvider), DateTime.utc(2026, 9));
  }, timeout: uiTestTimeout);
}
