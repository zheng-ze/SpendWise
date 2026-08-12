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
