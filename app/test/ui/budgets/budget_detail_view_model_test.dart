import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail_view_model.dart';

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

  Ledger buildLedger(Budget forBudget) {
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food},
        budgets: {forBudget.id: forBudget},
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

  test('build shows the current year and month by default', () async {
    final overall = budget(categoryID: null, id: 'b1');
    final container = buildContainer(buildLedger(overall));
    final now = DateTime.now().toUtc();

    final state = await container.read(
      budgetDetailViewModelProvider(overall.id).future,
    );

    expect(state.displayedYear, DateTime.utc(now.year));
    expect(state.selectedMonth, DateTime.utc(now.year, now.month));
    expect(state.budget?.id, overall.id);
  });

  test('title falls back to Overall for a budget with no category', () async {
    final overall = budget(categoryID: null, id: 'b1');
    final container = buildContainer(buildLedger(overall));

    final state = await container.read(
      budgetDetailViewModelProvider(overall.id).future,
    );

    expect(state.title, 'Overall');
  });

  test('title uses the category name for a category budget', () async {
    final categoryBudget = budget(categoryID: food.id, id: 'b2');
    final container = buildContainer(buildLedger(categoryBudget));

    final state = await container.read(
      budgetDetailViewModelProvider(categoryBudget.id).future,
    );

    expect(state.title, 'Food');
  });

  test(
    'selectMonth updates the selected month, keeping the same year',
    () async {
      final overall = budget(categoryID: null, id: 'b1');
      final container = buildContainer(buildLedger(overall));
      await container.read(budgetDetailViewModelProvider(overall.id).future);
      final viewModel = container.read(
        budgetDetailViewModelProvider(overall.id).notifier,
      );
      final now = DateTime.now().toUtc();
      final targetMonth = now.month == 1 ? 12 : 1;

      viewModel.selectMonth(DateTime.utc(now.year, targetMonth));

      final state = container
          .read(budgetDetailViewModelProvider(overall.id))
          .value;
      expect(state?.selectedMonth, DateTime.utc(now.year, targetMonth));
      expect(state?.displayedYear, DateTime.utc(now.year));
    },
  );

  test('changeYear keeps the selected month fixed', () async {
    final overall = budget(categoryID: null, id: 'b1');
    final container = buildContainer(buildLedger(overall));
    await container.read(budgetDetailViewModelProvider(overall.id).future);
    final viewModel = container.read(
      budgetDetailViewModelProvider(overall.id).notifier,
    );
    final now = DateTime.now().toUtc();

    viewModel.changeYear(DateTime.utc(now.year + 1));

    final state = container
        .read(budgetDetailViewModelProvider(overall.id))
        .value;
    expect(state?.displayedYear, DateTime.utc(now.year + 1));
    expect(state?.selectedMonth.month, now.month);
    expect(state?.selectedMonth.year, now.year + 1);
  });

  test(
    'requestLimitEdit emits BudgetLimitEditRequested, clearStep resets it',
    () async {
      final overall = budget(categoryID: null, id: 'b1');
      final container = buildContainer(buildLedger(overall));
      await container.read(budgetDetailViewModelProvider(overall.id).future);
      final viewModel = container.read(
        budgetDetailViewModelProvider(overall.id).notifier,
      );

      viewModel.requestLimitEdit();
      expect(
        container.read(budgetDetailViewModelProvider(overall.id)).value?.step,
        isA<BudgetLimitEditRequested>(),
      );

      viewModel.clearStep();
      expect(
        container.read(budgetDetailViewModelProvider(overall.id)).value?.step,
        isNull,
      );
    },
  );

  test('chartMaxY extends 15 percent past the largest bar, floors at 1.0', () {
    expect(chartMaxY([dec('0')], [dec('0')]), 1.0);
    expect(chartMaxY([dec('100')], [dec('50')]), closeTo(115.0, 1e-9));
    expect(chartMaxY([dec('50')], [dec('200')]), closeTo(230.0, 1e-9));
  });
}
