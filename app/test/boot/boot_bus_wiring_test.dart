import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/app_phase.dart';

import '../support/in_memory_ledger_store.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

Entry _entry(String sourceID) =>
    Entry(amount: Decimal.fromInt(-10), name: 'entry', sourceID: sourceID);

Future<Ready> _bootReady(InMemoryLedgerStore store) async {
  final boot = AppBoot(
    createStore: () async => store,
    seedChanges: () => const [],
  );
  await boot.start();
  return boot.phase as Ready;
}

void main() {
  test('theLedgerPublishesOntoTheBusTheProcessorSubscribedTo', () async {
    final store = InMemoryLedgerStore(hasSeeded: true);
    final ready = await _bootReady(store);

    expect(ready.ledger.bus, same(ready.persistence.bus));
  });

  test('theVeryFirstMutationAfterBootIsPersisted', () async {
    final store = InMemoryLedgerStore(hasSeeded: true);
    final ready = await _bootReady(store);

    final account = _account();
    ready.ledger.addAccount(account);

    expect(store.enqueuedBatches, hasLength(1));
    expect(store.enqueuedBatches.single, hasLength(1));

    await ready.persistence.flush();
    expect(store.state.moneySources, contains(account.id));
  });

  test('everyMutationAfterBootReachesTheStoreInOrder', () async {
    final store = InMemoryLedgerStore(hasSeeded: true);
    final ready = await _bootReady(store);

    final account = _account();
    ready.ledger.addAccount(account);
    final entry = _entry(account.id);
    ready.ledger.addEntry(entry);
    await ready.persistence.flush();

    expect(store.enqueuedBatches, hasLength(2));
    expect(store.state.entries, contains(entry.id));
  });
}
