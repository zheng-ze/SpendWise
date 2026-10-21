import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/store/persistence_processor.dart';
import 'package:sync/sync.dart';

import '../support/in_memory_ledger_store.dart';

Account _account() => Account(name: 'acc', type: AccountType.savings);

void main() {
  test(
    'ledger changes reach durable state through the publication bus',
    () async {
      final bus = EventBus();
      final store = InMemoryLedgerStore();
      final processor = PersistenceProcessor(store: store, bus: bus);
      await processor.start();
      final ledger = Ledger(bus: bus);
      final account = _account();
      ledger.addAccount(account);
      final entry = Entry(
        amount: Decimal.fromInt(-25),
        name: 'coffee',
        sourceID: account.id,
      );
      ledger.addEntry(entry);

      await processor.flush();

      final loaded = await store.load();
      expect(loaded.moneySources[account.id]?.asAccount, account);
      expect(loaded.entries[entry.id], entry);
    },
  );

  test('rejected ledger changes never reach persistence', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();

    expect(
      () => Ledger(bus: bus).addEntry(
        Entry(
          amount: Decimal.fromInt(-10),
          name: 'entry',
          sourceID: '4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43',
        ),
      ),
      throwsA(isA<UnknownHolder>()),
    );
    await processor.flush();

    expect((await store.load()).entries, isEmpty);
  });

  test(
    'stamped publications preserve their stamps at the store boundary',
    () async {
      final bus = EventBus();
      final store = InMemoryLedgerStore();
      final processor = PersistenceProcessor(store: store, bus: bus);
      await processor.start();
      final account = _account();
      final stamps = {
        SyncRowID.of(SyncCollection.moneySources, account.id): VersionVector({
          'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa': 3,
        }),
      };

      bus.publish([UpsertAccount(account)], stamps: stamps);
      await processor.flush();

      expect(store.enqueuedStamps.single, stamps);
      expect((await store.load()).moneySources[account.id]?.asAccount, account);
    },
  );

  test('disposing stops future publications from reaching the store', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();
    final before = _account();
    bus.publish([UpsertAccount(before)]);
    await processor.dispose();
    bus.publish([UpsertAccount(_account())]);
    await processor.flush();

    final loaded = await store.load();
    expect(loaded.moneySources[before.id]?.asAccount, before);
    expect(loaded.moneySources, hasLength(1));
  });
}
