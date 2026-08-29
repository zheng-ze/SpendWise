import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/account_form/account_form_logic.dart';
import 'package:spendwise/ui/accounts/account_form/account_form_view_model.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('cannot save with a blank name', () async {
    final container = buildContainer(Ledger());
    await container.read(accountFormViewModelProvider.future);
    final viewModel = container.read(accountFormViewModelProvider.notifier);

    viewModel.setName('   ');

    expect(
      container.read(accountFormViewModelProvider).value?.canSave,
      isFalse,
    );
  });

  test('locks to account kind when no account can hold a pocket', () async {
    final card = Account(name: 'Visa', type: AccountType.card);
    final ledger = Ledger(
      state: LedgerState(moneySources: {card.id: MoneySource.account(card)}),
    );
    final container = buildContainer(ledger);
    await container.read(accountFormViewModelProvider.future);

    final formState = container.read(accountFormViewModelProvider).value;
    expect(formState?.isLockedToAccount, isTrue);
    expect(formState?.effectiveKind, AccountFormKind.account);
  });

  test('subpocket kind requires a parent to save', () async {
    final account = Account(name: 'Checking', type: AccountType.checking);
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );
    final container = buildContainer(ledger);
    await container.read(accountFormViewModelProvider.future);
    final viewModel = container.read(accountFormViewModelProvider.notifier);

    viewModel.setKind(AccountFormKind.subpocket);
    viewModel.setName('Rent');

    expect(
      container.read(accountFormViewModelProvider).value?.canSave,
      isFalse,
    );

    viewModel.applyPickedParent(account.id);

    expect(container.read(accountFormViewModelProvider).value?.canSave, isTrue);
  });

  test('requestPickParent emits PickParentRequested', () async {
    final container = buildContainer(Ledger());
    await container.read(accountFormViewModelProvider.future);
    final viewModel = container.read(accountFormViewModelProvider.notifier);

    viewModel.requestPickParent();

    expect(
      container.read(accountFormViewModelProvider).value?.step,
      isA<PickParentRequested>(),
    );
  });

  test('applyPickedParent is a no-op once the provider is disposed', () async {
    final container = buildContainer(Ledger());
    await container.read(accountFormViewModelProvider.future);
    final viewModel = container.read(accountFormViewModelProvider.notifier);

    container.dispose();

    // Must not throw even though the underlying state is gone.
    expect(() => viewModel.applyPickedParent('some-id'), returnsNormally);
  });

  test('saving an account with zero opening balance posts no entry', () async {
    final ledger = Ledger();
    final container = buildContainer(ledger);
    await container.read(accountFormViewModelProvider.future);
    final viewModel = container.read(accountFormViewModelProvider.notifier);

    viewModel.setName('Wallet');
    await viewModel.save();

    expect(ledger.state.entries, isEmpty);
    expect(ledger.state.activeAccounts, hasLength(1));
    expect(ledger.state.activeAccounts.single.name, 'Wallet');
    expect(
      container.read(accountFormViewModelProvider).value?.step,
      isA<AccountFormSaved>(),
    );
  });

  test(
    'saving an account with an opening balance posts the balance entry',
    () async {
      final ledger = Ledger();
      final container = buildContainer(ledger);
      await container.read(accountFormViewModelProvider.future);
      final viewModel = container.read(accountFormViewModelProvider.notifier);

      viewModel.setName('Wallet');
      viewModel.setBalance('100');
      await viewModel.save();

      expect(ledger.state.entries, hasLength(1));
      expect(ledger.state.entries.values.single.amount, dec('100'));
    },
  );

  test('statement day is not persisted for a non-card account', () async {
    final ledger = Ledger();
    final container = buildContainer(ledger);
    await container.read(accountFormViewModelProvider.future);
    final viewModel = container.read(accountFormViewModelProvider.notifier);

    viewModel.setName('Wallet');
    viewModel.setStatementDay(5);
    await viewModel.save();

    expect(ledger.state.activeAccounts.single.statementDay, isNull);
  });

  test('saving a card persists its statement day', () async {
    final ledger = Ledger();
    final container = buildContainer(ledger);
    await container.read(accountFormViewModelProvider.future);
    final viewModel = container.read(accountFormViewModelProvider.notifier);

    viewModel.setName('Visa');
    viewModel.setType(AccountType.card);
    viewModel.setStatementDay(15);
    await viewModel.save();

    expect(ledger.state.activeAccounts.single.statementDay, 15);
  });

  test('saving a subpocket adds it under the picked parent', () async {
    final account = Account(name: 'Checking', type: AccountType.checking);
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );
    final container = buildContainer(ledger);
    await container.read(accountFormViewModelProvider.future);
    final viewModel = container.read(accountFormViewModelProvider.notifier);

    viewModel.setKind(AccountFormKind.subpocket);
    viewModel.setName('Rent');
    viewModel.applyPickedParent(account.id);
    await viewModel.save();

    expect(
      ledger.state.moneySources[account.id]!.asAccount!.subPocketIDs,
      hasLength(1),
    );
  });
}
