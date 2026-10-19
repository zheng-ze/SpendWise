import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_host.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';

import '../../../support/ui_test_timeout.dart';

void main() {
  final overall = Budget(
    id: 'b1',
    categoryID: null,
    limitEvents: [
      LimitEvent(
        effectiveFromMonth: null,
        value: Decimal.parse('100'),
        kind: LimitEventKind.defaultLimit,
      ),
    ],
    createdAtMonth: const YearMonth(2026, 1),
  );
  final money = budgetsListViewModelProvider(BudgetHost.money);
  final stats = budgetsListViewModelProvider(BudgetHost.stats);

  late ProviderContainer container;

  Widget hosts({bool showMoney = true, bool moneyActive = true}) => MaterialApp(
    home: Row(
      children: [
        if (showMoney)
          Expanded(
            child: HeroMode(
              enabled: false,
              child: DestinationActivity(
                active: moneyActive,
                child: const BudgetsFlow(host: BudgetHost.money),
              ),
            ),
          ),
        const Expanded(child: BudgetsFlow(host: BudgetHost.stats)),
      ],
    ),
  );

  Future<void> pumpApp(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: app),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpHosts(WidgetTester tester, Widget app) async {
    container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(
          Ledger(state: LedgerState(budgets: {overall.id: overall})),
        ),
        analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
      ],
    );
    addTearDown(container.dispose);
    await pumpApp(tester, app);
  }

  bool detailAlive(BudgetHost host) => container.exists(
    budgetDetailViewModelProvider((host: host, budgetID: overall.id)),
  );

  testWidgets('a detail request on one host opens only that host\'s detail', (
    tester,
  ) async {
    await pumpHosts(tester, hosts());

    container.read(money.notifier).requestBudgetDetail(overall.id);
    await tester.pumpAndSettle();

    final screen = tester.widget<BudgetDetailScreen>(
      find.byType(BudgetDetailScreen),
    );
    expect(screen.hostedBudget.host, BudgetHost.money);
    expect(detailAlive(BudgetHost.stats), isFalse);
    expect(container.read(stats).value?.step, isNull);
  }, timeout: uiTestTimeout);

  testWidgets('a hidden host leaves its Step pending until it becomes active', (
    tester,
  ) async {
    await pumpHosts(tester, hosts(moneyActive: false));

    container.read(money.notifier).requestBudgetDetail(overall.id);
    await tester.pumpAndSettle();

    expect(find.byType(BudgetDetailScreen), findsNothing);
    expect(container.read(money).value?.step, isNotNull);

    await pumpApp(tester, hosts());

    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(container.read(money).value?.step, isNull);
  }, timeout: uiTestTimeout);

  testWidgets('disposing one host leaves the other host working', (
    tester,
  ) async {
    await pumpHosts(tester, hosts());

    await pumpApp(tester, hosts(showMoney: false));
    container.read(stats.notifier).requestBudgetDetail(overall.id);
    await tester.pumpAndSettle();

    expect(find.byType(BudgetDetailScreen), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('each budget form draft is a fresh identity disposed with its '
      'route', (tester) async {
    await pumpHosts(tester, hosts());

    BudgetDraftKey openDraft() =>
        tester.widget<BudgetForm>(find.byType(BudgetForm)).draftKey;

    container.read(money.notifier).requestNewBudget();
    await tester.pumpAndSettle();
    final first = openDraft();
    expect(container.exists(budgetFormViewModelProvider(first)), isTrue);

    Navigator.of(tester.element(find.byType(BudgetForm))).pop();
    await tester.pumpAndSettle();
    expect(container.exists(budgetFormViewModelProvider(first)), isFalse);

    container.read(stats.notifier).requestNewBudget();
    await tester.pumpAndSettle();
    expect(openDraft(), isNot(same(first)));
  }, timeout: uiTestTimeout);
}
