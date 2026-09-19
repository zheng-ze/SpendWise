import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/sync_run_scheduler.dart';

/// Hand-written fake for the injected run-pass callback.
///
/// Each invocation records a call and returns a gate future the test
/// completes explicitly, so the test controls exactly when a pass finishes.
final class FakeRunPass {
  int calls = 0;
  final List<Completer<void>> gates = <Completer<void>>[];

  Future<void> call() {
    calls += 1;
    final gate = Completer<void>();
    gates.add(gate);
    return gate.future;
  }

  void completeOldest() {
    final gate = gates.removeAt(0);
    gate.complete();
  }

  bool get hasPendingPass => gates.isNotEmpty;
}

Future<void> pumpScheduler() => Future<void>.delayed(Duration.zero);

SyncRunScheduler schedulerWith({
  required FakeRunPass fake,
  required List<bool> statuses,
}) {
  return SyncRunScheduler(runPass: fake.call, onStatusChanged: statuses.add);
}

void main() {
  group('SyncRunScheduler requestRun', () {
    test(
      'a single trigger with no active pass starts exactly one pass',
      () async {
        final fake = FakeRunPass();
        final statuses = <bool>[];
        final scheduler = schedulerWith(fake: fake, statuses: statuses);

        scheduler.requestRun();
        await pumpScheduler();

        expect(fake.calls, 1);

        fake.completeOldest();
        await pumpScheduler();

        expect(fake.calls, 1);
        expect(statuses, <bool>[true, false]);
      },
    );

    test(
      'rapid repeated triggers while active queue exactly one trailing pass',
      () async {
        final fake = FakeRunPass();
        final statuses = <bool>[];
        final scheduler = schedulerWith(fake: fake, statuses: statuses);

        scheduler.requestRun();
        await pumpScheduler();

        scheduler.requestRun();
        scheduler.requestRun();
        scheduler.requestRun();
        await pumpScheduler();

        expect(fake.calls, 1);

        fake.completeOldest();
        await pumpScheduler();

        expect(fake.calls, 2);

        fake.completeOldest();
        await pumpScheduler();

        expect(fake.calls, 2);
        expect(statuses, <bool>[true, false]);
      },
    );

    test('triggers once both slots are full are no-ops', () async {
      final fake = FakeRunPass();
      final statuses = <bool>[];
      final scheduler = schedulerWith(fake: fake, statuses: statuses);

      scheduler.requestRun();
      await pumpScheduler();

      scheduler.requestRun();
      scheduler.requestRun();
      scheduler.requestRun();
      scheduler.requestRun();
      await pumpScheduler();

      fake.completeOldest();
      await pumpScheduler();
      expect(fake.calls, 2);

      fake.completeOldest();
      await pumpScheduler();
      expect(fake.calls, 2);
      expect(statuses, <bool>[true, false]);

      // The scheduler is reusable once idle: a later trigger starts a pass.
      scheduler.requestRun();
      await pumpScheduler();
      expect(fake.calls, 3);

      fake.completeOldest();
      await pumpScheduler();
      expect(statuses, <bool>[true, false, true, false]);
    });
  });

  group('SyncRunScheduler runNow', () {
    test(
      'with no active pass starts a pass and resolves on completion',
      () async {
        final fake = FakeRunPass();
        final statuses = <bool>[];
        final scheduler = schedulerWith(fake: fake, statuses: statuses);

        var resolved = false;
        final pending = scheduler.runNow();
        unawaited(
          pending.then((_) {
            resolved = true;
          }),
        );
        await pumpScheduler();

        expect(fake.calls, 1);
        expect(resolved, isFalse);

        fake.completeOldest();
        await pending;

        expect(resolved, isTrue);
        expect(statuses, <bool>[true, false]);
      },
    );

    test(
      'resolves after the first pass even when a trailing pass is queued',
      () async {
        final fake = FakeRunPass();
        final statuses = <bool>[];
        final scheduler = schedulerWith(fake: fake, statuses: statuses);

        final pending = scheduler.runNow();
        await pumpScheduler();

        scheduler.requestRun();
        await pumpScheduler();
        expect(fake.calls, 1);

        fake.completeOldest();
        await pending;
        expect(fake.hasPendingPass, isTrue);

        fake.completeOldest();
        await pumpScheduler();
        expect(fake.calls, 2);
        expect(statuses, <bool>[true, false]);
      },
    );

    test('while active joins the trailing slot queued by a trigger, '
        'resolving only after the trailing pass', () async {
      final fake = FakeRunPass();
      final statuses = <bool>[];
      final scheduler = schedulerWith(fake: fake, statuses: statuses);

      scheduler.requestRun();
      await pumpScheduler();

      scheduler.requestRun();
      final joined = scheduler.runNow();
      var joinedResolved = false;
      unawaited(
        joined.then((_) {
          joinedResolved = true;
        }),
      );
      await pumpScheduler();
      expect(fake.calls, 1);

      fake.completeOldest();
      await pumpScheduler();

      expect(joinedResolved, isFalse);
      expect(fake.calls, 2);

      fake.completeOldest();
      await joined;

      expect(joinedResolved, isTrue);
      expect(fake.calls, 2);
    });

    test('two overlapping joins share one coalesced trailing pass', () async {
      final fake = FakeRunPass();
      final statuses = <bool>[];
      final scheduler = schedulerWith(fake: fake, statuses: statuses);

      scheduler.requestRun();
      await pumpScheduler();

      final first = scheduler.runNow();
      final second = scheduler.runNow();
      await pumpScheduler();
      expect(fake.calls, 1);

      fake.completeOldest();
      await pumpScheduler();
      expect(fake.calls, 2);

      fake.completeOldest();
      await first;
      await second;
      expect(fake.calls, 2);
    });
  });

  group('SyncRunScheduler status reporting', () {
    test('stays running continuously across a chained trailing pass '
        'with no intermediate idle', () async {
      final fake = FakeRunPass();
      final statuses = <bool>[];
      final scheduler = schedulerWith(fake: fake, statuses: statuses);

      scheduler.requestRun();
      await pumpScheduler();
      expect(statuses, <bool>[true]);

      scheduler.requestRun();
      await pumpScheduler();
      expect(statuses, <bool>[true]);

      fake.completeOldest();
      await pumpScheduler();
      expect(statuses, <bool>[true]);

      fake.completeOldest();
      await pumpScheduler();
      expect(statuses, <bool>[true, false]);
    });
  });
}
