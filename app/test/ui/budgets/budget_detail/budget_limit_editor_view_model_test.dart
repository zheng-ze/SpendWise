import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_editor_view_model.dart';
import 'package:spendwise/ui/budgets/budget_detail/budgets_steps.dart';

const _budgetID = 'b1';

Budget _budget() =>
    Budget(id: _budgetID, categoryID: null, limit: Decimal.fromInt(100));

Ledger _ledger() => Ledger(state: LedgerState(budgets: {_budgetID: _budget()}));

typedef _Fixture = ({
  ProviderContainer container,
  BudgetLimitDraftKey key,
  BudgetLimitEditorNotifier viewModel,
});

_Fixture _open(Ledger? ledger, {String budgetID = _budgetID}) {
  final container = ProviderContainer(
    overrides: [ledgerProvider.overrideWithValue(ledger)],
  );
  addTearDown(container.dispose);
  final key = BudgetLimitDraftKey(
    budgetID: budgetID,
    initialLimit: Decimal.fromInt(100),
  );
  final provider = budgetLimitEditorViewModelProvider(key);
  container.listen(provider, (_, _) {});
  return (
    container: container,
    key: key,
    viewModel: container.read(provider.notifier),
  );
}

BudgetLimitEditorState _read(_Fixture fixture) => fixture.container
    .read(budgetLimitEditorViewModelProvider(fixture.key))
    .requireValue;

void main() {
  test('the draft is seeded with the initial limit', () {
    final fixture = _open(_ledger());

    expect(_read(fixture).amountText, '100.00');
    expect(_read(fixture).error, isNull);
    expect(_read(fixture).step, isNull);
    expect(_read(fixture).canSave, isTrue);
  });

  for (final (raw, saveable) in [
    ('', false),
    ('.', false),
    ('0', false),
    ('-5', false),
    ('0.01', true),
  ]) {
    test('canSave is $saveable for amount "$raw"', () {
      final fixture = _open(_ledger());

      fixture.viewModel.setAmount(raw);

      expect(_read(fixture).canSave, saveable);
    });
  }

  test('save writes the limit once and emits BudgetLimitSaved', () {
    final ledger = _ledger();
    final fixture = _open(ledger);
    final revision = ledger.revision;

    fixture.viewModel.setAmount('250.50');
    fixture.viewModel.save();

    expect(ledger.revision, revision + 1);
    expect(ledger.state.budgets[_budgetID]!.limit, Decimal.parse('250.50'));
    expect(_read(fixture).step, isA<BudgetLimitSaved>());
    expect(_read(fixture).error, isNull);
  });

  test('save does nothing while the amount cannot be saved', () {
    final ledger = _ledger();
    final fixture = _open(ledger);

    fixture.viewModel.setAmount('0');
    fixture.viewModel.save();

    expect(ledger.state.budgets[_budgetID]!.limit, Decimal.fromInt(100));
    expect(_read(fixture).step, isNull);
  });

  test('a budget deleted elsewhere keeps the amount and the error', () {
    final ledger = _ledger();
    final fixture = _open(ledger);
    fixture.viewModel.setAmount('75');
    ledger.deleteBudget(_budgetID);

    fixture.viewModel.save();

    expect(_read(fixture).error, isA<UnknownBudget>());
    expect(_read(fixture).amountText, '75');
    expect(_read(fixture).step, isNull);
    expect(ledger.state.budgets, isEmpty);
  });

  test('a missing ledger session becomes an error and writes nothing', () {
    final fixture = _open(null);

    final value = fixture.container.read(
      budgetLimitEditorViewModelProvider(fixture.key),
    );

    expect(value.error, isA<StateError>());
  });

  test('keys with equal fields resolve to separate drafts', () {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(_ledger())],
    );
    addTearDown(container.dispose);
    final first = BudgetLimitDraftKey(
      budgetID: _budgetID,
      initialLimit: Decimal.fromInt(100),
    );
    final second = BudgetLimitDraftKey(
      budgetID: _budgetID,
      initialLimit: Decimal.fromInt(100),
    );
    container.listen(budgetLimitEditorViewModelProvider(first), (_, _) {});
    container.listen(budgetLimitEditorViewModelProvider(second), (_, _) {});

    container
        .read(budgetLimitEditorViewModelProvider(first).notifier)
        .setAmount('5');

    final other = container.read(budgetLimitEditorViewModelProvider(second));
    expect(other.requireValue.amountText, '100.00');
  });

  test('clearStep resets the step to null', () {
    final fixture = _open(_ledger());
    fixture.viewModel.save();

    fixture.viewModel.clearStep();

    expect(_read(fixture).step, isNull);
  });
}
