import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';

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

  Budget budget({
    String? categoryID,
    required String id,
    String amount = '100',
  }) {
    return Budget(
      id: id,
      categoryID: categoryID,
      limitEvents: [
        LimitEvent(
          effectiveFromMonth: null,
          value: dec(amount),
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
        analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
        todayProvider.overrideWithValue(DateTime.utc(2026, 3, 3)),
        selectedMonthProvider.overrideWith((ref) => DateTime.utc(2026, 3)),
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
      container.read(budgetsListViewModelProvider).value?.overview?.hasBudgets,
      isTrue,
    );

    viewModel.deleteBudget(overall.id);
    await container
        .read(ledgerSessionProvider)!
        .analysisCache
        .refresh(ledger.state, sourceRevision: ledger.revision);
    await container.pump();

    expect(ledger.state.budgets.containsKey(overall.id), isFalse);
    expect(
      container.read(budgetsListViewModelProvider).value?.overview?.hasBudgets,
      isFalse,
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
    'overview ranks utilization and excludes child limits from cap',
    () async {
      final parent = budget(categoryID: food.id, id: 'b1');
      final child = budget(categoryID: hawker.id, id: 'b2', amount: '50');
      final entry = Entry(
        amount: dec('-80'),
        name: 'Lunch',
        sourceID: account.id,
        categoryID: hawker.id,
        date: DateTime.utc(2026, 3, 1),
      );
      final state = LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food, hawker.id: hawker},
        budgets: {child.id: child, parent.id: parent},
        entries: {entry.id: entry},
      );
      final ledger = Ledger(state: state);
      final container = buildContainer(ledger);
      await container
          .read(ledgerSessionProvider)!
          .analysisCache
          .refresh(ledger.state, sourceRevision: ledger.revision);
      final result = await container.read(budgetsListViewModelProvider.future);
      expect(result.overview!.allSpending.cap, dec('100'));
      expect(result.overview!.allSpending.spent, dec('80'));
      expect(result.overview!.categoryBudgets.map((row) => row.budgetID), [
        'b2',
        'b1',
      ]);
      expect(result.overview!.allSpending.dailyAllowance, isNotNull);
      expect(result.cards.first.overLimit, isTrue);
      expect(result.cards.first.progress, 1.6);
      expect(result.summary.allowance, 'From 4 March: about S\$0.71 a day.');
      container.read(selectedMonthProvider.notifier).state = DateTime.utc(
        2026,
        4,
      );
      await container.pump();
      final april = container.read(budgetsListViewModelProvider).requireValue;
      expect(april.overview!.allSpending.spent, Decimal.zero);
      expect(april.summary.allowance, isNull);
    },
  );

  test('initial query stays loading until computation completes', () async {
    final pending = Completer<List<AnalysisItem>>();
    final ledger = buildLedger();
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisComputeRunnerProvider.overrideWithValue((_) => pending.future),
      ],
    );
    addTearDown(container.dispose);
    final initial = await container.read(budgetsListViewModelProvider.future);
    expect(initial.loading, isTrue);
    expect(initial.overview, isNull);
    pending.complete([]);
    await container
        .read(ledgerSessionProvider)!
        .analysisCache
        .refresh(ledger.state, sourceRevision: ledger.revision);
    await container.pump();
    final ready = container.read(budgetsListViewModelProvider).requireValue;
    expect(ready.loading, isFalse);
    expect(ready.overview!.hasBudgets, isFalse);
  });

  test('refresh failure retains coherent amounts and retry recovers', () async {
    var fail = false;
    final reason = StateError('Data unavailable');
    final overall = budget(id: 'b1');
    final ledger = buildLedger(budgets: {overall.id: overall});
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisComputeRunnerProvider.overrideWithValue((state) async {
          if (fail) throw reason;
          return syncComputeRunner(state);
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      budgetsListViewModelProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final cache = container.read(ledgerSessionProvider)!.analysisCache;
    await cache.refresh(ledger.state, sourceRevision: ledger.revision);
    await container.pump();
    expect(
      container
          .read(budgetsListViewModelProvider)
          .requireValue
          .overview!
          .allSpending
          .cap,
      dec('100'),
    );
    fail = true;
    ledger.updateBudgetAmount(overall.id, dec('200'), const YearMonth(2026, 1));
    await cache.refresh(ledger.state, sourceRevision: ledger.revision);
    await container.pump();
    final failed = container.read(budgetsListViewModelProvider).requireValue;
    expect(failed.error, same(reason));
    expect(failed.overview!.allSpending.cap, dec('100'));
    fail = false;
    container.read(budgetsListViewModelProvider.notifier).retry();
    await cache.refresh(ledger.state, sourceRevision: ledger.revision);
    await container.pump();
    final recovered = container.read(budgetsListViewModelProvider).requireValue;
    expect(recovered.error, isNull);
    expect(recovered.overview!.allSpending.cap, dec('200'));
  });
  test('malformed limits expose their actual projection failure', () async {
    final invalid = budget(id: 'b1', amount: '0');
    final ledger = buildLedger(budgets: {invalid.id: invalid});
    final container = buildContainer(ledger);
    await container
        .read(ledgerSessionProvider)!
        .analysisCache
        .refresh(ledger.state, sourceRevision: ledger.revision);
    final state = await container.read(budgetsListViewModelProvider.future);
    expect(state.overview, isNull);
    expect(state.error, isA<StateError>());
    expect(state.error.toString(), contains('nonpositive limit'));
  });
}
