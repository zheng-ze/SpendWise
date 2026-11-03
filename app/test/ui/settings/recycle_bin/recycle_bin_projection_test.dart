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

  test('empty ledger yields three empty row lists', () {
    final container = buildContainer(buildLedger());

    final projection = container
        .read(recycleBinProjectionProvider)
        .requireValue;

    expect(projection.accounts, isEmpty);
    expect(projection.pockets, isEmpty);
    expect(projection.categories, isEmpty);
  });

  test('archived accounts, pockets and categories are each listed, sorted '
      'by name', () {
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

    final projection = container
        .read(recycleBinProjectionProvider)
        .requireValue;
    expect(projection.accounts.map((r) => r.name), ['Alpha', 'Zebra']);
    expect(projection.pockets.map((r) => r.name), ['Rent']);
    expect(projection.categories.map((r) => r.name), ['Old Cat']);
  });

  test('an active holder is excluded from its row list', () {
    final acc = account(
      'a0000000-0000-0000-0000-000000000001',
      'Active One',
      lifecycle: LifecycleState.active,
    );
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);

    expect(
      container.read(recycleBinProjectionProvider).requireValue.accounts,
      isEmpty,
    );
  });

  test('a row shows how many entries reference it', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final entry = Entry(amount: dec('5'), name: 'x', sourceID: acc.id);
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
      entries: {entry.id: entry},
    );
    final container = buildContainer(ledger);

    final row = container
        .read(recycleBinProjectionProvider)
        .requireValue
        .accounts
        .single;
    expect(row.referenceCount, 1);
  });

  test(
    'a pocket row is named with its qualified name when parent resolves',
    () {
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

      final row = container
          .read(recycleBinProjectionProvider)
          .requireValue
          .pockets
          .single;
      expect(row.name, 'Main/Rent');
    },
  );

  test('a ledger change refreshes the row lists', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    container.listen(recycleBinProjectionProvider, (previous, next) {});

    ledger.restoreAccount(acc.id);

    expect(
      container.read(recycleBinProjectionProvider).requireValue.accounts,
      isEmpty,
    );
  });
}
