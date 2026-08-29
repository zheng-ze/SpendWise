import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_screen.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';

import '../../../support/semantics_test_support.dart';

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
        child: const MaterialApp(home: BudgetsFlow()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('BudgetDetailRequested pushes BudgetDetailScreen for that '
      'budget', (tester) async {
    final overall = budget(categoryID: null, id: 'b1');
    final container = await pumpFlow(
      tester,
      buildLedger(budgets: {overall.id: overall}),
    );

    container
        .read(budgetsListViewModelProvider.notifier)
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

    container.read(budgetsListViewModelProvider.notifier).requestNewBudget();
    await tester.pumpAndSettle();

    expect(find.byType(BudgetForm), findsOneWidget);
  });

  testWidgets('BudgetLimitEditRequested from an open detail screen pushes '
      'BudgetLimitScreen', (tester) async {
    final overall = budget(categoryID: null, id: 'b1');
    final container = await pumpFlow(
      tester,
      buildLedger(budgets: {overall.id: overall}),
    );

    container
        .read(budgetsListViewModelProvider.notifier)
        .requestBudgetDetail(overall.id);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    final pushed = tester.widget<BudgetLimitScreen>(
      find.byType(BudgetLimitScreen),
    );
    expect(pushed.budgetID, overall.id);
  });

  testWidgets('PickLimitRequested opens the limit-edit sheet and applies the '
      'picked amount', (tester) async {
    final overall = budget(categoryID: null, id: 'b1');
    final ledger = buildLedger(budgets: {overall.id: overall});
    final container = await pumpFlow(tester, ledger);

    container
        .read(budgetsListViewModelProvider.notifier)
        .requestBudgetDetail(overall.id);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Default Budget'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '200.00');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final now = DateTime.now().toUtc();
    final currentMonth = YearMonth(now.year, now.month);
    expect(
      effectiveLimit(ledger.state.budgets[overall.id]!, currentMonth),
      dec('100'),
    );
    expect(find.text(r'$200.00'), findsWidgets);
  });

  testWidgets('PickCategoryRequested opens the category picker and applies '
      'the pick', (tester) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(budgetsListViewModelProvider.notifier).requestNewBudget();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets('back navigation while a pushed screen is open pops that '
      "screen, not the Flow's own root", (tester) async {
    final overall = budget(categoryID: null, id: 'b1');
    final container = await pumpFlow(
      tester,
      buildLedger(budgets: {overall.id: overall}),
    );

    container
        .read(budgetsListViewModelProvider.notifier)
        .requestBudgetDetail(overall.id);
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsOneWidget);

    // Simulates the system back gesture, which BudgetsFlow's own Navigator
    // must consume instead of the outer PopScope (canPop: false).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(BudgetDetailScreen), findsNothing);
    expect(find.byType(BudgetsFlow), findsOneWidget);
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

    await pumpFlow(tester, ledger);

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

    await pumpFlow(tester, ledger);

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
