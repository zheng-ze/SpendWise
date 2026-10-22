import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/app_phase.dart';

import '../support/recording_ledger_store.dart';

void main() {
  final account = Account(name: 'acc', type: AccountType.savings);

  RecurringPlan duePlan() => RecurringPlan(
    template: EntryTemplate(
      amount: Decimal.fromInt(-25),
      name: 'rent',
      sourceID: account.id,
    ),
    frequency: RecurrenceFrequency.monthly,
    anchor: DateTime.utc(2026, 1, 15),
    lastResolvedDate: DateTime.utc(2026, 1, 15),
  );

  RecordingLedgerStore storeWithPlan() {
    final plan = duePlan();
    return RecordingLedgerStore(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        plans: {plan.id: plan},
      ),
      hasSeeded: true,
    );
  }

  AppBoot boot(RecordingLedgerStore store, {DateTime Function()? now}) =>
      AppBoot(
        createStore: () async => store,
        seedChanges: () => const [],
        now: now,
      );

  test('enteringReadyResolvesPlansExactlyOnceWithoutAResume', () async {
    final store = storeWithPlan();
    final clock = _FakeClock();

    final app = boot(store, now: clock.now);
    await app.start();

    expect(clock.reads, 1);
    expect((app.phase as Ready).ledger.state.entries, isNotEmpty);
  });

  test('everyResolveReceivesAUtcInstant', () async {
    final store = storeWithPlan();
    final seen = <DateTime>[];

    final app = boot(
      store,
      now: () {
        final instant = DateTime.now().toUtc();
        seen.add(instant);
        return instant;
      },
    );
    await app.start();
    app.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(seen, hasLength(2));
    for (final instant in seen) {
      expect(instant.isUtc, isTrue);
    }
  });

  test('theDefaultClockIsUtc', () {
    final app = AppBoot(
      createStore: () async => RecordingLedgerStore(hasSeeded: true),
      seedChanges: () => const [],
    );

    expect(app.now().isUtc, isTrue);
  });

  test('resumeResolvesPlans', () async {
    final store = storeWithPlan();
    final clock = _FakeClock();

    final app = boot(store, now: clock.now);
    await app.start();
    final atReady = clock.reads;

    app.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(clock.reads, atReady + 1);
  });

  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
  ]) {
    test('${state.name}Flushes', () async {
      final store = storeWithPlan();
      final app = boot(store);
      await app.start();
      store.calls.clear();

      app.didChangeAppLifecycleState(state);
      await Future<void>.delayed(Duration.zero);

      expect(store.calls, contains(StoreCall.flushNow));
    });
  }

  test('lifecycleCallbacksDoNothingWhileLoading', () async {
    final store = storeWithPlan();
    final clock = _FakeClock();
    final app = boot(store, now: clock.now);

    app.didChangeAppLifecycleState(AppLifecycleState.resumed);
    app.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);

    expect(clock.reads, 0);
    expect(store.calls, isNot(contains(StoreCall.flushNow)));
  });

  test('aFlushErrorDuringBackgroundingIsCaughtNotUnhandled', () async {
    final store = storeWithPlan()..failOn = StoreCall.flushNow;
    final app = boot(store);
    await app.start();

    final zoneErrors = <Object>[];
    await runZonedGuarded(() async {
      app.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
    }, (error, stackTrace) => zoneErrors.add(error));

    expect(zoneErrors, isEmpty);
  });

  test('lifecycleCallbacksDoNothingWhileFailed', () async {
    final store = storeWithPlan()..failOn = StoreCall.load;
    final clock = _FakeClock();
    final app = boot(store, now: clock.now);
    await app.start();
    expect(app.phase, isA<Failed>());
    store.calls.clear();

    app.didChangeAppLifecycleState(AppLifecycleState.resumed);
    app.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);

    expect(clock.reads, 0);
    expect(store.calls, isNot(contains(StoreCall.flushNow)));
  });
}

class _FakeClock {
  int reads = 0;

  DateTime now() {
    reads += 1;
    return DateTime.utc(2026, 8, 12, 9);
  }
}
