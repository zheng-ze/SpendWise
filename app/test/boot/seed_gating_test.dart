import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/app_phase.dart';

import '../support/in_memory_ledger_store.dart';
import '../support/ledger_fixtures.dart';
import '../support/recording_ledger_store.dart';

void main() {
  test('firstLaunchSeedsAndFlushesBeforeLoad', () async {
    final store = RecordingLedgerStore();
    final account = testAccount(name: 'seeded');

    await AppBoot(
      createStore: () async => store,
      seedChanges: () => [UpsertAccount(account)],
    ).start();

    expect(
      store.calls,
      containsAllInOrder([
        StoreCall.seedIfFirstLaunch,
        StoreCall.flushNow,
        StoreCall.load,
      ]),
    );
    expect(store.state.moneySources, contains(account.id));
  });

  test('seedIsNotRepeatedOnASecondLaunch', () async {
    final store = InMemoryLedgerStore();
    final account = testAccount(name: 'seeded');
    List<LedgerChange> seed() => [UpsertAccount(account)];

    await AppBoot(createStore: () async => store, seedChanges: seed).start();
    final afterFirst = store.enqueuedBatches.length;

    await AppBoot(createStore: () async => store, seedChanges: seed).start();

    expect(store.enqueuedBatches, hasLength(afterFirst));
  });

  test('anEmptiedLedgerIsNotReseeded', () async {
    final store = InMemoryLedgerStore();
    final account = testAccount(name: 'seeded');
    List<LedgerChange> seed() => [UpsertAccount(account)];

    final first = AppBoot(createStore: () async => store, seedChanges: seed);
    await first.start();

    final ready = first.phase as Ready;
    ready.ledger.deleteAccount(account.id);
    ready.ledger.purgeAccount(account.id);
    await ready.persistence.flush();
    expect(store.state.moneySources, isEmpty);

    final second = AppBoot(createStore: () async => store, seedChanges: seed);
    await second.start();

    expect((second.phase as Ready).ledger.state.moneySources, isEmpty);
    expect(store.state.moneySources, isEmpty);
  });

  test('seedIsSkippedWhenTheFlagIsAlreadySet', () async {
    final store = RecordingLedgerStore(hasSeeded: true);
    var built = 0;

    await AppBoot(
      createStore: () async => store,
      seedChanges: () {
        built += 1;
        return [UpsertAccount(testAccount(name: 'seeded'))];
      },
    ).start();

    expect(store.state.moneySources, isEmpty);
    expect(store.calls, isNot(contains(StoreCall.flushNow)));
    expect(built, 1);
  });
}
