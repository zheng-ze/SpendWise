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
  }) {
    return Ledger(
      state: LedgerState(
        moneySources: moneySources,
        categories: categories,
        entries: entries,
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

  test('empty ledger yields three empty row lists', () async {
    final container = buildContainer(buildLedger());
    await container.read(recycleBinViewModelProvider.future);

    final state = container.read(recycleBinViewModelProvider).value!;
    expect(state.accounts, isEmpty);
    expect(state.pockets, isEmpty);
    expect(state.categories, isEmpty);
  });

  test('archived accounts, pockets and categories are each listed, sorted '
      'by name', () async {
    final zebra = account('a0000000-0000-0000-0000-000000000001', 'Zebra');
    final alpha = account('a0000000-0000-0000-0000-000000000002', 'Alpha');
    final pkt = pocket('a0000000-0000-0000-0000-000000000003', 'Rent');
    final cat = category('a0000000-0000-0000-0000-000000000004', 'Old Cat');
    final ledger = buildLedger(
      moneySources: {
        zebra.id: MoneySource.account(zebra),
        alpha.id: MoneySource.account(alpha),
        pkt.id: MoneySource.pocket(pkt),
      },
      categories: {cat.id: cat},
    );
    final container = buildContainer(ledger);
    await container.read(recycleBinViewModelProvider.future);

    final state = container.read(recycleBinViewModelProvider).value!;
    expect(state.accounts.map((r) => r.name), ['Alpha', 'Zebra']);
    expect(state.pockets.map((r) => r.name), ['Rent']);
    expect(state.categories.map((r) => r.name), ['Old Cat']);
  });

  test('an active holder is excluded from its row list', () async {
    final acc = account(
      'a0000000-0000-0000-0000-000000000001',
      'Active One',
      lifecycle: LifecycleState.active,
    );
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    await container.read(recycleBinViewModelProvider.future);

    expect(
      container.read(recycleBinViewModelProvider).value!.accounts,
      isEmpty,
    );
  });

  test('a row shows how many entries reference it', () async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final entry = Entry(amount: dec('5'), name: 'x', sourceID: acc.id);
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
      entries: {entry.id: entry},
    );
    final container = buildContainer(ledger);
    await container.read(recycleBinViewModelProvider.future);

    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;
    expect(row.referenceCount, 1);
  });

  test(
    'a pocket row is named with its qualified name when parent resolves',
    () async {
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
      await container.read(recycleBinViewModelProvider.future);

      final row = container
          .read(recycleBinViewModelProvider)
          .value!
          .pockets
          .single;
      expect(row.name, 'Main/Rent');
    },
  );

  test('restore(account) reactivates the account', () async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    await container.read(recycleBinViewModelProvider.future);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.restore(BinRowKind.account, acc.id);

    expect(ledger.state.moneySources[acc.id]!.lifecycle, LifecycleState.active);
  });

  test('restore(pocket) is a no-op while the parent account is still '
      'archived', () async {
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
    await container.read(recycleBinViewModelProvider.future);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.restore(BinRowKind.pocket, pkt.id);

    expect(
      ledger.state.moneySources[pkt.id]!.lifecycle,
      LifecycleState.archived,
    );
  });

  test('restore(category) reactivates the category', () async {
    final cat = category('a0000000-0000-0000-0000-000000000004', 'Old Cat');
    final ledger = buildLedger(categories: {cat.id: cat});
    final container = buildContainer(ledger);
    await container.read(recycleBinViewModelProvider.future);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.restore(BinRowKind.category, cat.id);

    expect(ledger.state.categories[cat.id]!.lifecycle, LifecycleState.active);
  });

  test(
    'requestPurge emits PurgeConfirmationRequested carrying the row',
    () async {
      final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
      final ledger = buildLedger(
        moneySources: {acc.id: MoneySource.account(acc)},
      );
      final container = buildContainer(ledger);
      await container.read(recycleBinViewModelProvider.future);
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
    },
  );

  test(
    'applyPurgeConfirmed(true) purges the account and clears the step',
    () async {
      final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
      final ledger = buildLedger(
        moneySources: {acc.id: MoneySource.account(acc)},
      );
      final container = buildContainer(ledger);
      await container.read(recycleBinViewModelProvider.future);
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
    },
  );

  test('applyPurgeConfirmed(false) leaves the row untouched and clears the '
      'step', () async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    await container.read(recycleBinViewModelProvider.future);
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

  test('applyPurgeConfirmed(true) purges a pocket', () async {
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
    await container.read(recycleBinViewModelProvider.future);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.applyPurgeConfirmed(true, BinRowKind.pocket, pkt.id);

    expect(ledger.state.moneySources.containsKey(pkt.id), isFalse);
  });

  test('applyPurgeConfirmed(true) purges a category', () async {
    final cat = category('a0000000-0000-0000-0000-000000000004', 'Old Cat');
    final ledger = buildLedger(categories: {cat.id: cat});
    final container = buildContainer(ledger);
    await container.read(recycleBinViewModelProvider.future);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.applyPurgeConfirmed(true, BinRowKind.category, cat.id);

    expect(ledger.state.categories.containsKey(cat.id), isFalse);
  });

  test('clearStep resets the step to null', () async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    await container.read(recycleBinViewModelProvider.future);
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
}
