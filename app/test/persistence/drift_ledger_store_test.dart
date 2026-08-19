import 'package:domain/domain.dart';
import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/drift_ledger_store.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/persistence/mappers.dart';

// Hands out timers the test fires by hand, so real time never elapses.
// Real drift I/O stays genuinely async, which `FakeAsync` would deadlock on.
class ManualClock {
  final List<_Armed> _armed = [];

  int get armedCount => _armed.length;

  List<Duration> get armedDelays => [for (final a in _armed) a.delay];

  StoreTimer arm(Duration delay, void Function() onFire) {
    final armed = _Armed(delay, onFire, this);
    _armed.add(armed);
    return armed;
  }

  // Fires every timer armed at the moment of the call. A timer armed by a
  // callback waits for the next call, so a re-arming retry loop cannot spin forever here.
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

// Fails the commit of the first `failures` transactions, then behaves normally.
// Failing the commit keeps drift's own rollback in the path, so it tests the real thing.
class FlakyInterceptor extends QueryInterceptor {
  int failures = 0;

  int transactionAttempts = 0;

  // Runs once, as a save opens its transaction. Lets a test enqueue while a
  // save is genuinely mid-flight rather than merely started.
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

  // Lets the drain loop and any awaited save run to completion. Nothing here
  // sleeps, so this only yields the event loop.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> debouncedSave() async {
    await settle();
    clock.fire();
    await settle();
  }

  // Counts once per write the row has taken, so a change applied twice reads
  // as two even though the row itself looks the same.
  Future<int> versionBumpsOnAccount(String id) async {
    final row = await (db.select(
      db.accounts,
    )..where((row) => row.id.equals(id))).getSingle();
    return versionFromRow(row.versionData).counters.values.single;
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

      // A surviving upsert would have written 99 before tombstoning, so the
      // untouched amount proves the upsert itself was dropped by coalescing.
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
    test('saveFailureRollsBackThenRetrySucceeds', () async {
      flaky.failures = 1;
      store.enqueue([
        UpsertAccount(account('a1', 'v1')),
        UpsertEntry(entry('e1', '10')),
      ]);

      await debouncedSave();

      expect(reported, [SaveBannerState.retrying]);
      expect(flaky.transactionAttempts, 1);

      // Both rows or neither. A partial commit would leave the account behind,
      // since it is applied before the entry inside the one transaction.
      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.entries).get(), isEmpty);
      expect(clock.armedDelays.single, const Duration(milliseconds: 200));

      clock.fire();
      await settle();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
      expect((await db.select(db.entries).getSingle()).amount, '10');
      expect(reported.last, SaveBannerState.clear);

      // A flush over a store still holding the written batch would re-apply it
      // and bump the row a second time.
      final attemptsAfterRetry = flaky.transactionAttempts;
      await store.flushNow();
      expect(flaky.transactionAttempts, attemptsAfterRetry);

      // The rolled back attempt wrote no version, so the row that landed sits
      // at one bump rather than two.
      final row = await db.select(db.accounts).getSingle();
      expect(versionFromRow(row.versionData).counters.values.single, 1);
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

      // The batch is still pending after this cycle gives up.
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
      expect(await db.select(db.accounts).get(), isEmpty);

      // The disk is healthy again and nothing new is enqueued, so the row can
      // only land if every failed attempt left the batch pending.
      clock.fire();
      await settle();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
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
      await debouncedSave();

      // Clearing more than the save snapshotted would drop 'a2' before it was
      // ever written.
      expect((await db.select(db.accounts).get()).length, 2);
    });

    test('the raw pre-coalesce count is what clears from pending', () async {
      store
        ..enqueue([UpsertAccount(account('a1', 'v1'))])
        ..enqueue([UpsertAccount(account('a1', 'v2'))])
        ..enqueue([UpsertAccount(account('a1', 'v3'))]);

      await debouncedSave();

      // Three raw changes coalesce to one. Clearing only the coalesced count
      // would leave two stale changes behind for this flush to write again.
      await store.flushNow();

      expect(flaky.transactionAttempts, 1);
      expect(await versionBumpsOnAccount('a1'), 1);
    });

    test('saves are serialized behind one in-flight future', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await settle();

      // Both calls enter their save loop over the same pending prefix in the same
      // turn. Without the in-flight guard, the second would bump the row a second time.
      final first = store.flushNow();
      final second = store.flushNow();
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

      await store.flushNow();
      expect(await versionBumpsOnAccount('a1'), 1);
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

      // Each batch lands mid-transaction, so the running save clears only its own
      // snapshot, leaving flushNow to run more than one cycle after the save it awaited.
      flaky.onTransactionBegin = () {
        store.enqueue([UpsertAccount(account('a2', 'v2'))]);
        flaky.onTransactionBegin = () {
          store.enqueue([UpsertAccount(account('a3', 'v3'))]);
        };
      };

      await store.flushNow();

      // No clock.fire after those enqueues, so no debounce timer can write
      // them. A single trailing save returns with 'a3' still buffered.
      expect((await db.select(db.accounts).get()).length, 3);
    });

    test('flushNow stops looping when a cycle ends in failedWillRetry', () async {
      // More failures than any number of cycles can consume, so a loop
      // without the give-up exit never sees pending drain.
      flaky.failures = 99;
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);

      var returned = false;
      final flush = store.flushNow().then((_) => returned = true);

      // Ten passes far outlast the three attempts one retry cycle needs, so a
      // flush that kept looping instead of giving up would still be unfinished here.
      for (var i = 0; i < 10; i++) {
        await settle();
        clock.fire();
      }
      await settle();

      expect(returned, isTrue, reason: 'the flush never gave up looping');
      await flush;

      expect(reported.last, SaveBannerState.failedWillRetry);
      expect(store.pendingCount, 1);
      expect(await db.select(db.accounts).get(), isEmpty);
    });

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

  group('load', () {
    domain.SubPocket pocket(String id, String name) =>
        domain.SubPocket(id: id, name: name);

    RecurringPlan plan(String id) => RecurringPlan(
      id: id,
      template: EntryTemplate(
        amount: Decimal.parse('25'),
        name: 'rent',
        sourceID: 'a1',
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 1),
      lastResolvedDate: DateTime.utc(2026, 1, 1),
    );

    test('loadReturnsWhatWasEnqueued', () async {
      store.enqueue([
        UpsertAccount(account('a1', 'wallet').addSubPocket('p1')),
        UpsertPocket(pocket('p1', 'rainy day')),
        UpsertCategory(category('c1', 'food', parentID: null)),
        UpsertEntry(entry('e1', '12.34', source: 'a1')),
        UpsertPlan(plan('pl1')),
      ]);
      await store.flushNow();

      final state = await store.load();

      expect(state.moneySources.keys.toSet(), {'a1', 'p1'});
      expect(state.categories.keys.toSet(), {'c1'});
      expect(state.entries.keys.toSet(), {'e1'});
      expect(state.plans.keys.toSet(), {'pl1'});
      expect(state.entries['e1']!.amount, Decimal.parse('12.34'));
      expect(state.entries['e1']!.date, DateTime.utc(2026, 3, 14));
      expect(state.moneySources['a1']!.name, 'wallet');
    });

    test('deleteChangeRemovesFromLoadedState', () async {
      store.enqueue([
        UpsertAccount(account('a1', 'wallet')),
        UpsertEntry(entry('e1', '12.34')),
      ]);
      await store.flushNow();

      store.enqueue([const DeleteEntry('e1')]);
      await store.flushNow();

      final state = await store.load();

      expect(state.entries, isEmpty);
      expect(state.moneySources.keys.toSet(), {'a1'});

      // The row survives the delete, so load is filtering rather than the
      // delete having removed it.
      final row = await db.select(db.entries).getSingle();
      expect(row.lifecycle, LifecycleState.tombstoned.code);
    });

    test('enqueuedChangesPersistAcrossLoad', () async {
      store.enqueue([
        UpsertAccount(account('a1', 'wallet')),
        UpsertEntry(entry('e1', '12.34', source: 'a1')),
      ]);
      await store.flushNow();

      final state = await store.load();

      expect(state.moneySources['a1']!.name, 'wallet');
      expect(state.entries['e1']!.amount, Decimal.parse('12.34'));
    });

    test('deleteTombstonesRowButHidesItFromLoad', () async {
      store.enqueue([UpsertEntry(entry('e1', '12.34'))]);
      await store.flushNow();

      store.enqueue([const DeleteEntry('e1')]);
      await store.flushNow();

      expect((await store.load()).entries, isEmpty);

      final row = await db
          .customSelect('SELECT lifecycle, version_data FROM entries')
          .getSingle();
      expect(row.read<int>('lifecycle'), LifecycleState.tombstoned.code);

      // The delete bumps rather than clears, so a tombstone carries the causal
      // history a future sync needs to see it as newer than the upsert.
      final counters = versionFromRow(
        row.read<Uint8List>('version_data'),
      ).counters;
      expect(counters.values.fold(0, (sum, count) => sum + count), 2);
    });

    test('coalescedUpsertsWriteLatestValue', () async {
      store
        ..enqueue([UpsertCategory(category('c1', 'v1', parentID: null))])
        ..enqueue([UpsertCategory(category('c1', 'v2', parentID: null))]);
      await store.flushNow();

      expect((await store.load()).categories['c1']!.name, 'v2');
      expect(flaky.transactionAttempts, 1);
    });

    test('planPersistsAndTombstonesAcrossLoad', () async {
      store.enqueue([
        UpsertAccount(account('a1', 'wallet')),
        UpsertPlan(plan('pl1')),
      ]);
      await store.flushNow();

      expect((await store.load()).plans.keys.toSet(), {'pl1'});

      store.enqueue([const DeletePlan('pl1')]);
      await store.flushNow();

      expect((await store.load()).plans, isEmpty);
      expect(
        (await db.select(db.plans).getSingle()).lifecycle,
        LifecycleState.tombstoned.code,
      );
    });

    test(
      'load orders changes accounts pockets categories entries plans',
      () async {
        store.enqueue([
          UpsertPlan(plan('pl1')),
          UpsertEntry(entry('e1', '12.34')),
          UpsertCategory(category('c1', 'food', parentID: null)),
          UpsertPocket(pocket('p1', 'rainy day')),
          UpsertAccount(account('a1', 'wallet')),
        ]);
        await store.flushNow();

        final changes = await loadChanges(db);

        expect(changes.map((c) => c.runtimeType).toList(), [
          UpsertAccount,
          UpsertPocket,
          UpsertCategory,
          UpsertEntry,
          UpsertPlan,
        ]);
      },
    );

    test('a corrupt version vector does not fail the load', () async {
      store.enqueue([UpsertAccount(account('a1', 'wallet'))]);
      await store.flushNow();

      await db.customUpdate(
        'UPDATE accounts SET version_data = ? WHERE id = ?',
        variables: [
          Variable<Uint8List>(Uint8List.fromList([0xff, 0xfe])),
          const Variable<String>('a1'),
        ],
        updates: {db.accounts},
      );

      // Load reads only the domain columns, so damage to a vector surfaces on
      // the next write to the row rather than here.
      final state = await store.load();
      expect(state.moneySources.keys.toSet(), {'a1'});
    });

    test('a storage error propagates out of load', () async {
      await db.customStatement('DROP TABLE entries');

      // Not `isA<Object>()`, which an UnimplementedError from an unbuilt load
      // would satisfy just as well as the storage failure under test.
      await expectLater(
        store.load(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('entries'),
          ),
        ),
      );
    });
  });

  group('seeding', () {
    List<LedgerChange> seedChanges() => [
      UpsertAccount(account('a1', 'wallet')),
      UpsertEntry(entry('e1', '12.34', source: 'a1')),
    ];

    // An absent meta row reads as unseeded, which is what a seed that never
    // reached its commit leaves behind.
    Future<bool> hasSeeded() async =>
        (await db.select(db.storeMeta).getSingleOrNull())?.hasSeeded ?? false;

    test('seedRunsOnceAndIsGatedByFlagNotEmptiness', () async {
      await store.seedIfFirstLaunch(seedChanges());

      expect(await hasSeeded(), isTrue);
      expect((await store.load()).entries.keys.toSet(), {'e1'});

      // Wiping every row leaves the flag as the only thing that can gate the
      // second call, so a store gating on emptiness would seed again here.
      await db.customStatement('DELETE FROM accounts');
      await db.customStatement('DELETE FROM entries');

      await store.seedIfFirstLaunch(seedChanges());

      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.entries).get(), isEmpty);
      expect((await store.load()).entries, isEmpty);
    });

    test('a failed seed save leaves has_seeded unset', () async {
      // Outlasts every in-cycle retry, so the seed genuinely gives up rather
      // than merely stumbling on the way to a commit.
      flaky.failures = 100;

      final seed = store.seedIfFirstLaunch(seedChanges());
      for (var i = 0; i < 5; i++) {
        await settle();
        clock.fire();
      }
      await seed;

      expect(await hasSeeded(), isFalse);
      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.entries).get(), isEmpty);
    });

    test('a seed that recovers commits the flag with its rows', () async {
      flaky.failures = 1;

      final seed = store.seedIfFirstLaunch(seedChanges());
      await settle();
      clock.fire();
      await seed;

      expect(await hasSeeded(), isTrue);
      expect((await store.load()).entries.keys.toSet(), {'e1'});
    });
  });
}
