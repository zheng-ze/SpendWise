import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_form.dart';
import 'package:spendwise/ui/stats/category_detail_screen.dart';
import 'package:spendwise/ui/stats/stats_flow.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';

import '../../support/semantics_test_support.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );

  final food = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000001',
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#00AA00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );

  Budget budget({String? categoryID, required String id}) {
    return Budget(
      id: id,
      categoryID: categoryID,
      limitEvents: [
        LimitEvent(
          effectiveFromMonth: null,
          value: dec('100'),
          kind: LimitEventKind.defaultLimit,
        ),
      ],
      createdAtMonth: const YearMonth(2026, 1),
    );
  }

  Ledger buildLedger({Map<String, Budget> budgets = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food},
        budgets: budgets,
      ),
    );
  }

  Future<ProviderContainer> pumpFlow(WidgetTester tester, Ledger ledger) async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisCacheProvider.overrideWith(
          (ref) => AnalysisCache(runner: syncComputeRunner),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StatsFlow()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('CategoryDetailRequested pushes CategoryDetailScreen for that '
      'category', (tester) async {
    final container = await pumpFlow(tester, buildLedger());

    container
        .read(statsRootViewModelProvider.notifier)
        .requestCategoryDetail(
          kind: CategoryKind.expense,
          mainID: food.id,
          isYearRange: false,
          initialDate: DateTime.utc(2026, 3),
        );
    await tester.pumpAndSettle();

    expect(find.byType(CategoryDetailScreen), findsOneWidget);
    // Step is cleared once the Flow has acted on it, so a later rebuild
    // does not push a second time.
    expect(container.read(statsRootViewModelProvider).value?.step, isNull);
  });

  testWidgets('BudgetDetailRequested pushes BudgetDetailScreen for that '
      'budget', (tester) async {
    final overall = budget(categoryID: null, id: 'b1');
    final container = await pumpFlow(
      tester,
      buildLedger(budgets: {overall.id: overall}),
    );

    container
        .read(statsRootViewModelProvider.notifier)
        .requestBudgetDetail(overall.id);
    await tester.pumpAndSettle();

    final pushed = tester.widget<BudgetDetailScreen>(
      find.byType(BudgetDetailScreen),
    );
    expect(pushed.budgetID, overall.id);
  });

  testWidgets('BudgetFormRequested opens the budget form sheet', (
    tester,
  ) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(statsRootViewModelProvider.notifier).requestNewBudget();
    await tester.pumpAndSettle();

    expect(find.byType(BudgetForm), findsOneWidget);
  });

  testWidgets('back navigation while a pushed screen is open pops that '
      "screen, not the Flow's own root", (tester) async {
    final overall = budget(categoryID: null, id: 'b1');
    final container = await pumpFlow(
      tester,
      buildLedger(budgets: {overall.id: overall}),
    );

    container
        .read(statsRootViewModelProvider.notifier)
        .requestBudgetDetail(overall.id);
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsOneWidget);

    // Simulate the system back gesture: the outer PopScope has canPop:
    // false, so this must resolve inside StatsFlow's own Navigator rather
    // than escaping the Flow.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(BudgetDetailScreen), findsNothing);
    expect(find.byType(StatsFlow), findsOneWidget);
  });

  testWidgets('swiping a budget row asks for confirmation, then deletes '
      'without altering entries', (tester) async {
    final overall = budget(categoryID: null, id: 'b1');
    final entry = Entry(
      amount: dec('-7'),
      name: 'Misc',
      sourceID: account.id,
      date: DateTime.utc(2026, 3, 1),
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food},
        budgets: {overall.id: overall},
        entries: {entry.id: entry},
      ),
    );

    final container = await pumpFlow(tester, ledger);
    container
        .read(statsRootViewModelProvider.notifier)
        .setTab(StatsTab.budgets);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Overall'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(ledger.state.budgets.containsKey(overall.id), isFalse);
    expect(ledger.state.entries.containsKey(entry.id), isTrue);
  });

  testWidgets('the delete custom semantic action on a budget row opens the '
      'same confirm dialog as the swipe', (tester) async {
    final handle = tester.ensureSemantics();
    final overall = budget(categoryID: null, id: 'b1');
    final ledger = buildLedger(budgets: {overall.id: overall});

    final container = await pumpFlow(tester, ledger);
    container
        .read(statsRootViewModelProvider.notifier)
        .setTab(StatsTab.budgets);
    await tester.pumpAndSettle();

    await performCustomSemanticsAction(
      tester,
      of: find.text('Overall'),
      label: 'Delete Overall',
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Overall?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(ledger.state.budgets.containsKey(overall.id), isFalse);
    handle.dispose();
  });
}
