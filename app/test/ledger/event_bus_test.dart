import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/event_bus.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

void main() {
  test('subscriberReceivesPublishedBatch', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen(received.add);

    final a = _account();
    bus.publish([UpsertAccount(a)]);

    expect(received, hasLength(1));
    expect(received.first, [UpsertAccount(a)]);
  });

  test('batchArrivesAtomicallyNotFlattened', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen(received.add);

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
    bus.subscribe().listen(received.add);

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
    bus.subscribe().listen(first.add);
    bus.subscribe().listen(second.add);

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
    bus.subscribe().listen(received.add);

    bus.publish([]);
    final a = _account();
    bus.publish([UpsertAccount(a)]);

    expect(received, [
      [UpsertAccount(a)],
    ]);
  });

  // Swift pinned an unbounded per-subscriber buffer, so a batch published
  // before the consumer began reading was replayed to it. A Dart broadcast
  // stream has no such buffer and delivers only to attached listeners, so what
  // is pinned here is the property boot actually relies on: a listener attached
  // before the first publish loses nothing.
  test('bufferingIsLosslessBeforeConsumptionStarts', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen(received.add);

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
    bus.subscribe().listen(received.add);

    bus.publish([UpsertAccount(_account())]);

    expect(
      () => received.single.add(UpsertAccount(_account())),
      throwsUnsupportedError,
    );
  });

  test('cancelledSubscriberStopsReceiving', () async {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    final subscription = bus.subscribe().listen(received.add);

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
    bus.subscribe().listen((batch) {
      received.add(batch);
      if (batch.single != UpsertAccount(a)) return;
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
}
