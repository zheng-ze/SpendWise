import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/event_bus.dart';

import '../support/ledger_fixtures.dart';

void main() {
  test('subscriberReceivesPublishedBatch', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen(received.add);

    final a = testAccount();
    bus.publish([UpsertAccount(a)]);

    expect(received, hasLength(1));
    expect(received.first, [UpsertAccount(a)]);
  });

  test('batchArrivesAtomicallyNotFlattened', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen(received.add);

    final a = testAccount();
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

    final a = testAccount(name: 'a');
    final b = testAccount(name: 'b');
    final c = testAccount(name: 'c');
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

    final a = testAccount();
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
    final a = testAccount();
    bus.publish([UpsertAccount(a)]);

    expect(received, [
      [UpsertAccount(a)],
    ]);
  });

  test('bufferingIsLosslessBeforeConsumptionStarts', () {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    bus.subscribe().listen(received.add);

    final a = testAccount(name: 'a');
    final b = testAccount(name: 'b');
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

    bus.publish([UpsertAccount(testAccount())]);

    expect(
      () => received.single.add(UpsertAccount(testAccount())),
      throwsUnsupportedError,
    );
  });

  test('cancelledSubscriberStopsReceiving', () async {
    final bus = EventBus();
    final received = <List<LedgerChange>>[];
    final subscription = bus.subscribe().listen(received.add);

    final a = testAccount(name: 'a');
    bus.publish([UpsertAccount(a)]);
    await subscription.cancel();
    bus.publish([UpsertAccount(testAccount(name: 'b'))]);

    expect(received, [
      [UpsertAccount(a)],
    ]);
  });

  test('publishAfterDisposeThrows', () async {
    final bus = EventBus();
    bus.subscribe().listen((_) {});

    await bus.dispose();

    expect(() => bus.publish([UpsertAccount(testAccount())]), throwsStateError);
  });

  test('reentrantPublishFromSubscriberThrows', () {
    final bus = EventBus();
    final a = testAccount(name: 'a');
    final b = testAccount(name: 'b');
    final received = <List<LedgerChange>>[];
    Object? caught;
    bus.subscribe().listen((changes) {
      received.add(changes);
      if (changes.single != UpsertAccount(a)) return;
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

  test('deliveryIsSynchronous', () {
    final bus = EventBus();
    var delivered = false;
    bus.subscribe().listen((_) => delivered = true);

    bus.publish([UpsertAccount(testAccount())]);

    expect(delivered, isTrue);
  });
}
