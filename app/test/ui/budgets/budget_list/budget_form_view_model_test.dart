import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_scope_options.dart';

TransactionCategory _category(String name) => TransactionCategory(
  name: name,
  kind: CategoryKind.expense,
  colorHex: '#00AA00',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'restaurant',
);

typedef _Fixture = ({
  ProviderContainer container,
  BudgetDraftKey key,
  BudgetFormNotifier viewModel,
});

BudgetFormViewState _read(_Fixture fixture) => fixture.container
    .read(budgetFormViewModelProvider(fixture.key))
    .requireValue;

Future<_Fixture> _open(Ledger? ledger) async {
  final container = ProviderContainer(
    overrides: [ledgerProvider.overrideWithValue(ledger)],
  );
  addTearDown(container.dispose);
  final key = BudgetDraftKey();
  final provider = budgetFormViewModelProvider(key);
  container.listen(provider, (_, _) {});
  await container.read(provider.future).then((_) {}, onError: (_) {});
  return (
    container: container,
    key: key,
    viewModel: container.read(provider.notifier),
  );
}

void main() {
  test('a fresh draft selects All spending when that slot is free', () async {
    final fixture = await _open(Ledger(state: LedgerState()));

    final state = _read(fixture);

    expect(state.scope, const AllSpendingChosen());
    expect(state.amountText, '');
    expect(state.canSave, isFalse);
  });

  test('a fresh draft has no scope when All spending is budgeted', () async {
    final overall = Budget(categoryID: null, limit: Decimal.fromInt(10));
    final ledger = Ledger(state: LedgerState(budgets: {overall.id: overall}));
    final fixture = await _open(ledger);

    final state = _read(fixture);

    expect(state.scope, isNull);
    expect(state.scopeLabel, 'Choose');
  });

  for (final (raw, saveable) in [
    ('', false),
    ('.', false),
    ('0', false),
    ('-5', false),
    ('0.01', true),
    ('250.00', true),
  ]) {
    test('canSave is $saveable for amount "$raw"', () async {
      final fixture = await _open(Ledger(state: LedgerState()));

      fixture.viewModel.setAmount(raw);

      expect(_read(fixture).canSave, saveable);
    });
  }

  test('canSave is false without a scope even with a valid amount', () async {
    final overall = Budget(categoryID: null, limit: Decimal.fromInt(10));
    final ledger = Ledger(state: LedgerState(budgets: {overall.id: overall}));
    final fixture = await _open(ledger);

    fixture.viewModel.setAmount('5');

    expect(_read(fixture).canSave, isFalse);
  });

  test('requestPickCategory emits PickCategoryRequested', () async {
    final fixture = await _open(Ledger(state: LedgerState()));

    fixture.viewModel.requestPickCategory();

    expect(_read(fixture).step, isA<PickCategoryRequested>());
  });

  test('applyPickedScope sets the scope label and clears the step', () async {
    final food = _category('Food');
    final ledger = Ledger(state: LedgerState(categories: {food.id: food}));
    final fixture = await _open(ledger);

    fixture.viewModel.requestPickCategory();
    fixture.viewModel.applyPickedScope(CategoryChosen(food.id));

    expect(_read(fixture).scopeLabel, 'Food');
    expect(_read(fixture).step, isNull);
  });

  test('save writes exactly one budget with the chosen category', () async {
    final food = _category('Food');
    final ledger = Ledger(state: LedgerState(categories: {food.id: food}));
    final fixture = await _open(ledger);

    fixture.viewModel.applyPickedScope(CategoryChosen(food.id));
    fixture.viewModel.setAmount('250.50');
    await fixture.viewModel.save();

    final budget = ledger.state.budgets.values.single;
    expect(budget.categoryID, food.id);
    expect(budget.limit, Decimal.parse('250.50'));
    expect(_read(fixture).step, isA<BudgetFormSaved>());
    expect(_read(fixture).error, isNull);
  });

  test('save with All spending writes an unscoped budget', () async {
    final ledger = Ledger(state: LedgerState());
    final fixture = await _open(ledger);

    fixture.viewModel.setAmount('10');
    await fixture.viewModel.save();

    expect(ledger.state.budgets.values.single.categoryID, isNull);
  });

  test('save does nothing while the draft cannot be saved', () async {
    final ledger = Ledger(state: LedgerState());
    final fixture = await _open(ledger);

    fixture.viewModel.setAmount('-5');
    await fixture.viewModel.save();

    expect(ledger.state.budgets, isEmpty);
    expect(_read(fixture).step, isNull);
  });

  test(
    'a budget added elsewhere keeps the draft and a retry writes once',
    () async {
      final food = _category('Food');
      final ledger = Ledger(state: LedgerState(categories: {food.id: food}));
      final fixture = await _open(ledger);
      fixture.viewModel.setAmount('250.00');
      ledger.addBudget(null, Decimal.fromInt(10));

      await fixture.viewModel.save();

      expect(_read(fixture).error, isA<CategoryAlreadyBudgeted>());
      expect(_read(fixture).amountText, '250.00');
      expect(_read(fixture).step, isNull);

      fixture.viewModel.applyPickedScope(CategoryChosen(food.id));
      await fixture.viewModel.save();

      expect(ledger.state.budgets, hasLength(2));
      expect(_read(fixture).error, isNull);
    },
  );

  test(
    'a category archived after the pick keeps the draft and the error',
    () async {
      final food = _category('Food');
      final ledger = Ledger(state: LedgerState(categories: {food.id: food}));
      final fixture = await _open(ledger);
      fixture.viewModel.applyPickedScope(CategoryChosen(food.id));
      fixture.viewModel.setAmount('20');
      ledger.deleteCategory(food.id);

      await fixture.viewModel.save();

      expect(_read(fixture).error, isA<InactiveReference>());
      expect(_read(fixture).amountText, '20');
      expect(ledger.state.budgets, isEmpty);
    },
  );

  test(
    'an initialization failure becomes an error and retry reloads once',
    () async {
      final container = ProviderContainer(
        overrides: [ledgerProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final provider = budgetFormViewModelProvider(BudgetDraftKey());
      final seen = <AsyncValue<BudgetFormViewState>>[];
      container.listen(provider, (_, next) => seen.add(next));
      await container.read(provider.future).then((_) {}, onError: (_) {});
      expect(container.read(provider).error, isA<StateError>());
      seen.clear();

      container.read(provider.notifier).retry();
      await container.read(provider.future).then((_) {}, onError: (_) {});

      expect(seen.first.isLoading, isTrue);
      expect(seen.where((value) => value.isLoading), hasLength(1));
      expect(container.read(provider).error, isA<StateError>());
    },
  );

  test('clearStep resets the step to null', () async {
    final fixture = await _open(Ledger(state: LedgerState()));
    fixture.viewModel.requestPickCategory();

    fixture.viewModel.clearStep();

    expect(_read(fixture).step, isNull);
  });
}
