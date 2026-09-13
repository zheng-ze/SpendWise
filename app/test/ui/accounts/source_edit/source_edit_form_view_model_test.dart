import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/source_edit/source_edit_form_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Ledger ledgerWithAccountBalance(Account account, {String balance = '100'}) {
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        entries: {
          'e0000000-0000-0000-0000-000000000001': Entry(
            id: 'e0000000-0000-0000-0000-000000000001',
            amount: dec(balance),
            name: 'Opening balance',
            sourceID: account.id,
            includeInAnalysis: false,
          ),
        },
      ),
    );
  }

  test('saving with an unchanged balance posts no entry', () async {
    final account = Account(name: 'Wallet', type: AccountType.cash);
    final ledger = ledgerWithAccountBalance(account);
    final container = buildContainer(ledger);
    await container.read(sourceEditFormViewModelProvider(account.id).future);
    final viewModel = container.read(
      sourceEditFormViewModelProvider(account.id).notifier,
    );

    await viewModel.save();

    expect(ledger.state.entries, hasLength(1));
  });

  test(
    'raising the balance posts one adjustment entry excluded from analysis',
    () async {
      final account = Account(name: 'Wallet', type: AccountType.cash);
      final ledger = ledgerWithAccountBalance(account);
      final container = buildContainer(ledger);
      await container.read(sourceEditFormViewModelProvider(account.id).future);
      final viewModel = container.read(
        sourceEditFormViewModelProvider(account.id).notifier,
      );

      viewModel.setBalance('150');
      await viewModel.save();

      expect(ledger.state.entries, hasLength(2));
      final posted = ledger.state.entries.values.firstWhere(
        (e) => e.id != 'e0000000-0000-0000-0000-000000000001',
      );
      expect(posted.amount, dec('50'));
      expect(posted.includeInAnalysis, isFalse);
      expect(posted.sourceID, account.id);
    },
  );

  test('lowering the balance posts a negative adjustment entry', () async {
    final account = Account(name: 'Wallet', type: AccountType.cash);
    final ledger = ledgerWithAccountBalance(account);
    final container = buildContainer(ledger);
    await container.read(sourceEditFormViewModelProvider(account.id).future);
    final viewModel = container.read(
      sourceEditFormViewModelProvider(account.id).notifier,
    );

    viewModel.setBalance('40');
    await viewModel.save();

    final posted = ledger.state.entries.values.firstWhere(
      (e) => e.id != 'e0000000-0000-0000-0000-000000000001',
    );
    expect(posted.amount, dec('-60'));
  });

  test('an empty balance field counts as zero and needs no entry', () async {
    final account = Account(name: 'Wallet', type: AccountType.cash);
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );
    final container = buildContainer(ledger);
    await container.read(sourceEditFormViewModelProvider(account.id).future);
    final viewModel = container.read(
      sourceEditFormViewModelProvider(account.id).notifier,
    );

    viewModel.setBalance('');
    await viewModel.save();

    expect(ledger.state.entries, isEmpty);
  });

  test('net worth toggle is unavailable for a pocket', () async {
    final account = Account(name: 'Wallet', type: AccountType.cash);
    final pocket = SubPocket(name: 'Vacation');
    final linkedAccount = account.addSubPocket(pocket.id);
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {
          linkedAccount.id: MoneySource.account(linkedAccount),
          pocket.id: MoneySource.pocket(pocket),
        },
      ),
    );
    final container = buildContainer(ledger);
    await container.read(sourceEditFormViewModelProvider(pocket.id).future);

    final formState = container
        .read(sourceEditFormViewModelProvider(pocket.id))
        .value;
    expect(formState?.isAccount, isFalse);
    // Cash cannot treat incoming transfers as expenses, and a pocket has no
    // type of its own, so it follows its parent account's eligibility.
    expect(formState?.showsTransferToggle, isFalse);
  });

  test(
    'transfer toggle is available for a pocket whose parent is eligible',
    () async {
      final account = Account(name: 'Nest egg', type: AccountType.savings);
      final pocket = SubPocket(name: 'Vacation');
      final linkedAccount = account.addSubPocket(pocket.id);
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {
            linkedAccount.id: MoneySource.account(linkedAccount),
            pocket.id: MoneySource.pocket(pocket),
          },
        ),
      );
      final container = buildContainer(ledger);
      await container.read(sourceEditFormViewModelProvider(pocket.id).future);

      final formState = container
          .read(sourceEditFormViewModelProvider(pocket.id))
          .value;
      expect(formState?.showsTransferToggle, isTrue);
    },
  );

  test('switching an account to an ineligible type resets the transfer toggle on save', () async {
    final account = Account(
      name: 'Nest egg',
      type: AccountType.savings,
      incomingTransfersAsExpenses: true,
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );
    final container = buildContainer(ledger);
    await container.read(sourceEditFormViewModelProvider(account.id).future);
    final viewModel = container.read(
      sourceEditFormViewModelProvider(account.id).notifier,
    );

    viewModel.setType(AccountType.checking);
    expect(
      container
          .read(sourceEditFormViewModelProvider(account.id))
          .value
          ?.showsTransferToggle,
      isFalse,
    );

    await viewModel.save();

    final stored = ledger.state.moneySources[account.id]!.asAccount!;
    expect(stored.incomingTransfersAsExpenses, isFalse);
  });

  test('save emits SourceEditFormSaved on success', () async {
    final account = Account(name: 'Wallet', type: AccountType.cash);
    final ledger = ledgerWithAccountBalance(account);
    final container = buildContainer(ledger);
    await container.read(sourceEditFormViewModelProvider(account.id).future);
    final viewModel = container.read(
      sourceEditFormViewModelProvider(account.id).notifier,
    );

    await viewModel.save();

    expect(
      container.read(sourceEditFormViewModelProvider(account.id)).value?.step,
      isA<SourceEditFormSaved>(),
    );
  });
}
