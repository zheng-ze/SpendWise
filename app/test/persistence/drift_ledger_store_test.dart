import 'package:domain/domain.dart';
import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/drift_ledger_store.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/persistence/mappers.dart';

/// Hands out timers the test fires by hand, so the suite never waits out a
/// 250 ms debounce or a 200 ms backoff. Real drift I/O stays genuinely async,
/// which `FakeAsync` would deadlock on.
class ManualClock {
  final List<_Armed> _armed = [];

  int get armedCount => _armed.length;

  List<Duration> get armedDelays => [for (final a in _armed) a.delay];

  StoreTimer arm(Duration delay, void Function() onFire) {
    final armed = _Armed(delay, onFire, this);
    _armed.add(armed);
    return armed;
  }

  /// Fires every timer armed at the moment of the call. A timer armed by one of
  /// these callbacks waits for the next call, which keeps a re-arming retry
  /// loop from spinning forever inside one `fire`.
  void fire() {
    final due = List<_Armed>.of(_armed);
    _armed.clear();
    for (final timer in due) {
      timer.onFire();
    }
  }
}

class _Armed implements StoreTimer {
  _Armed(this.delay, this.onFire, this.owner);

  final Duration delay;
  final void Function() onFire;
  final ManualClock owner;

  @override
  void cancel() => owner._armed.remove(this);
}

/// Fails the commit of the first [failures] transactions, then behaves
/// normally. Failing the commit rather than a single statement keeps drift's
/// own rollback in the path, so the rollback assertions test the real thing.
class FlakyInterceptor extends QueryInterceptor {
  int failures = 0;

  int transactionAttempts = 0;

  /// Runs once, as a save opens its transaction. Lets a test enqueue while a
  /// save is genuinely mid-flight rather than merely started.
  void Function()? onTransactionBegin;

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    transactionAttempts++;
    final hook = onTransactionBegin;
    onTransactionBegin = null;
    hook?.call();
    return super.beginTransaction(parent);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    if (failures > 0) {
      failures--;
      await inner.rollback();
      throw const _DiskFailure();
    }
    return super.commitTransaction(inner);
  }
}

class _DiskFailure implements Exception {
  const _DiskFailure();

  @override
  String toString() => 'disk failure';
}

void main() {
  late ManualClock clock;
  late FlakyInterceptor flaky;
  late LedgerDatabase db;
  late DriftLedgerStore store;
  late List<SaveBannerState> reported;

  setUp(() async {
    clock = ManualClock();
    flaky = FlakyInterceptor();
    db = LedgerDatabase(NativeDatabase.memory().interceptWith(flaky));
    reported = [];
    store = DriftLedgerStore(db, armTimer: clock.arm);
    await store.setErrorHandler(reported.add);
    await store.start();
  });

  tearDown(() async {
    await db.close();
  });

  domain.Account account(String id, String name) =>
      domain.Account(id: id, name: name, type: AccountType.cash);

  domain.Entry entry(String id, String amount, {String source = 'a'}) =>
      domain.Entry(
        id: id,
        date: DateTime.utc(2026, 3, 14),
        amount: Decimal.parse(amount),
        name: 'e-$id',
        sourceID: source,
      );

  domain.TransactionCategory category(
    String id,
    String name, {
    required String? parentID,
  }) => domain.TransactionCategory(
    id: id,
    name: name,
    kind: CategoryKind.expense,
    colorHex: '#ff0000',
    includeInAnalysis: true,
    parentID: parentID,
    symbol: 'fork',
  );

  /// Lets the drain loop and any awaited save run to completion. Nothing here
  /// sleeps, so this only yields the event loop.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Drives one full debounce-and-save cycle without waiting real time.
  Future<void> debouncedSave() async {
    await settle();
    clock.fire();
    await settle();
  }

  group('ordered ingest and debounce', () {
    test('enqueue buffers synchronously in arrival order', () async {
      store
        ..enqueue([UpsertAccount(account('a1', 'first'))])
        ..enqueue([UpsertAccount(account('a2', 'second'))]);

      await debouncedSave();

      final stored = await db.select(db.accounts).get();
      expect(stored.map((row) => row.name).toSet(), {'first', 'second'});
    });

    test('a burst re-arms the debounce and collapses to one save', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await settle();
      expect(clock.armedCount, 1);
      expect(clock.armedDelays.single, const Duration(milliseconds: 250));

      store.enqueue([UpsertAccount(account('a1', 'v2'))]);
      await settle();

      // The first timer was cancelled rather than left to fire twice.
      expect(clock.armedCount, 1);

      clock.fire();
      await settle();

      expect(flaky.transactionAttempts, 1);
      expect((await db.select(db.accounts).getSingle()).name, 'v2');
    });

    test('rapid conflicting upserts store the last one', () async {
      for (var i = 1; i <= 50; i++) {
        store.enqueue([UpsertAccount(account('a1', 'v$i'))]);
      }

      await debouncedSave();

      expect((await db.select(db.accounts).getSingle()).name, 'v50');
    });
  });

  group('coalescing', () {
    test('upsertThenDeleteInOneWindowAppliesOnlyDelete', () async {
      store.enqueue([UpsertEntry(entry('e1', '10'))]);
      await debouncedSave();

      store
        ..enqueue([UpsertEntry(entry('e1', '99'))])
        ..enqueue([const DeleteEntry('e1')]);

      await debouncedSave();

      final row = await db.select(db.entries).getSingle();
      expect(row.lifecycle, LifecycleState.tombstoned.code);

      // The surviving upsert would have written 99 before tombstoning, so the
      // untouched amount is what proves the upsert was dropped, not merely
      // followed by the delete.
      expect(row.amount, '10');
    });

    test('deleteThenUpsertInOneWindowAppliesOnlyUpsert', () async {
      store.enqueue([UpsertEntry(entry('e1', '10'))]);
      await debouncedSave();

      store
        ..enqueue([const DeleteEntry('e1')])
        ..enqueue([UpsertEntry(entry('e1', '42'))]);

      await debouncedSave();

      final row = await db.select(db.entries).getSingle();
      expect(row.amount, '42');
      expect(row.lifecycle, LifecycleState.active.code);
    });

    test('coalescing spans batches and preserves survivor order', () async {
      store
        ..enqueue([
          UpsertAccount(account('a1', 'v1')),
          UpsertAccount(account('a2', 'b1')),
        ])
        ..enqueue([UpsertAccount(account('a1', 'v2'))]);

      await debouncedSave();

      final rows = await db.select(db.accounts).get();
      expect({for (final r in rows) r.id: r.name}, {'a1': 'v2', 'a2': 'b1'});
    });

    test('survivors are applied in their original relative order', () async {
      // Three survivors on distinct ids, all inserted inside this one window.
      // SQLite hands out rowids in insertion order, so the stored rowids are a
      // direct readout of the order the survivors were applied in.
      store
        ..enqueue([UpsertAccount(account('a1', 'first'))])
        ..enqueue([UpsertAccount(account('a2', 'second'))])
        ..enqueue([UpsertAccount(account('a3', 'third'))])
        ..enqueue([UpsertAccount(account('a1', 'first again'))]);

      await debouncedSave();

      // 'a1' lands last because a survivor sits at the index of its final
      // occurrence, not its first.
      final order = await db
          .customSelect('SELECT id FROM accounts ORDER BY rowid')
          .get();
      expect(
        [for (final row in order) row.read<String>('id')],
        ['a2', 'a3', 'a1'],
      );
    });

    test('a coalesced row is bumped exactly once per save', () async {
      store
        ..enqueue([UpsertAccount(account('a1', 'v1'))])
        ..enqueue([UpsertAccount(account('a1', 'v2'))])
        ..enqueue([UpsertAccount(account('a1', 'v3'))]);

      await debouncedSave();

      final row = await db.select(db.accounts).getSingle();
      expect(versionFromRow(row.versionData).counters.values.single, 1);
    });
  });

  group('transactional save and retry', () {
    test('a failed save rolls back leaving nothing partial', () async {
      flaky.failures = 1;
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);

      await debouncedSave();

      // The first attempt failed, the retry is armed at the backoff.
      expect(reported, [SaveBannerState.retrying]);
      expect(await db.select(db.accounts).get(), isEmpty);
      expect(clock.armedDelays.single, const Duration(milliseconds: 200));

      clock.fire();
      await settle();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
      expect(reported.last, SaveBannerState.clear);
    });

    test('a cycle retries twice before giving up', () async {
      flaky.failures = 3;
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);

      await debouncedSave();
      expect(reported, [SaveBannerState.retrying]);

      clock.fire();
      await settle();
      expect(reported, [SaveBannerState.retrying, SaveBannerState.retrying]);

      clock.fire();
      await settle();

      expect(reported.last, SaveBannerState.failedWillRetry);
      expect(flaky.transactionAttempts, 3);
    });

    test('failedWillRetryEventuallyPersistsWhenStoreRecovers', () async {
      flaky.failures = 3;
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);

      await debouncedSave();
      clock.fire();
      await settle();
      clock.fire();
      await settle();

      expect(reported.last, SaveBannerState.failedWillRetry);
      expect(await db.select(db.accounts).get(), isEmpty);

      // No further enqueue. Swift stopped here and the data never landed.
      expect(clock.armedDelays.single, const Duration(milliseconds: 200));

      clock.fire();
      await settle();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
      expect(reported.last, SaveBannerState.clear);
    });

    test('a timed retry does not flip the banner back to retrying', () async {
      flaky.failures = 6;
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);

      await debouncedSave();
      clock.fire();
      await settle();
      clock.fire();
      await settle();
      expect(reported.last, SaveBannerState.failedWillRetry);

      final beforeTimedCycle = reported.length;

      // A whole timer-driven cycle, exhausting its own two retries.
      clock.fire();
      await settle();
      clock.fire();
      await settle();
      clock.fire();
      await settle();

      expect(
        reported.sublist(beforeTimedCycle),
        everyElement(isNot(SaveBannerState.retrying)),
      );
    });

    test('the pending batch survives every failed attempt', () async {
      flaky.failures = 3;
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);

      await debouncedSave();
      clock.fire();
      await settle();
      clock.fire();
      await settle();

      expect(reported.last, SaveBannerState.failedWillRetry);
      expect(store.debugPendingLength, 1);
    });
  });

  group('save bookkeeping', () {
    test('a batch buffered during a save is not cleared by it', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await settle();

      // Fired without awaiting, so the enqueue below lands mid-save.
      clock.fire();
      store.enqueue([UpsertAccount(account('a2', 'v2'))]);

      await settle();

      // Clearing the coalesced count instead of the raw one would drop this.
      expect(store.debugPendingLength, lessThanOrEqualTo(1));

      await debouncedSave();

      expect((await db.select(db.accounts).get()).length, 2);
    });

    test('the raw pre-coalesce count is what clears from pending', () async {
      store
        ..enqueue([UpsertAccount(account('a1', 'v1'))])
        ..enqueue([UpsertAccount(account('a1', 'v2'))])
        ..enqueue([UpsertAccount(account('a1', 'v3'))]);

      await debouncedSave();

      // Three raw changes coalesce to one. Clearing only the coalesced count
      // would leave two stale changes behind.
      expect(store.debugPendingLength, 0);
    });

    test('saves are serialized behind one in-flight future', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await settle();

      // Two save requests racing the same pending prefix. Without the
      // in-flight guard both apply it and the row is bumped twice.
      final first = store.debugSaveCycle();
      final second = store.debugSaveCycle();
      await Future.wait([first, second]);
      await settle();

      final row = await db.select(db.accounts).getSingle();
      expect(versionFromRow(row.versionData).counters.values.single, 1);
      expect(flaky.transactionAttempts, 1);
    });
  });

  group('banner reporting', () {
    test('clearReportedOnlyAfterNonClearState', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await debouncedSave();

      store.enqueue([UpsertAccount(account('a2', 'v2'))]);
      await debouncedSave();

      expect(reported, isEmpty);
    });

    test('clear is reported once a non-clear state has been', () async {
      flaky.failures = 1;
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);

      await debouncedSave();
      clock.fire();
      await settle();

      expect(reported, [SaveBannerState.retrying, SaveBannerState.clear]);
    });

    test('clear is not repeated on a second healthy save', () async {
      flaky.failures = 1;
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await debouncedSave();
      clock.fire();
      await settle();

      store.enqueue([UpsertAccount(account('a2', 'v2'))]);
      await debouncedSave();

      expect(reported, [SaveBannerState.retrying, SaveBannerState.clear]);
    });
  });

  group('flush barrier', () {
    test('flushNowPersistsAnEnqueueMadeMomentsBefore', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);

      // No clock.fire, so the armed debounce never runs. Only the flush can
      // put this on disk.
      await store.flushNow();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
      expect(store.debugPendingLength, 0);
    });

    test('debouncedFlushPersistsWithoutAnExplicitFlush', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);

      await debouncedSave();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
    });

    test('flushNow starts the store when it was never started', () async {
      final unstarted = DriftLedgerStore(db, armTimer: clock.arm);
      unstarted.enqueue([UpsertAccount(account('a1', 'v1'))]);

      await unstarted.flushNow();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');

      // A store left unstarted buffers nothing on enqueue, so the debounce that
      // writes this batch is only armed if the flush really did start it.
      unstarted.enqueue([UpsertAccount(account('a2', 'v2'))]);
      await debouncedSave();

      expect((await db.select(db.accounts).get()).length, 2);
    });

    test('flushNow on an already started store does not restart it', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await store.flushNow();

      store.enqueue([UpsertAccount(account('a2', 'v2'))]);
      await store.flushNow();

      expect((await db.select(db.accounts).get()).length, 2);
    });

    test('the barrier rides the ingest queue behind earlier batches', () async {
      // Enqueued and flushed with no settle in between, so the batch is still
      // sitting in the ingest queue when the flush is called.
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      final flush = store.flushNow();
      store.enqueue([UpsertAccount(account('a2', 'after the barrier'))]);

      await flush;

      // 'a1' was enqueued before the barrier, so the flush must have written
      // it. 'a2' came after and is not covered by this flush's guarantee.
      final names = (await db.select(db.accounts).get())
          .map((row) => row.name)
          .toSet();
      expect(names, contains('v1'));
    });

    test('flushNow cancels the armed debounce timer', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await settle();
      expect(clock.armedCount, 1);

      await store.flushNow();

      // The debounce is gone, not left to fire a redundant save later.
      expect(clock.armedCount, 0);
      clock.fire();
      await settle();
      expect(flaky.transactionAttempts, 1);
    });

    test('flushNowCoversBatchBufferedDuringInFlightSave', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await settle();

      // Fires the debounce without awaiting, so this save is in flight and has
      // already snapshotted 'a1' when the flush below awaits it.
      clock.fire();

      // Each batch lands mid-transaction, so the save that is running clears
      // only its own snapshot and leaves the new one pending. Two of them means
      // the flush must run more than one cycle after the save it awaited.
      flaky.onTransactionBegin = () {
        store.enqueue([UpsertAccount(account('a2', 'v2'))]);
        flaky.onTransactionBegin = () {
          store.enqueue([UpsertAccount(account('a3', 'v3'))]);
        };
      };

      await store.flushNow();

      // No clock.fire after those enqueues, so no debounce timer can write
      // them. A single trailing save returns with 'a3' still buffered.
      expect(store.debugPendingLength, 0);
      expect((await db.select(db.accounts).get()).length, 3);
    });

    test(
      'flushNow stops looping when a cycle ends in failedWillRetry',
      () async {
        // More failures than any number of cycles can consume, so a loop
        // without the give-up exit never sees pending drain.
        flaky.failures = 99;
        store.enqueue([UpsertAccount(account('a1', 'v1'))]);

        var returned = false;
        final flush = store.flushNow().then((_) => returned = true);

        // Fires the in-cycle backoff timers so a cycle can exhaust its retries
        // and report. Ten passes outlast the three attempts one cycle needs, so
        // a flush that kept looping would still be unfinished here.
        for (var i = 0; i < 10; i++) {
          await settle();
          clock.fire();
        }
        await settle();

        expect(returned, isTrue, reason: 'the flush never gave up looping');
        await flush;

        expect(reported.last, SaveBannerState.failedWillRetry);
        expect(store.debugPendingLength, 1);
        expect(await db.select(db.accounts).get(), isEmpty);
      },
    );

    test('flushOnAnIdleStoreIsANoOp', () async {
      await store.flushNow();

      expect(reported, isEmpty);
      expect(flaky.transactionAttempts, 0);
      expect(clock.armedCount, 0);
    });

    test('flushNow after a completed save is a no-op', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await debouncedSave();
      final attemptsAfterSave = flaky.transactionAttempts;

      await store.flushNow();

      expect(flaky.transactionAttempts, attemptsAfterSave);
      expect(reported, isEmpty);
    });

    test('a flush recovers from a failure inside its own loop', () async {
      flaky.failures = 1;
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);

      // The first attempt fails, the in-cycle backoff timer needs firing.
      final flush = store.flushNow();
      await settle();
      clock.fire();
      await flush;

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
    });
  });

  group('apply rules', () {
    test('an upsert inserts when absent then updates in place', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await debouncedSave();

      store.enqueue([UpsertAccount(account('a1', 'v2'))]);
      await debouncedSave();

      final row = await db.select(db.accounts).getSingle();
      expect(row.name, 'v2');
      expect(versionFromRow(row.versionData).counters.values.single, 2);
    });

    test('deleteMoneySource tombstones an account', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await debouncedSave();

      store.enqueue([const DeleteMoneySource('a1')]);
      await debouncedSave();

      expect(
        (await db.select(db.accounts).getSingle()).lifecycle,
        LifecycleState.tombstoned.code,
      );
    });

    test('deleteMoneySource falls through to pockets', () async {
      store.enqueue([UpsertPocket(domain.SubPocket(id: 'p1', name: 'p'))]);
      await debouncedSave();

      store.enqueue([const DeleteMoneySource('p1')]);
      await debouncedSave();

      expect(
        (await db.select(db.subPockets).getSingle()).lifecycle,
        LifecycleState.tombstoned.code,
      );
    });

    test('a delete for an absent id is a silent no-op', () async {
      store.enqueue([
        const DeleteMoneySource('nope'),
        const DeleteCategory('nope'),
        const DeleteEntry('nope'),
        const DeletePlan('nope'),
      ]);

      await debouncedSave();

      expect(reported, isEmpty);
      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.entries).get(), isEmpty);
    });

    test('an upsert keeps the stored parent of a category', () async {
      store.enqueue([
        UpsertCategory(category('c1', 'food', parentID: 'parent-1')),
      ]);
      await debouncedSave();

      store.enqueue([
        UpsertCategory(category('c1', 'food renamed', parentID: 'parent-2')),
      ]);
      await debouncedSave();

      final row = await db.select(db.categories).getSingle();
      expect(row.name, 'food renamed');
      expect(row.parentId, 'parent-1');
    });

    test(
      'a plan upsert stores an active row and a delete tombstones',
      () async {
        final plan = RecurringPlan(
          id: 'pl1',
          template: EntryTemplate(
            amount: Decimal.parse('25'),
            name: 'rent',
            sourceID: 'a1',
          ),
          frequency: RecurrenceFrequency.monthly,
          anchor: DateTime.utc(2026, 1, 1),
          lastResolvedDate: DateTime.utc(2026, 1, 1),
        );

        store.enqueue([UpsertPlan(plan)]);
        await debouncedSave();
        expect(
          (await db.select(db.plans).getSingle()).lifecycle,
          LifecycleState.active.code,
        );

        store.enqueue([const DeletePlan('pl1')]);
        await debouncedSave();

        expect(
          (await db.select(db.plans).getSingle()).lifecycle,
          LifecycleState.tombstoned.code,
        );
      },
    );
  });
}
