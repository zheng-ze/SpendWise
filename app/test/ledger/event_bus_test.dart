import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:sync/sync.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

void main() {
  test('subscriberReceivesPublishedBatch', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen((publication) => received.add(publication.changes));

    final a = _account();
    bus.publish([UpsertAccount(a)]);

    expect(received, hasLength(1));
    expect(received.first, [UpsertAccount(a)]);
  });

  test('batchArrivesAtomicallyNotFlattened', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen((publication) => received.add(publication.changes));

    final a = _account();
    final entry = Entry(amount: Decimal.fromInt(10), name: 'x', sourceID: a.id);
    bus.publish([UpsertAccount(a), UpsertEntry(entry)]);

    expect(received, [
      [UpsertAccount(a), UpsertEntry(entry)],
    ]);
  });

  test('ordersBatchesInPublishOrder', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen((publication) => received.add(publication.changes));

    final a = _account(name: 'a');
    final b = _account(name: 'b');
    final c = _account(name: 'c');
    bus.publish([UpsertAccount(a)]);
    bus.publish([UpsertAccount(b)]);
    bus.publish([UpsertAccount(c)]);

    expect(received, [
      [UpsertAccount(a)],
      [UpsertAccount(b)],
      [UpsertAccount(c)],
    ]);
  });

  test('everySubscriberSeesEveryBatch', () {
    final bus = EventBus();
    final first = <List<LedgerChange>>[];
    final second = <List<LedgerChange>>[];
    bus.subscribe().listen((publication) => first.add(publication.changes));
    bus.subscribe().listen((publication) => second.add(publication.changes));

    final a = _account();
    bus.publish([UpsertAccount(a)]);

    expect(first, [
      [UpsertAccount(a)],
    ]);
    expect(second, [
      [UpsertAccount(a)],
    ]);
  });

  test('emptyBatchIsNotDelivered', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen((publication) => received.add(publication.changes));

    bus.publish([]);
    final a = _account();
    bus.publish([UpsertAccount(a)]);

    expect(received, [
      [UpsertAccount(a)],
    ]);
  });

  // A listener attached before the first publish must still receive it.
  test('bufferingIsLosslessBeforeConsumptionStarts', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen((publication) => received.add(publication.changes));

    final a = _account(name: 'a');
    final b = _account(name: 'b');
    bus.publish([UpsertAccount(a)]);
    bus.publish([UpsertAccount(b)]);

    expect(received, [
      [UpsertAccount(a)],
      [UpsertAccount(b)],
    ]);
  });

  test('publishedBatchIsUnmodifiableByASubscriber', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen((publication) => received.add(publication.changes));

    bus.publish([UpsertAccount(_account())]);

    expect(
      () => received.single.add(UpsertAccount(_account())),
      throwsUnsupportedError,
    );
  });

  test('cancelledSubscriberStopsReceiving', () async {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    final subscription = bus.subscribe().listen(
      (publication) => received.add(publication.changes),
    );

    final a = _account(name: 'a');
    bus.publish([UpsertAccount(a)]);
    await subscription.cancel();
    bus.publish([UpsertAccount(_account(name: 'b'))]);

    expect(received, [
      [UpsertAccount(a)],
    ]);
  });

  test('publishAfterDisposeThrows', () async {
    final bus = EventBus();
    bus.subscribe().listen((_) {});

    await bus.dispose();

    expect(() => bus.publish([UpsertAccount(_account())]), throwsStateError);
  });

  test('reentrantPublishFromSubscriberThrows', () {
    final bus = EventBus();
    final a = _account(name: 'a');
    final b = _account(name: 'b');
    final received = <List<LedgerChange>>[];
    Object? caught;
    bus.subscribe().listen((publication) {
      received.add(publication.changes);
      if (publication.changes.single != UpsertAccount(a)) return;
      try {
        bus.publish([UpsertAccount(b)]);
      } on Object catch (error) {
        caught = error;
      }
    });

    bus.publish([UpsertAccount(a)]);

    expect(caught, isStateError);
    expect(received, [
      [UpsertAccount(a)],
    ]);
  });

  test('ordinaryPublicationCarriesNoStamps', () {
    final bus = EventBus();
    final publications = <LedgerPublication>[];
    bus.subscribe().listen(publications.add);

    bus.publish([UpsertAccount(_account())]);

    expect(publications, hasLength(1));
    expect(publications.single.stamps, isNull);
    expect(publications.single.hasStamps, isFalse);
  });

  test('stampedPublicationDeliversStamps', () {
    final bus = EventBus();
    final publications = <LedgerPublication>[];
    bus.subscribe().listen(publications.add);

    final account = _account();
    final row = SyncRowID.of(SyncCollection.moneySources, account.id);
    final stamps = {
      row: VersionVector({'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa': 3}),
    };
    bus.publish([UpsertAccount(account)], stamps: stamps);

    expect(publications, hasLength(1));
    expect(publications.single.changes, [UpsertAccount(account)]);
    expect(publications.single.stamps, stamps);
    expect(publications.single.hasStamps, isTrue);
  });

  test('publishedStampsAreUnmodifiableByASubscriber', () {
    final bus = EventBus();
    final publications = <LedgerPublication>[];
    bus.subscribe().listen(publications.add);

    final account = _account();
    final row = SyncRowID.of(SyncCollection.moneySources, account.id);
    bus.publish(
      [UpsertAccount(account)],
      stamps: {
        row: VersionVector({'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa': 3}),
      },
    );

    final other = SyncRowID.of(
      SyncCollection.entries,
      '4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43',
    );
    expect(
      () => publications.single.stamps![other] = VersionVector.empty,
      throwsUnsupportedError,
    );
  });

  test('emptyChangesWithStampsIsNotDelivered', () {
    final bus = EventBus();
    final publications = <LedgerPublication>[];
    bus.subscribe().listen(publications.add);

    final row = SyncRowID.of(
      SyncCollection.moneySources,
      '4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43',
    );
    bus.publish([], stamps: {row: VersionVector.empty});
    bus.publish([UpsertAccount(_account())]);

    expect(publications, hasLength(1));
    expect(publications.single.stamps, isNull);
  });

  test('deliveryIsSynchronous', () {
    final bus = EventBus();
    var delivered = false;
    bus.subscribe().listen((_) => delivered = true);

    bus.publish([UpsertAccount(_account())]);

    expect(delivered, isTrue);
  });
}
