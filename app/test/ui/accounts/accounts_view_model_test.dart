import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';

void main() {
  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Main Checking',
    type: AccountType.checking,
    subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
  );
  final rentPocket = SubPocket(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Rent',
  );
  final savings = Account(
    id: 'a0000000-0000-0000-0000-000000000003',
    name: 'Piggy Bank',
    type: AccountType.savings,
  );

  Ledger buildLedger() {
    return Ledger(
      state: LedgerState(
        moneySources: {
          checking.id: MoneySource.account(checking),
          rentPocket.id: MoneySource.pocket(rentPocket),
          savings.id: MoneySource.account(savings),
        },
      ),
    );
  }

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'toggleExpanded opens and closes an account, single-open at a time',
    () async {
      final container = buildContainer(buildLedger());
      await container.read(accountsViewModelProvider.future);
      final viewModel = container.read(accountsViewModelProvider.notifier);

      viewModel.toggleExpanded(checking.id);
      expect(
        container.read(accountsViewModelProvider).value?.expandedAccountId,
        checking.id,
      );

      viewModel.toggleExpanded(savings.id);
      expect(
        container.read(accountsViewModelProvider).value?.expandedAccountId,
        savings.id,
      );

      viewModel.toggleExpanded(savings.id);
      expect(
        container.read(accountsViewModelProvider).value?.expandedAccountId,
        isNull,
      );
    },
  );

  test(
    'deleteAccount archives the account and collapses it when expanded',
    () async {
      final ledger = buildLedger();
      final container = buildContainer(ledger);
      await container.read(accountsViewModelProvider.future);
      final viewModel = container.read(accountsViewModelProvider.notifier);

      viewModel.toggleExpanded(checking.id);
      expect(
        container.read(accountsViewModelProvider).value?.expandedAccountId,
        checking.id,
      );

      await viewModel.deleteAccount(checking.id);

      expect(
        ledger.state.moneySources[checking.id]!.lifecycle,
        LifecycleState.archived,
      );
      expect(
        container.read(accountsViewModelProvider).value?.expandedAccountId,
        isNull,
      );
    },
  );

  test('deleteAccount leaves an unrelated expansion alone', () async {
    final ledger = buildLedger();
    final container = buildContainer(ledger);
    await container.read(accountsViewModelProvider.future);
    final viewModel = container.read(accountsViewModelProvider.notifier);

    viewModel.toggleExpanded(checking.id);
    await viewModel.deleteAccount(savings.id);

    expect(
      container.read(accountsViewModelProvider).value?.expandedAccountId,
      checking.id,
    );
  });

  test('deletePocket archives the pocket', () async {
    final ledger = buildLedger();
    final container = buildContainer(ledger);
    await container.read(accountsViewModelProvider.future);
    final viewModel = container.read(accountsViewModelProvider.notifier);

    await viewModel.deletePocket(rentPocket.id);

    expect(
      ledger.state.moneySources[rentPocket.id]!.lifecycle,
      LifecycleState.archived,
    );
  });

  test(
    'openAccount emits AccountOpened scoped to the account and its pockets',
    () async {
      final container = buildContainer(buildLedger());
      await container.read(accountsViewModelProvider.future);
      final viewModel = container.read(accountsViewModelProvider.notifier);

      viewModel.openAccount(checking.id);

      final step = container.read(accountsViewModelProvider).value?.step;
      expect(step, isA<AccountOpened>());
      final opened = step as AccountOpened;
      expect(opened.title, 'Main Checking');
      expect(opened.scopeIDs, {checking.id, rentPocket.id});
    },
  );

  test(
    'openAccountAlone emits AccountAloneOpened scoped to the account only',
    () async {
      final container = buildContainer(buildLedger());
      await container.read(accountsViewModelProvider.future);
      final viewModel = container.read(accountsViewModelProvider.notifier);

      viewModel.openAccountAlone(checking.id);

      final step = container.read(accountsViewModelProvider).value?.step;
      expect(step, isA<AccountAloneOpened>());
      final opened = step as AccountAloneOpened;
      expect(opened.title, 'Main Checking');
      expect(opened.scopeIDs, {checking.id});
    },
  );

  test('openPocket emits PocketOpened scoped to the pocket alone', () async {
    final container = buildContainer(buildLedger());
    await container.read(accountsViewModelProvider.future);
    final viewModel = container.read(accountsViewModelProvider.notifier);

    viewModel.openPocket(rentPocket.id);

    final step = container.read(accountsViewModelProvider).value?.step;
    expect(step, isA<PocketOpened>());
    final opened = step as PocketOpened;
    expect(opened.title, 'Rent');
    expect(opened.scopeIDs, {rentPocket.id});
  });

  test('requestNewAccount emits AccountFormRequested', () async {
    final container = buildContainer(buildLedger());
    await container.read(accountsViewModelProvider.future);
    final viewModel = container.read(accountsViewModelProvider.notifier);

    viewModel.requestNewAccount();

    expect(
      container.read(accountsViewModelProvider).value?.step,
      isA<AccountFormRequested>(),
    );
  });

  test('clearStep resets the step to null', () async {
    final container = buildContainer(buildLedger());
    await container.read(accountsViewModelProvider.future);
    final viewModel = container.read(accountsViewModelProvider.notifier);

    viewModel.requestNewAccount();
    expect(container.read(accountsViewModelProvider).value?.step, isNotNull);

    viewModel.clearStep();
    expect(container.read(accountsViewModelProvider).value?.step, isNull);
  });
}
