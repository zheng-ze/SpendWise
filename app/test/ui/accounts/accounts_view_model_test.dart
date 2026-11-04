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
    container.listen(accountsViewModelProvider, (previous, next) {});
    return container;
  }

  test(
    'toggleExpanded opens and closes an account, single-open at a time',
    () async {
      final container = buildContainer(buildLedger());
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
    final viewModel = container.read(accountsViewModelProvider.notifier);

    viewModel.toggleExpanded(checking.id);
    await viewModel.deleteAccount(savings.id);

    expect(
      container.read(accountsViewModelProvider).value?.expandedAccountId,
      checking.id,
    );
  });

  test('a failing deleteAccount leaves the account expanded', () async {
    final container = buildContainer(ThrowingDeleteLedger(buildLedger().state));
    final viewModel = container.read(accountsViewModelProvider.notifier);
    viewModel.toggleExpanded(checking.id);

    await expectLater(viewModel.deleteAccount(checking.id), throwsStateError);

    expect(
      container.read(accountsViewModelProvider).value?.expandedAccountId,
      checking.id,
    );
  });

  test('deletePocket archives the pocket', () async {
    final ledger = buildLedger();
    final container = buildContainer(ledger);
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
    final viewModel = container.read(accountsViewModelProvider.notifier);

    viewModel.requestNewAccount();

    expect(
      container.read(accountsViewModelProvider).value?.step,
      isA<AccountFormRequested>(),
    );
  });

  test('clearStep resets the step to null', () async {
    final container = buildContainer(buildLedger());
    final viewModel = container.read(accountsViewModelProvider.notifier);

    viewModel.requestNewAccount();
    expect(container.read(accountsViewModelProvider).value?.step, isNotNull);

    viewModel.clearStep();
    expect(container.read(accountsViewModelProvider).value?.step, isNull);
  });

  test('an unmounted view model resets expansion and keeps the data', () async {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(buildLedger())],
    );
    addTearDown(container.dispose);
    final mounted = container.listen(accountsViewModelProvider, (_, _) {});
    container
        .read(accountsViewModelProvider.notifier)
        .toggleExpanded(checking.id);

    mounted.close();
    await container.pump();

    final remounted = container.read(accountsViewModelProvider);
    expect(remounted.value?.expandedAccountId, isNull);
    expect(remounted.value?.sections, isNotEmpty);
  });

  test('the ledger sections and net worth appear in the state', () {
    final container = buildContainer(buildLedger());

    final state = container.read(accountsViewModelProvider).requireValue;

    final ids = [
      for (final section in state.sections)
        for (final row in section.rows) row.id,
    ];
    expect(ids, unorderedEquals([checking.id, savings.id]));
    expect(state.netWorth, Accounting.netWorth(buildLedger().state));
  });

  test('a ledger change updates the sections and net worth', () {
    final ledger = buildLedger();
    final container = buildContainer(ledger);

    ledger.deleteAccount(savings.id);

    final state = container.read(accountsViewModelProvider).requireValue;
    final ids = [
      for (final section in state.sections)
        for (final row in section.rows) row.id,
    ];
    expect(ids, [checking.id]);
    expect(state.netWorth, Accounting.netWorth(ledger.state));
  });

  test('an unmounted view model stops listening to the ledger', () async {
    final ledger = ListenerTrackingLedger(buildLedger().state);
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    final mounted = container.listen(accountsViewModelProvider, (_, _) {});
    expect(ledger.isListened, isTrue);

    mounted.close();
    await container.pump();

    expect(ledger.isListened, isFalse);
  });

  test('a ledger change keeps the expansion and the pending step', () {
    final ledger = buildLedger();
    final container = buildContainer(ledger);
    final viewModel = container.read(accountsViewModelProvider.notifier);
    viewModel.toggleExpanded(checking.id);
    viewModel.requestNewAccount();

    ledger.deletePocket(rentPocket.id);

    final state = container.read(accountsViewModelProvider).value;
    expect(state?.expandedAccountId, checking.id);
    expect(state?.step, isA<AccountFormRequested>());
  });
}

class ThrowingDeleteLedger extends Ledger {
  ThrowingDeleteLedger(LedgerState state) : super(state: state);

  @override
  List<LedgerChange> deleteAccount(String rawID) =>
      throw StateError('delete failed');
}

class ListenerTrackingLedger extends Ledger {
  ListenerTrackingLedger(LedgerState state) : super(state: state);

  bool get isListened => hasListeners;
}
