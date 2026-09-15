import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:sync/sync.dart';

import '../support/in_memory_ledger_store.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

TransactionCategory _category({String name = 'cat'}) => TransactionCategory(
  name: name,
  kind: CategoryKind.expense,
  colorHex: '#000000',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'tag',
);

Entry _entry(String sourceID, {String? categoryID}) => Entry(
  amount: Decimal.fromInt(-10),
  name: 'entry',
  sourceID: sourceID,
  categoryID: categoryID,
);

VersionVector _stamp(int counter) =>
    VersionVector({'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa': counter});

void main() {
  test('validMultiRowBatchAdoptsOnceWithExactCounts', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();
    final ledger = Ledger(bus: bus);

    final publications = <LedgerPublication>[];
    bus.subscribe().listen(publications.add);
    var notifications = 0;
    ledger.addListener(() => notifications++);

    final account = _account();
    final category = _category();
    final entry = _entry(account.id, categoryID: category.id);
    final changes = <LedgerChange>[
      UpsertAccount(account),
      UpsertCategory(category),
      UpsertEntry(entry),
    ];
    final stamps = {
      SyncRowID.of(SyncCollection.moneySources, account.id): _stamp(3),
      SyncRowID.of(SyncCollection.categories, category.id): _stamp(2),
      SyncRowID.of(SyncCollection.entries, entry.id): _stamp(1),
    };
    final before = ledger.state;

    final returned = ledger.applySyncBatch(changes, stamps);

    // The live object is refilled in place, not swapped.
    expect(identical(ledger.state, before), isTrue);
    expect(returned, changes);
    expect(ledger.state.moneySources[account.id]?.asAccount, account);
    expect(ledger.state.categories[category.id], category);
    expect(ledger.state.entries[entry.id], entry);

    // Exactly one composite-stamped publication, one stamped enqueue, one
    // notification.
    expect(publications, hasLength(1));
    expect(publications.single.changes, changes);
    expect(publications.single.stamps, stamps);
    expect(publications.single.hasStamps, isTrue);
    expect(store.enqueuedBatches, [changes]);
    expect(store.enqueuedStamps, [stamps]);
    expect(notifications, 1);

    await processor.dispose();
  });

  test('invalidBatchChangesNothing', () async {
    final bus = EventBus();
    final store = InMemoryLedgerStore();
    final processor = PersistenceProcessor(store: store, bus: bus);
    await processor.start();
    final ledger = Ledger(bus: bus);

    final publications = <LedgerPublication>[];
    bus.subscribe().listen(publications.add);
    var notifications = 0;
    ledger.addListener(() => notifications++);

    final orphan = _entry('4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43');
    final stamps = {SyncRowID.of(SyncCollection.entries, orphan.id): _stamp(1)};

    expect(
      () => ledger.applySyncBatch([UpsertEntry(orphan)], stamps),
      throwsA(isA<StateError>()),
    );

    expect(ledger.state.moneySources, isEmpty);
    expect(ledger.state.entries, isEmpty);
    expect(publications, isEmpty);
    expect(store.enqueuedBatches, isEmpty);
    expect(notifications, 0);

    await processor.dispose();
  });

  test('unseenLifecycleTransitionPassesAndRefreshesTheBaseline', () {
    final ledger = Ledger();

    // Local history ends at referenceOnly: the account was deleted, then
    // purged while still referenced by an entry.
    final account = _account();
    ledger.addAccount(account);
    ledger.addEntry(_entry(account.id));
    ledger.deleteAccount(account.id);
    ledger.purgeAccount(account.id);
    expect(
      ledger.state.moneySources[account.id]?.lifecycle,
      LifecycleState.referenceOnly,
    );

    // Another device restored the row; this device never observed the
    // referenceOnly-to-active move, but the row is structurally sound.
    final publications = <LedgerPublication>[];
    ledger.bus.subscribe().listen(publications.add);
    var notifications = 0;
    ledger.addListener(() => notifications++);
    final restored = Account(
      id: account.id,
      name: account.name,
      type: account.type,
    );
    final stamps = {
      SyncRowID.of(SyncCollection.moneySources, account.id): _stamp(5),
    };

    ledger.applySyncBatch([UpsertAccount(restored)], stamps);

    expect(
      ledger.state.moneySources[account.id]?.lifecycle,
      LifecycleState.active,
    );
    expect(publications, hasLength(1));
    expect(publications.single.hasStamps, isTrue);
    expect(notifications, 1);

    // The lifecycle baseline moved to the post-sync state: a local delete
    // now judges active-to-archived, instead of throwing clause 12 against
    // the stale referenceOnly baseline.
    ledger.deleteAccount(account.id);
    expect(
      ledger.state.moneySources[account.id]?.lifecycle,
      LifecycleState.archived,
    );
  });
}
