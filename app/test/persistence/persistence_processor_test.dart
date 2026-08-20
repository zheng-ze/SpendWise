import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/persistence_processor.dart';

import '../support/in_memory_ledger_store.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

Entry _entry(String sourceID) =>
    Entry(amount: Decimal.fromInt(-10), name: 'entry', sourceID: sourceID);

// Holds `start()` open until the test releases it, so a processor that awaited
// the store before subscribing would miss anything published in between.
class _GatedStore extends InMemoryLedgerStore {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> start() async {
    await gate.future;
    await super.start();
  }
}

void main() {
  test('committedFactsReachTheStore', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();

    final a = _account();
    final entry = Entry(
      amount: Decimal.fromInt(100),
      name: 'x',
      sourceID: a.id,
    );
    bus.publish([UpsertAccount(a), UpsertEntry(entry)]);
    await processor.flush();

    final loaded = await store.load();
    expect(loaded.moneySources[a.id]?.asAccount, a);
    expect(loaded.entries[entry.id], entry);
  });

  test('laterUpsertWinsWhenBatchesArriveInOrder', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();

    final first = _account(name: 'first');
    final renamed = Account(id: first.id, name: 'second', type: first.type);
    bus.publish([UpsertAccount(first)]);
    bus.publish([UpsertAccount(renamed)]);
    await processor.flush();

    final loaded = await store.load();
    expect(loaded.moneySources[first.id]?.asAccount?.name, 'second');
  });

  test('ledgerMutationPersistsThroughTheBus', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();
    final ledger = Ledger(bus: bus);

    final a = _account();
    ledger.addAccount(a);
    final entry = Entry(
      amount: Decimal.fromInt(-25),
      name: 'coffee',
      sourceID: a.id,
    );
    ledger.addEntry(entry);
    await processor.flush();

    final loaded = await store.load();
    expect(loaded.moneySources[a.id]?.asAccount, a);
    expect(loaded.entries[entry.id], entry);
  });

  test('rejectedLedgerMutationReachesNothing', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();
    final ledger = Ledger(bus: bus);

    expect(
      () => ledger.addEntry(_entry('4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43')),
      throwsA(isA<UnknownHolder>()),
    );
    await processor.flush();

    expect(store.enqueuedBatches, isEmpty);
    expect((await store.load()).entries, isEmpty);
  });

  test('disposeStopsForwardingToTheStore', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();

    final before = _account(name: 'before');
    bus.publish([UpsertAccount(before)]);
    await processor.dispose();
    bus.publish([UpsertAccount(_account(name: 'after'))]);
    await processor.flush();

    expect(store.enqueuedBatches, [
      [UpsertAccount(before)],
    ]);
  });

  test('disposeIsIdempotent', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();

    await processor.dispose();

    await expectLater(processor.dispose(), completes);
  });

  test('flushCompletesWithoutLosingPriorFacts', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();

    final first = _account(name: 'first');
    bus.publish([UpsertAccount(first)]);
    await processor.flush();

    final second = _account(name: 'second');
    bus.publish([UpsertAccount(second)]);
    await processor.flush();

    final loaded = await store.load();
    expect(loaded.moneySources[first.id]?.asAccount, first);
    expect(loaded.moneySources[second.id]?.asAccount, second);
  });

  test('flushDrivesTheStoreToDurability', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();

    final a = _account();
    bus.publish([UpsertAccount(a)]);

    expect((await store.load()).moneySources[a.id], isNull);
    await processor.flush();
    expect((await store.load()).moneySources[a.id]?.asAccount, a);
  });

  test('processorSubscribesBeforeStoreStartCompletes', () async {
    final bus = EventBus();
    final store = _GatedStore();
    final processor = PersistenceProcessor(store: store, bus: bus);

    final starting = processor.start();

    // Published while `start()` is still suspended on the gate. A subscription
    // taken only after the await would never see it.
    final early = _account(name: 'early');
    bus.publish([UpsertAccount(early)]);

    store.gate.complete();
    await starting;

    final late = _account(name: 'late');
    bus.publish([UpsertAccount(late)]);
    await processor.flush();

    final loaded = await store.load();
    expect(loaded.moneySources[early.id]?.asAccount, early);
    expect(loaded.moneySources[late.id]?.asAccount, late);
  });

  test('processorForwardsBatchesWithoutCoalescing', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();

    final a = _account(name: 'a');
    final b = _account(name: 'b');
    bus.publish([UpsertAccount(a)]);
    bus.publish([UpsertAccount(b), UpsertAccount(a)]);
    await processor.flush();

    expect(store.enqueuedBatches, [
      [UpsertAccount(a)],
      [UpsertAccount(b), UpsertAccount(a)],
    ]);
  });
}
