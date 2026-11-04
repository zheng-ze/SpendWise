import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  Account account(
    String id,
    String name, {
    LifecycleState lifecycle = LifecycleState.archived,
    Set<String> subPocketIDs = const {},
  }) => Account(
    id: id,
    name: name,
    type: AccountType.checking,
    lifecycle: lifecycle,
    subPocketIDs: subPocketIDs,
  );

  SubPocket pocket(
    String id,
    String name, {
    LifecycleState lifecycle = LifecycleState.archived,
  }) => SubPocket(id: id, name: name, lifecycle: lifecycle);

  TransactionCategory category(
    String id,
    String name, {
    LifecycleState lifecycle = LifecycleState.archived,
  }) => TransactionCategory(
    id: id,
    name: name,
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'tag',
    lifecycle: lifecycle,
  );

  Ledger buildLedger({
    Map<String, MoneySource> moneySources = const {},
    Map<String, TransactionCategory> categories = const {},
    Map<String, Entry> entries = const {},
    Map<String, Entry> binnedEntries = const {},
  }) {
    return Ledger(
      state: LedgerState(
        moneySources: moneySources,
        categories: categories,
        entries: entries,
        binnedEntries: binnedEntries,
      ),
    );
  }

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    container.listen(recycleBinViewModelProvider, (previous, next) {});
    return container;
  }

  test('restore(account) reactivates the account', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.restore(BinRowKind.account, acc.id);

    expect(ledger.state.moneySources[acc.id]!.lifecycle, LifecycleState.active);
  });

  test('restore(pocket) is a no-op while the parent account is still '
      'archived', () {
    final parent = account(
      'a0000000-0000-0000-0000-000000000001',
      'Main',
      subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
    );
    final pkt = pocket('a0000000-0000-0000-0000-000000000002', 'Rent');
    final ledger = buildLedger(
      moneySources: {
        parent.id: MoneySource.account(parent),
        pkt.id: MoneySource.pocket(pkt),
      },
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.restore(BinRowKind.pocket, pkt.id);

    expect(
      ledger.state.moneySources[pkt.id]!.lifecycle,
      LifecycleState.archived,
    );
  });

  test('restore(category) reactivates the category', () {
    final cat = category('a0000000-0000-0000-0000-000000000004', 'Old Cat');
    final ledger = buildLedger(categories: {cat.id: cat});
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.restore(BinRowKind.category, cat.id);

    expect(ledger.state.categories[cat.id]!.lifecycle, LifecycleState.active);
  });

  test('requestPurge emits PurgeConfirmationRequested carrying the row', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;

    viewModel.requestPurge(row);

    final step = container.read(recycleBinViewModelProvider).value?.step;
    expect(step, isA<PurgeConfirmationRequested>());
    expect((step as PurgeConfirmationRequested).row.id, acc.id);
    expect(step.row.name, 'Old Bank');
  });

  test('applyPurgeConfirmed(true) purges the account and clears the step', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;
    viewModel.requestPurge(row);

    viewModel.applyPurgeConfirmed(true, row.kind, row.id);

    expect(ledger.state.moneySources.containsKey(acc.id), isFalse);
    expect(container.read(recycleBinViewModelProvider).value?.step, isNull);
  });

  test('applyPurgeConfirmed(false) leaves the row untouched and clears the '
      'step', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;
    viewModel.requestPurge(row);

    viewModel.applyPurgeConfirmed(false, row.kind, row.id);

    expect(ledger.state.moneySources.containsKey(acc.id), isTrue);
    expect(container.read(recycleBinViewModelProvider).value?.step, isNull);
  });

  test('applyPurgeConfirmed(true) purges a pocket', () {
    final parent = account(
      'a0000000-0000-0000-0000-000000000001',
      'Main',
      lifecycle: LifecycleState.active,
      subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
    );
    final pkt = pocket('a0000000-0000-0000-0000-000000000002', 'Rent');
    final ledger = buildLedger(
      moneySources: {
        parent.id: MoneySource.account(parent),
        pkt.id: MoneySource.pocket(pkt),
      },
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.applyPurgeConfirmed(true, BinRowKind.pocket, pkt.id);

    expect(ledger.state.moneySources.containsKey(pkt.id), isFalse);
  });

  test('applyPurgeConfirmed(true) purges a category', () {
    final cat = category('a0000000-0000-0000-0000-000000000004', 'Old Cat');
    final ledger = buildLedger(categories: {cat.id: cat});
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.applyPurgeConfirmed(true, BinRowKind.category, cat.id);

    expect(ledger.state.categories.containsKey(cat.id), isFalse);
  });

  test('clearStep resets the step to null', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;

    viewModel.requestPurge(row);
    expect(container.read(recycleBinViewModelProvider).value?.step, isNotNull);

    viewModel.clearStep();
    expect(container.read(recycleBinViewModelProvider).value?.step, isNull);
  });

  test('empty ledger yields empty row lists', () {
    final container = buildContainer(buildLedger());

    final state = container.read(recycleBinViewModelProvider).value;

    expect(state?.entries, isEmpty);
    expect(state?.accounts, isEmpty);
    expect(state?.pockets, isEmpty);
    expect(state?.categories, isEmpty);
  });

  test('archived accounts, pockets and categories are each listed, sorted '
      'by name', () {
    final zebra = account('a0000000-0000-0000-0000-000000000001', 'Zebra');
    final alpha = account('a0000000-0000-0000-0000-000000000002', 'Alpha');
    final pkt = pocket('a0000000-0000-0000-0000-000000000003', 'Rent');
    final cat = category('a0000000-0000-0000-0000-000000000004', 'Old Cat');
    final container = buildContainer(
      buildLedger(
        moneySources: {
          zebra.id: MoneySource.account(zebra),
          alpha.id: MoneySource.account(alpha),
          pkt.id: MoneySource.pocket(pkt),
        },
        categories: {cat.id: cat},
      ),
    );

    final state = container.read(recycleBinViewModelProvider).value;

    expect(state?.accounts.map((r) => r.name), ['Alpha', 'Zebra']);
    expect(state?.pockets.map((r) => r.name), ['Rent']);
    expect(state?.categories.map((r) => r.name), ['Old Cat']);
  });

  test('an active holder is excluded from its row list', () {
    final acc = account(
      'a0000000-0000-0000-0000-000000000001',
      'Active One',
      lifecycle: LifecycleState.active,
    );
    final container = buildContainer(
      buildLedger(moneySources: {acc.id: MoneySource.account(acc)}),
    );

    expect(
      container.read(recycleBinViewModelProvider).value?.accounts,
      isEmpty,
    );
  });

  test('a binned entry is listed with its name', () {
    final acc = account(
      'a0000000-0000-0000-0000-000000000001',
      'Bank',
      lifecycle: LifecycleState.active,
    );
    final entry = Entry(amount: dec('5'), name: 'Coffee', sourceID: acc.id);
    final container = buildContainer(
      buildLedger(
        moneySources: {acc.id: MoneySource.account(acc)},
        binnedEntries: {entry.id: entry},
      ),
    );

    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .entries
        .single;

    expect(row.id, entry.id);
    expect(row.name, 'Coffee');
  });

  test('a row shows how many entries reference it', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final entry = Entry(amount: dec('5'), name: 'x', sourceID: acc.id);
    final container = buildContainer(
      buildLedger(
        moneySources: {acc.id: MoneySource.account(acc)},
        entries: {entry.id: entry},
      ),
    );

    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;

    expect(row.referenceCount, 1);
  });

  test('a pocket row is named with its qualified name when the parent '
      'resolves', () {
    final parent = account(
      'a0000000-0000-0000-0000-000000000001',
      'Main',
      lifecycle: LifecycleState.active,
      subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
    );
    final pkt = pocket('a0000000-0000-0000-0000-000000000002', 'Rent');
    final container = buildContainer(
      buildLedger(
        moneySources: {
          parent.id: MoneySource.account(parent),
          pkt.id: MoneySource.pocket(pkt),
        },
      ),
    );

    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .pockets
        .single;

    expect(row.name, 'Main/Rent');
  });

  test('a ledger change refreshes the row lists', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);

    ledger.restoreAccount(acc.id);

    expect(
      container.read(recycleBinViewModelProvider).value?.accounts,
      isEmpty,
    );
  });

  test('an unmounted view model stops listening to the ledger', () async {
    final ledger = ListenerTrackingLedger(LedgerState());
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    final mounted = container.listen(recycleBinViewModelProvider, (_, _) {});
    expect(ledger.isListened, isTrue);

    mounted.close();
    await container.pump();

    expect(ledger.isListened, isFalse);
  });

  test('a ledger change keeps the pending step', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;
    viewModel.requestPurge(row);

    ledger.restoreAccount(acc.id);

    final state = container.read(recycleBinViewModelProvider).value;
    expect(state?.accounts, isEmpty);
    expect(state?.step, isA<PurgeConfirmationRequested>());
  });
}

class ListenerTrackingLedger extends Ledger {
  ListenerTrackingLedger(LedgerState state) : super(state: state);

  bool get isListened => hasListeners;
}
