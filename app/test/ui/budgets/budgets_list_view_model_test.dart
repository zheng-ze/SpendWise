import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budgets_list_view_model.dart';

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

  final hawker = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000002',
    name: 'Hawker',
    kind: CategoryKind.expense,
    colorHex: '#00BB00',
    includeInAnalysis: true,
    parentID: food.id,
    symbol: 'set_meal',
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
        categories: {food.id: food, hawker.id: hawker},
        budgets: budgets,
      ),
    );
  }

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisCacheProvider.overrideWith(
          (ref) => AnalysisCache(runner: syncComputeRunner),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'requestBudgetDetail emits BudgetDetailRequested carrying the budget id',
    () async {
      final container = buildContainer(buildLedger());
      await container.read(budgetsListViewModelProvider.future);
      final viewModel = container.read(budgetsListViewModelProvider.notifier);

      viewModel.requestBudgetDetail('b1');

      final step = container.read(budgetsListViewModelProvider).value?.step;
      expect(step, isA<BudgetDetailRequested>());
      expect((step as BudgetDetailRequested).budgetID, 'b1');
    },
  );

  test('requestNewBudget emits BudgetFormRequested', () async {
    final container = buildContainer(buildLedger());
    await container.read(budgetsListViewModelProvider.future);
    final viewModel = container.read(budgetsListViewModelProvider.notifier);

    viewModel.requestNewBudget();

    expect(
      container.read(budgetsListViewModelProvider).value?.step,
      isA<BudgetFormRequested>(),
    );
  });

  test('clearStep resets the step to null', () async {
    final container = buildContainer(buildLedger());
    await container.read(budgetsListViewModelProvider.future);
    final viewModel = container.read(budgetsListViewModelProvider.notifier);

    viewModel.requestNewBudget();
    expect(container.read(budgetsListViewModelProvider).value?.step, isNotNull);

    viewModel.clearStep();
    expect(container.read(budgetsListViewModelProvider).value?.step, isNull);
  });

  test('deleteBudget removes the budget from the ledger', () async {
    final overall = budget(categoryID: null, id: 'b1');
    final ledger = buildLedger(budgets: {overall.id: overall});
    final container = buildContainer(ledger);
    await container.read(budgetsListViewModelProvider.future);
    final viewModel = container.read(budgetsListViewModelProvider.notifier);
    expect(
      container.read(budgetsListViewModelProvider).value?.budgets,
      hasLength(1),
    );

    viewModel.deleteBudget(overall.id);

    expect(ledger.state.budgets.containsKey(overall.id), isFalse);
    expect(
      container.read(budgetsListViewModelProvider).value?.budgets,
      isEmpty,
    );
  });

  test('deleteBudget leaves entries untouched', () async {
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
        categories: {food.id: food, hawker.id: hawker},
        budgets: {overall.id: overall},
        entries: {entry.id: entry},
      ),
    );
    final container = buildContainer(ledger);
    await container.read(budgetsListViewModelProvider.future);
    final viewModel = container.read(budgetsListViewModelProvider.notifier);

    viewModel.deleteBudget(overall.id);

    expect(ledger.state.entries.containsKey(entry.id), isTrue);
  });

  test(
    'sortedBudgets groups a subcategory budget next to its parent',
    () async {
      final parentBudget = budget(categoryID: food.id, id: 'b1');
      final childBudget = budget(categoryID: hawker.id, id: 'b2');
      final ledger = buildLedger(
        budgets: {parentBudget.id: parentBudget, childBudget.id: childBudget},
      );
      final container = buildContainer(ledger);

      final state = await container.read(budgetsListViewModelProvider.future);

      expect(state.budgets.map((b) => b.id), [parentBudget.id, childBudget.id]);
      expect(state.isSubcategoryBudget(parentBudget), isFalse);
      expect(state.isSubcategoryBudget(childBudget), isTrue);
    },
  );
}
