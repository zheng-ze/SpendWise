import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_ledger_store.dart';
import 'ledger_fixtures.dart';

SubPocket _pocket(String id, String name) => SubPocket(id: id, name: name);

RecurringPlan _plan(String id) => RecurringPlan(
  id: id,
  template: EntryTemplate(
    amount: Decimal.parse('25'),
    name: 'rent',
    sourceID: 'a1',
  ),
  frequency: RecurrenceFrequency.monthly,
  anchor: DateTime.utc(2026, 1, 1),
  lastResolvedDate: DateTime.utc(2026, 1, 1),
);

void main() {
  test('a drained upsert reaches the state of every kind', () async {
    final store = InMemoryLedgerStore();
    store.enqueue([
      UpsertAccount(
        testAccount(id: 'a1', name: 'wallet', type: AccountType.cash),
      ),
      UpsertPocket(_pocket('p1', 'rainy day')),
      UpsertCategory(
        testCategory(
          id: 'c1',
          name: 'food',
          colorHex: '#ff0000',
          symbol: 'fork',
        ),
      ),
      UpsertEntry(
        testEntry(
          id: 'e1',
          sourceID: 'a1',
          amount: Decimal.parse('12.34'),
          name: 'e-e1',
          date: DateTime.utc(2026, 3, 14),
        ),
      ),
      UpsertPlan(_plan('pl1')),
    ]);

    await store.flushNow();

    expect(store.state.moneySources['a1']?.asAccount?.name, 'wallet');
    expect(store.state.moneySources['p1']?.asPocket?.name, 'rainy day');
    expect(store.state.categories['c1']?.name, 'food');
    expect(store.state.entries['e1']?.amount, Decimal.parse('12.34'));
    expect(store.state.plans['pl1']?.template.name, 'rent');
  });

  test('a drained delete removes from the state of every kind', () async {
    final store = InMemoryLedgerStore();
    store.enqueue([
      UpsertAccount(
        testAccount(id: 'a1', name: 'wallet', type: AccountType.cash),
      ),
      UpsertPocket(_pocket('p1', 'rainy day')),
      UpsertCategory(
        testCategory(
          id: 'c1',
          name: 'food',
          colorHex: '#ff0000',
          symbol: 'fork',
        ),
      ),
      UpsertEntry(
        testEntry(
          id: 'e1',
          sourceID: 'a1',
          amount: Decimal.parse('12.34'),
          name: 'e-e1',
          date: DateTime.utc(2026, 3, 14),
        ),
      ),
      UpsertPlan(_plan('pl1')),
    ]);
    await store.flushNow();

    store.enqueue([
      const DeleteMoneySource('a1'),
      const DeleteMoneySource('p1'),
      const DeleteCategory('c1'),
      const DeleteEntry('e1'),
      const DeletePlan('pl1'),
    ]);
    await store.flushNow();

    expect(store.state.moneySources, isEmpty);
    expect(store.state.categories, isEmpty);
    expect(store.state.entries, isEmpty);
    expect(store.state.plans, isEmpty);
  });

  test('archive, restore and purge move an entry between the maps', () async {
    final store = InMemoryLedgerStore();
    final active = testEntry(
      id: 'e1',
      sourceID: 'a1',
      amount: Decimal.parse('12.34'),
      name: 'e-e1',
      date: DateTime.utc(2026, 3, 14),
    );
    store.enqueue([UpsertEntry(active)]);
    await store.flushNow();

    store.enqueue([
      UpsertEntry(active.settingLifecycle(LifecycleState.archived)),
    ]);
    await store.flushNow();
    expect(store.state.entries, isEmpty);
    expect(store.state.binnedEntries.keys.toSet(), {'e1'});

    store.enqueue([UpsertEntry(active)]);
    await store.flushNow();
    expect(store.state.binnedEntries, isEmpty);
    expect(store.state.entries.keys.toSet(), {'e1'});

    store.enqueue([
      UpsertEntry(active.settingLifecycle(LifecycleState.archived)),
    ]);
    store.enqueue([const DeleteEntry('e1')]);
    await store.flushNow();
    expect(store.state.binnedEntries, isEmpty);
    expect(store.state.entries, isEmpty);
  });

  test('a later upsert of one id replaces the earlier one', () async {
    final store = InMemoryLedgerStore();
    store.enqueue([
      UpsertAccount(
        testAccount(id: 'a1', name: 'first', type: AccountType.cash),
      ),
    ]);
    store.enqueue([
      UpsertAccount(
        testAccount(id: 'a1', name: 'second', type: AccountType.cash),
      ),
    ]);

    await store.flushNow();

    expect(store.state.moneySources.keys.toSet(), {'a1'});
    expect(store.state.moneySources['a1']?.asAccount?.name, 'second');
  });

  test('enqueued changes stay out of the state until a flush', () async {
    final store = InMemoryLedgerStore();
    store.enqueue([
      UpsertAccount(
        testAccount(id: 'a1', name: 'wallet', type: AccountType.cash),
      ),
    ]);

    expect(store.state.moneySources, isEmpty);

    await store.flushNow();

    expect(store.state.moneySources.keys.toSet(), {'a1'});
  });

  test('batches drain in the order they were enqueued', () async {
    final store = InMemoryLedgerStore();
    store.enqueue([
      UpsertAccount(
        testAccount(id: 'a1', name: 'first', type: AccountType.cash),
      ),
    ]);
    store.enqueue([const DeleteMoneySource('a1')]);
    store.enqueue([
      UpsertAccount(
        testAccount(id: 'a1', name: 'third', type: AccountType.cash),
      ),
    ]);

    await store.flushNow();

    expect(store.state.moneySources['a1']?.asAccount?.name, 'third');
  });

  test('a flush with nothing enqueued leaves the state alone', () async {
    final store = InMemoryLedgerStore();
    store.enqueue([
      UpsertAccount(
        testAccount(id: 'a1', name: 'wallet', type: AccountType.cash),
      ),
    ]);
    store.enqueue([const DeleteMoneySource('a1')]);
    await store.flushNow();

    await store.flushNow();

    expect(store.state.moneySources, isEmpty);
  });

  test('the state carries an opening balance the store was built on', () async {
    final opening = LedgerState();
    opening.apply([
      UpsertAccount(
        testAccount(id: 'a1', name: 'wallet', type: AccountType.cash),
      ),
    ]);

    final store = InMemoryLedgerStore(state: opening);
    store.enqueue([
      UpsertEntry(
        testEntry(
          id: 'e1',
          sourceID: 'a1',
          amount: Decimal.parse('12.34'),
          name: 'e-e1',
          date: DateTime.utc(2026, 3, 14),
        ),
      ),
    ]);
    await store.flushNow();

    expect(store.state.moneySources.keys.toSet(), {'a1'});
    expect(store.state.entries.keys.toSet(), {'e1'});
  });

  test('load returns the same state the drain mutates', () async {
    final store = InMemoryLedgerStore();
    store.enqueue([
      UpsertAccount(
        testAccount(id: 'a1', name: 'wallet', type: AccountType.cash),
      ),
    ]);
    await store.flushNow();

    expect((await store.load()).moneySources.keys.toSet(), {'a1'});
  });

  test(
    'enqueuedBatches keeps batch boundaries the drained state merges away',
    () async {
      final store = InMemoryLedgerStore();
      store.enqueue([
        UpsertAccount(
          testAccount(id: 'a1', name: 'first', type: AccountType.cash),
        ),
      ]);
      store.enqueue([
        UpsertAccount(
          testAccount(id: 'a1', name: 'second', type: AccountType.cash),
        ),
      ]);

      await store.flushNow();

      expect(store.enqueuedBatches, [
        [
          UpsertAccount(
            testAccount(id: 'a1', name: 'first', type: AccountType.cash),
          ),
        ],
        [
          UpsertAccount(
            testAccount(id: 'a1', name: 'second', type: AccountType.cash),
          ),
        ],
      ]);
      expect(store.state.moneySources.keys.toSet(), {'a1'});
      expect(store.state.moneySources['a1']?.asAccount?.name, 'second');
    },
  );
}
