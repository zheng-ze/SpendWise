import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/app_phase.dart';

import '../support/recording_ledger_store.dart';

void main() {
  AppBoot boot(RecordingLedgerStore store) =>
      AppBoot(createStore: () async => store, seedChanges: () => const []);

  test('retryReturnsToLoadingAndRerunsEveryStepInOrder', () async {
    final store = RecordingLedgerStore(hasSeeded: true)
      ..failOn = StoreCall.load;
    final app = boot(store);
    await app.start();
    expect(app.phase, isA<Failed>());

    final phases = <AppPhase>[];
    app.addListener(() => phases.add(app.phase));
    store
      ..failOn = null
      ..calls.clear();

    await app.retry();

    expect(phases.first, isA<Loading>());
    expect(
      store.calls.where((call) => call != StoreCall.start).toList(),
      containsAllInOrder([
        StoreCall.setErrorHandler,
        StoreCall.seedIfFirstLaunch,
        StoreCall.load,
      ]),
    );
  });

  test('retryAfterAFailureThatThenSucceedsReachesReady', () async {
    final store = RecordingLedgerStore(hasSeeded: true)
      ..failOn = StoreCall.load;
    final app = boot(store);
    await app.start();
    expect(app.phase, isA<Failed>());

    store.failOn = null;
    await app.retry();

    expect(app.phase, isA<Ready>());
  });

  test('retryDisposesTheRuntimeFromASuccessfulBoot', () async {
    final store = RecordingLedgerStore(hasSeeded: true);
    final app = boot(store);
    await app.start();
    final stale = app.phase as Ready;

    await app.retry();

    expect(app.phase, isA<Ready>());
    expect((app.phase as Ready).ledger, isNot(same(stale.ledger)));
    expect(
      () => stale.ledger.addAccount(
        Account(name: 'after dispose', type: AccountType.savings),
      ),
      throwsFlutterError,
    );
  });

  test('retryClosesTheBusFromTheDiscardedRuntime', () async {
    final store = RecordingLedgerStore(hasSeeded: true);
    final app = boot(store);
    await app.start();
    final stale = app.phase as Ready;

    await app.retry();

    expect(
      () => stale.ledger.bus.publish([
        UpsertAccount(
          Account(name: 'after dispose', type: AccountType.savings),
        ),
      ]),
      throwsStateError,
    );
  });

  test(
    'aBootThatFailedAfterMintingTheBusLeavesNothingWiredToTheStore',
    () async {
      final store = RecordingLedgerStore(hasSeeded: true);
      final app = boot(store);
      // Fires inside PersistenceProcessor.start, after the bus exists but
      // before any Ready phase can carry it.
      store.failOn = StoreCall.start;
      await app.start();
      expect(app.phase, isA<Failed>());

      store.failOn = null;
      await app.retry();
      expect(app.phase, isA<Ready>());

      (app.phase as Ready).ledger.addAccount(
        Account(name: 'after retry', type: AccountType.savings),
      );
      await store.flushNow();

      // Two would mean the orphaned processor still holds a live subscription.
      expect(store.state.moneySources, hasLength(1));
    },
  );

  test('lifecycleActsThroughTheRuntimeFromTheLatestBoot', () async {
    final store = RecordingLedgerStore(hasSeeded: true);
    final app = boot(store);
    await app.start();
    final stale = app.phase as Ready;

    await app.retry();
    store.calls.clear();

    app.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);

    expect(store.calls, contains(StoreCall.flushNow));
    expect((app.phase as Ready).persistence, isNot(same(stale.persistence)));
  });
}
