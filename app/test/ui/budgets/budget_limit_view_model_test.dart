import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_limit_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  Budget buildBudget() {
    return Budget(
      id: 'b1',
      categoryID: null,
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

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('build reads the default limit and the current year', () async {
    final budget = buildBudget();
    final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
    final container = buildContainer(ledger);
    final now = DateTime.now().toUtc();

    final state = await container.read(
      budgetLimitViewModelProvider(budget.id).future,
    );

    expect(state.defaultLimit, dec('100'));
    expect(state.displayedYear, DateTime.utc(now.year));
    expect(state.months, hasLength(12));
  });

  test('changeYear updates the displayed year', () async {
    final budget = buildBudget();
    final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
    final container = buildContainer(ledger);
    await container.read(budgetLimitViewModelProvider(budget.id).future);
    final viewModel = container.read(
      budgetLimitViewModelProvider(budget.id).notifier,
    );
    final now = DateTime.now().toUtc();

    viewModel.changeYear(DateTime.utc(now.year + 1));

    expect(
      container
          .read(budgetLimitViewModelProvider(budget.id))
          .value
          ?.displayedYear,
      DateTime.utc(now.year + 1),
    );
  });

  test(
    'requestEditDefault emits a PickLimitRequested for next month',
    () async {
      final budget = buildBudget();
      final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
      final container = buildContainer(ledger);
      await container.read(budgetLimitViewModelProvider(budget.id).future);
      final viewModel = container.read(
        budgetLimitViewModelProvider(budget.id).notifier,
      );
      final now = DateTime.now().toUtc();
      final expectedMonth = YearMonth.fromUtc(
        DateTime.utc(now.year, now.month + 1),
      );

      viewModel.requestEditDefault();

      final step = container
          .read(budgetLimitViewModelProvider(budget.id))
          .value
          ?.step;
      expect(step, isA<PickLimitRequested>());
      final target = (step as PickLimitRequested).target;
      expect(target, isA<DefaultLimitTarget>());
      expect((target as DefaultLimitTarget).current, dec('100'));
      expect(target.effectiveFromMonth, expectedMonth);
    },
  );

  test('requestEditMonth emits a PickLimitRequested for that month', () async {
    final budget = buildBudget();
    final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
    final container = buildContainer(ledger);
    await container.read(budgetLimitViewModelProvider(budget.id).future);
    final viewModel = container.read(
      budgetLimitViewModelProvider(budget.id).notifier,
    );
    const month = YearMonth(2026, 6);

    viewModel.requestEditMonth(month);

    final step = container
        .read(budgetLimitViewModelProvider(budget.id))
        .value
        ?.step;
    expect(step, isA<PickLimitRequested>());
    final target = (step as PickLimitRequested).target;
    expect(target, isA<MonthLimitTarget>());
    expect((target as MonthLimitTarget).month, month);
    expect(target.current, dec('100'));
  });

  test('applyPickedLimit(default target) sets the default from next month, '
      'not the current month', () async {
    final budget = buildBudget();
    final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
    final container = buildContainer(ledger);
    await container.read(budgetLimitViewModelProvider(budget.id).future);
    final viewModel = container.read(
      budgetLimitViewModelProvider(budget.id).notifier,
    );
    final now = DateTime.now().toUtc();
    final currentMonth = YearMonth(now.year, now.month);

    viewModel.requestEditDefault();
    viewModel.applyPickedLimit(dec('200'));

    expect(
      effectiveLimit(ledger.state.budgets[budget.id]!, currentMonth),
      dec('100'),
    );
    expect(
      container.read(budgetLimitViewModelProvider(budget.id)).value?.step,
      isNull,
    );
  });

  test('applyPickedLimit(month target) sets that month\'s override', () async {
    final budget = buildBudget();
    final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
    final container = buildContainer(ledger);
    await container.read(budgetLimitViewModelProvider(budget.id).future);
    final viewModel = container.read(
      budgetLimitViewModelProvider(budget.id).notifier,
    );
    const month = YearMonth(2026, 6);

    viewModel.requestEditMonth(month);
    viewModel.applyPickedLimit(dec('150'));

    expect(effectiveLimit(ledger.state.budgets[budget.id]!, month), dec('150'));
  });

  test(
    'applyPickedLimit(null) leaves the budget unchanged and clears the step',
    () async {
      final budget = buildBudget();
      final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
      final container = buildContainer(ledger);
      await container.read(budgetLimitViewModelProvider(budget.id).future);
      final viewModel = container.read(
        budgetLimitViewModelProvider(budget.id).notifier,
      );

      viewModel.requestEditMonth(const YearMonth(2026, 6));
      viewModel.applyPickedLimit(null);

      expect(
        effectiveLimit(
          ledger.state.budgets[budget.id]!,
          const YearMonth(2026, 6),
        ),
        dec('100'),
      );
      expect(
        container.read(budgetLimitViewModelProvider(budget.id)).value?.step,
        isNull,
      );
    },
  );

  test(
    'applyPickedLimit with no PickLimitRequested step in flight is a no-op',
    () async {
      final budget = buildBudget();
      final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
      final container = buildContainer(ledger);
      await container.read(budgetLimitViewModelProvider(budget.id).future);
      final viewModel = container.read(
        budgetLimitViewModelProvider(budget.id).notifier,
      );

      viewModel.applyPickedLimit(dec('999'));

      final now = DateTime.now().toUtc();
      expect(
        effectiveLimit(
          ledger.state.budgets[budget.id]!,
          YearMonth(now.year, now.month),
        ),
        dec('100'),
      );
    },
  );

  test('clearStep resets the step to null', () async {
    final budget = buildBudget();
    final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
    final container = buildContainer(ledger);
    await container.read(budgetLimitViewModelProvider(budget.id).future);
    final viewModel = container.read(
      budgetLimitViewModelProvider(budget.id).notifier,
    );

    viewModel.requestEditMonth(const YearMonth(2026, 6));
    expect(
      container.read(budgetLimitViewModelProvider(budget.id)).value?.step,
      isNotNull,
    );

    viewModel.clearStep();
    expect(
      container.read(budgetLimitViewModelProvider(budget.id)).value?.step,
      isNull,
    );
  });
}
