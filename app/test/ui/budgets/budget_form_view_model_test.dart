import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_form_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  Budget buildBudget({String? categoryID, String id = 'stale'}) {
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

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('build starts with an empty amount and Overall selected', () async {
    final container = buildContainer(Ledger(state: LedgerState()));

    final state = await container.read(budgetFormViewModelProvider.future);

    expect(state.categoryID, isNull);
    expect(state.amountText, '');
    expect(state.canSave, isFalse);
  });

  test('setAmount updates the amount text and recomputes canSave', () async {
    final container = buildContainer(Ledger(state: LedgerState()));
    await container.read(budgetFormViewModelProvider.future);
    final viewModel = container.read(budgetFormViewModelProvider.notifier);

    viewModel.setAmount('250.00');

    final state = container.read(budgetFormViewModelProvider).value;
    expect(state?.amountText, '250.00');
    expect(state?.canSave, isTrue);
  });

  test('requestPickCategory emits PickCategoryRequested', () async {
    final container = buildContainer(Ledger(state: LedgerState()));
    await container.read(budgetFormViewModelProvider.future);
    final viewModel = container.read(budgetFormViewModelProvider.notifier);

    viewModel.requestPickCategory();

    expect(
      container.read(budgetFormViewModelProvider).value?.step,
      isA<PickCategoryRequested>(),
    );
  });

  test('applyPickedCategory sets the category and clears the step', () async {
    final container = buildContainer(Ledger(state: LedgerState()));
    await container.read(budgetFormViewModelProvider.future);
    final viewModel = container.read(budgetFormViewModelProvider.notifier);

    viewModel.requestPickCategory();
    viewModel.applyPickedCategory('c1');

    final state = container.read(budgetFormViewModelProvider).value;
    expect(state?.categoryID, 'c1');
    expect(state?.step, isNull);
  });

  test(
    'save rejects a duplicate Overall budget, keeping the entered amount',
    () async {
      final existingOverall = buildBudget(categoryID: null, id: 'b1');
      final ledger = Ledger(
        state: LedgerState(budgets: {existingOverall.id: existingOverall}),
      );
      final container = buildContainer(ledger);
      await container.read(budgetFormViewModelProvider.future);
      final viewModel = container.read(budgetFormViewModelProvider.notifier);

      viewModel.setAmount('250.00');
      await viewModel.save();

      final state = container.read(budgetFormViewModelProvider).value;
      expect(state?.error, isA<LedgerError>());
      expect(state?.amountText, '250.00');
      expect(state?.step, isNull);
    },
  );

  test('save adds the budget and emits BudgetFormSaved on success', () async {
    final ledger = Ledger(state: LedgerState());
    final container = buildContainer(ledger);
    await container.read(budgetFormViewModelProvider.future);
    final viewModel = container.read(budgetFormViewModelProvider.notifier);

    viewModel.setAmount('250.00');
    await viewModel.save();

    expect(ledger.state.budgets, hasLength(1));
    final state = container.read(budgetFormViewModelProvider).value;
    expect(state?.step, isA<BudgetFormSaved>());
    expect(state?.error, isNull);
  });

  test('clearStep resets the step to null', () async {
    final container = buildContainer(Ledger(state: LedgerState()));
    await container.read(budgetFormViewModelProvider.future);
    final viewModel = container.read(budgetFormViewModelProvider.notifier);

    viewModel.requestPickCategory();
    expect(container.read(budgetFormViewModelProvider).value?.step, isNotNull);

    viewModel.clearStep();
    expect(container.read(budgetFormViewModelProvider).value?.step, isNull);
  });
}
