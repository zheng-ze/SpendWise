import 'package:domain/domain.dart';
import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/store/drift_ledger_store.dart';
import 'package:spendwise/persistence/database/ledger_database.dart';
import 'package:spendwise/persistence/database/ledger_database.dart' as rows;
import 'package:spendwise/persistence/store/ledger_store.dart';
import 'package:spendwise/persistence/mappers/mappers.dart';

import '../support/ledger_fixtures.dart';

class ManualClock {
  final List<_Armed> _armed = [];

  int get armedCount => _armed.length;

  List<Duration> get armedDelays => [for (final a in _armed) a.delay];

  StoreTimer arm(Duration delay, void Function() onFire) {
    final armed = _Armed(delay, onFire, this);
    _armed.add(armed);
    return armed;
  }

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

class FlakyInterceptor extends QueryInterceptor {
  int failures = 0;

  int transactionAttempts = 0;

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
      testAccount(id: id, name: name, type: AccountType.cash);

  domain.Entry entry(String id, String amount, {String source = 'a'}) =>
      testEntry(
        id: id,
        sourceID: source,
        amount: Decimal.parse(amount),
        name: 'e-$id',
        date: DateTime.utc(2026, 3, 14),
      );

  domain.TransactionCategory category(
    String id,
    String name, {
    required String? parentID,
  }) => testCategory(
    id: id,
    name: name,
    colorHex: '#ff0000',
    parentID: parentID,
    symbol: 'fork',
  );

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

      expect(await db.select(db.entries).get(), isEmpty);
    });

    test('a budget upsert followed by a delete of the same id applies only the delete', () async {
      domain.Budget budget(String amount) => domain.Budget(
        id: 'b1',
        categoryID: 'c1',
        limit: Decimal.parse(amount),
      );

      store.enqueue([UpsertBudget(budget('10'))]);
      await debouncedSave();

      store
        ..enqueue([UpsertBudget(budget('99'))])
        ..enqueue([const DeleteBudget('b1')]);

      await debouncedSave();

      expect(await db.select(db.budgets).get(), isEmpty);
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
      store
        ..enqueue([UpsertAccount(account('a1', 'first'))])
        ..enqueue([UpsertAccount(account('a2', 'second'))])
        ..enqueue([UpsertAccount(account('a3', 'third'))])
        ..enqueue([UpsertAccount(account('a1', 'first again'))]);

      await debouncedSave();

      final order = await db
          .customSelect('SELECT id FROM accounts ORDER BY rowid')
          .get();
      expect(
        [for (final row in order) row.read<String>('id')],
        ['a2', 'a3', 'a1'],
      );
    });

    test('a pocket upsert followed by delete money source coalesces to one '
        'deletion', () async {
      store.enqueue([
        UpsertPocket(domain.SubPocket(id: 'p1', name: 'original')),
      ]);
      await debouncedSave();

      store
        ..enqueue([
          UpsertPocket(domain.SubPocket(id: 'p1', name: 'replacement')),
        ])
        ..enqueue([const DeleteMoneySource('p1')]);

      await debouncedSave();

      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.subPockets).get(), isEmpty);
    });

    test('identical ids in different collections stay independent', () async {
      store.enqueue([
        UpsertAccount(account('shared', 'wallet')),
        UpsertEntry(entry('shared', '10')),
      ]);

      await debouncedSave();

      expect((await db.select(db.accounts).getSingle()).name, 'wallet');
      expect((await db.select(db.entries).getSingle()).amount, '10');
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

      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.entries).get(), isEmpty);
      expect(clock.armedDelays.single, const Duration(milliseconds: 200));

      clock.fire();
      await settle();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
      expect((await db.select(db.entries).getSingle()).amount, '10');
      expect(reported.last, SaveBannerState.clear);

      final attemptsAfterRetry = flaky.transactionAttempts;
      await store.flushNow();
      expect(flaky.transactionAttempts, attemptsAfterRetry);

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
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

      clock.fire();
      await settle();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
    });
  });

  group('save bookkeeping', () {
    test('a batch buffered during a save is not cleared by it', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await settle();

      clock.fire();
      store.enqueue([UpsertAccount(account('a2', 'v2'))]);

      await settle();
      await debouncedSave();

      expect((await db.select(db.accounts).get()).length, 2);
    });

    test('the raw pre-coalesce count is what clears from pending', () async {
      store
        ..enqueue([UpsertAccount(account('a1', 'v1'))])
        ..enqueue([UpsertAccount(account('a1', 'v2'))])
        ..enqueue([UpsertAccount(account('a1', 'v3'))]);

      await debouncedSave();

      await store.flushNow();

      expect(flaky.transactionAttempts, 1);
      expect((await db.select(db.accounts).getSingle()).name, 'v3');
    });

    test('saves are serialized behind one in-flight future', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await settle();

      final first = store.flushNow();
      final second = store.flushNow();
      await Future.wait([first, second]);
      await settle();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');
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

      await store.flushNow();

      expect((await db.select(db.accounts).getSingle()).name, 'v1');

      await store.flushNow();
      expect(flaky.transactionAttempts, 1);
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
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      final flush = store.flushNow();
      store.enqueue([UpsertAccount(account('a2', 'after the barrier'))]);

      await flush;

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

      clock.fire();

      flaky.onTransactionBegin = () {
        store.enqueue([UpsertAccount(account('a2', 'v2'))]);
        flaky.onTransactionBegin = () {
          store.enqueue([UpsertAccount(account('a3', 'v3'))]);
        };
      };

      await store.flushNow();

      expect((await db.select(db.accounts).get()).length, 3);
    });

    test(
      'flushNow stops looping when a cycle ends in failedWillRetry',
      () async {
        flaky.failures = 99;
        store.enqueue([UpsertAccount(account('a1', 'v1'))]);

        final flush = expectLater(
          store.flushNow(),
          throwsA(
            isA<PersistenceBarrierFailure>()
                .having((error) => error.cause != null, 'has cause', isTrue)
                .having(
                  (error) => error.stackTrace != null,
                  'has stackTrace',
                  isTrue,
                ),
          ),
        );

        for (var i = 0; i < 10; i++) {
          await settle();
          clock.fire();
        }
        await settle();

        await flush;

        expect(reported.last, SaveBannerState.failedWillRetry);
        expect(store.pendingCount, 1);
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
    });

    test('deleteMoneySource removes an account', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await debouncedSave();

      store.enqueue([const DeleteMoneySource('a1')]);
      await debouncedSave();

      expect(await db.select(db.accounts).get(), isEmpty);
    });

    test('deleteMoneySource falls through to pockets', () async {
      store.enqueue([UpsertPocket(domain.SubPocket(id: 'p1', name: 'p'))]);
      await debouncedSave();

      store.enqueue([const DeleteMoneySource('p1')]);
      await debouncedSave();

      expect(await db.select(db.subPockets).get(), isEmpty);
    });

    test('a delete for an absent id is a silent no-op', () async {
      store.enqueue([
        const DeleteMoneySource('nope'),
        const DeleteCategory('nope'),
        const DeleteEntry('nope'),
        const DeletePlan('nope'),
        const DeleteBudget('nope'),
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
      'a plan upsert stores an active row and a delete removes it',
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

        expect(await db.select(db.plans).get(), isEmpty);
      },
    );

    test(
      'a budget upsert stores an active row and a delete removes it',
      () async {
        final budget = domain.Budget(
          id: 'b1',
          categoryID: 'c1',
          limit: Decimal.fromInt(500),
        );

        store.enqueue([UpsertBudget(budget)]);
        await debouncedSave();
        expect(
          (await db.select(db.budgets).getSingle()).lifecycle,
          LifecycleState.active.code,
        );

        store.enqueue([const DeleteBudget('b1')]);
        await debouncedSave();

        expect(await db.select(db.budgets).get(), isEmpty);
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

    domain.Budget budget(String id) =>
        domain.Budget(id: id, categoryID: 'c1', limit: Decimal.fromInt(500));

    test('loadReturnsWhatWasEnqueued', () async {
      store.enqueue([
        UpsertAccount(account('a1', 'wallet').addSubPocket('p1')),
        UpsertPocket(pocket('p1', 'rainy day')),
        UpsertCategory(category('c1', 'food', parentID: null)),
        UpsertEntry(entry('e1', '12.34', source: 'a1')),
        UpsertPlan(plan('pl1')),
        UpsertBudget(budget('b1')),
      ]);
      await store.flushNow();

      final state = await store.load();

      expect(state.moneySources.keys.toSet(), {'a1', 'p1'});
      expect(state.categories.keys.toSet(), {'c1'});
      expect(state.entries.keys.toSet(), {'e1'});
      expect(state.plans.keys.toSet(), {'pl1'});
      expect(state.budgets.keys.toSet(), {'b1'});
      expect(state.entries['e1']!.amount, Decimal.parse('12.34'));
      expect(state.entries['e1']!.date, DateTime.utc(2026, 3, 14));
      expect(state.moneySources['a1']!.name, 'wallet');
    });

    test('anArchivedEntryPersistsAsLifecycleOneAndReloadsIntoTheBin', () async {
      final active = entry('e1', '12.34');
      store.enqueue([UpsertAccount(account('a', 'wallet'))]);
      store.enqueue([UpsertEntry(active)]);
      await store.flushNow();

      store.enqueue([
        UpsertEntry(active.settingLifecycle(LifecycleState.archived)),
      ]);
      await store.flushNow();

      final row = await db.select(db.entries).getSingle();
      expect(row.lifecycle, LifecycleState.archived.code);
      final state = await store.load();
      expect(state.entries, isEmpty);
      expect(state.binnedEntries.keys.toSet(), {'e1'});
      expect(state.binnedEntries['e1']!.amount, Decimal.parse('12.34'));
    });

    test('restoringAnArchivedEntryPersistsLifecycleZero', () async {
      final active = entry('e1', '12.34');
      store.enqueue([
        UpsertAccount(account('a', 'wallet')),
        UpsertEntry(active.settingLifecycle(LifecycleState.archived)),
      ]);
      await store.flushNow();

      store.enqueue([UpsertEntry(active)]);
      await store.flushNow();

      final row = await db.select(db.entries).getSingle();
      expect(row.lifecycle, LifecycleState.active.code);
      final state = await store.load();
      expect(state.binnedEntries, isEmpty);
      expect(state.entries.keys.toSet(), {'e1'});
    });

    test('purgingAnArchivedEntryRemovesTheRow', () async {
      store.enqueue([
        UpsertAccount(account('a', 'wallet')),
        UpsertEntry(
          entry('e1', '12.34').settingLifecycle(LifecycleState.archived),
        ),
      ]);
      await store.flushNow();

      store.enqueue([const DeleteEntry('e1')]);
      await store.flushNow();

      expect(await db.select(db.entries).get(), isEmpty);
      final state = await store.load();
      expect(state.binnedEntries, isEmpty);
      expect(state.entries, isEmpty);
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
      expect(await db.select(db.entries).get(), isEmpty);
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

    test('deleteRemovesRowAndHidesItFromLoad', () async {
      store.enqueue([UpsertEntry(entry('e1', '12.34'))]);
      await store.flushNow();

      store.enqueue([const DeleteEntry('e1')]);
      await store.flushNow();

      expect((await store.load()).entries, isEmpty);
      expect(await db.select(db.entries).get(), isEmpty);
    });

    test('coalescedUpsertsWriteLatestValue', () async {
      store
        ..enqueue([UpsertCategory(category('c1', 'v1', parentID: null))])
        ..enqueue([UpsertCategory(category('c1', 'v2', parentID: null))]);
      await store.flushNow();

      expect((await store.load()).categories['c1']!.name, 'v2');
      expect(flaky.transactionAttempts, 1);
    });

    test('planPersistsAndDeletesAcrossLoad', () async {
      store.enqueue([
        UpsertAccount(account('a1', 'wallet')),
        UpsertPlan(plan('pl1')),
      ]);
      await store.flushNow();

      expect((await store.load()).plans.keys.toSet(), {'pl1'});

      store.enqueue([const DeletePlan('pl1')]);
      await store.flushNow();

      expect((await store.load()).plans, isEmpty);
      expect(await db.select(db.plans).get(), isEmpty);
    });

    test('budgetPersistsAndDeletesAcrossLoad', () async {
      store.enqueue([
        UpsertCategory(category('c1', 'food', parentID: null)),
        UpsertBudget(budget('b1')),
      ]);
      await store.flushNow();

      expect((await store.load()).budgets.keys.toSet(), {'b1'});

      store.enqueue([const DeleteBudget('b1')]);
      await store.flushNow();

      expect((await store.load()).budgets, isEmpty);
      expect(await db.select(db.budgets).get(), isEmpty);
    });

    test(
      'load orders changes accounts pockets categories entries plans budgets',
      () async {
        store.enqueue([
          UpsertBudget(budget('b1')),
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
          UpsertBudget,
        ]);
      },
    );

    test('a stored tombstoned account makes load fail', () async {
      await db.customStatement(
        'INSERT INTO accounts (id, name, type, sub_pocket_ids, '
        'incoming_transfers_as_expenses, include_in_net_worth, lifecycle) '
        "VALUES ('a1', 'wallet', 0, '[]', 0, 1, 3)",
      );

      await expectLater(store.load(), throwsA(anything));
    });
    test('a storage error propagates out of load', () async {
      await db.customStatement('DROP TABLE entries');

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

    Future<bool> hasSeeded() async =>
        (await db.select(db.storeMeta).getSingleOrNull())?.hasSeeded ?? false;

    test('seedRunsOnceAndIsGatedByFlagNotEmptiness', () async {
      await store.seedIfFirstLaunch(seedChanges());

      expect(await hasSeeded(), isTrue);
      expect((await store.load()).entries.keys.toSet(), {'e1'});

      await db.customStatement('DELETE FROM accounts');
      await db.customStatement('DELETE FROM entries');

      await store.seedIfFirstLaunch(seedChanges());

      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.entries).get(), isEmpty);
      expect((await store.load()).entries, isEmpty);
    });

    test('a failed seed save leaves has_seeded unset', () async {
      flaky.failures = 100;

      final seed = expectLater(
        store.seedIfFirstLaunch(seedChanges()),
        throwsA(isA<PersistenceBarrierFailure>()),
      );
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

  group('entry note persistence', () {
    domain.Entry buildNotedEntry(
      String id, {
      String amount = '-12.34',
      String name = 'Coffee',
      String? categoryID,
      String sourceID = 'a',
      String? destinationID,
      String? note,
      bool includeInAnalysis = true,
      domain.SystemEntryKind? systemKind,
    }) => domain.Entry(
      id: id,
      date: DateTime.utc(2026, 3, 14),
      amount: Decimal.parse(amount),
      name: name,
      categoryID: categoryID,
      sourceID: sourceID,
      destinationID: destinationID,
      includeInAnalysis: includeInAnalysis,
      systemKind: systemKind,
      note: note,
    );

    Future<void> seedLedgerHolders() async {
      store.enqueue([
        UpsertAccount(account('a', 'wallet')),
        UpsertAccount(account('b', 'savings')),
        UpsertCategory(category('c1', 'food', parentID: null)),
      ]);
      await store.flushNow();
    }

    Future<void> writeEntryChange(domain.Entry entryValue) async {
      store.enqueue([UpsertEntry(entryValue)]);
      await store.flushNow();
    }

    Future<rows.Entry> selectEntryRow(String id) async =>
        (db.select(db.entries)..where((row) => row.id.equals(id))).getSingle();

    test('aNotedEntryRoundTripsThroughTheStore', () async {
      await seedLedgerHolders();
      final noted = buildNotedEntry(
        'e1',
        categoryID: 'c1',
        note: '  Receipt kept ',
      );
      store.enqueue([UpsertEntry(noted)]);
      await store.flushNow();

      final row = await selectEntryRow('e1');
      expect(row.note, 'Receipt kept');

      final state = await store.load();
      expect(state.entries['e1']!.note, 'Receipt kept');
      expect(
        state.entries['e1'],
        buildNotedEntry('e1', categoryID: 'c1', note: 'Receipt kept'),
      );
    });

    test('aLegacyNullNoteLoadsWithEveryFieldUnchanged', () async {
      await seedLedgerHolders();
      final legacy = buildNotedEntry('e1', categoryID: 'c1');
      await db.into(db.entries).insert(entryToRow(legacy));

      final state = await store.load();

      expect(state.entries['e1']!.note, isNull);
      expect(state.entries['e1']!.amount, Decimal.parse('-12.34'));
      expect(state.entries['e1']!.name, 'Coffee');
      expect(state.entries['e1']!.categoryID, 'c1');
      expect(state.entries['e1']!.sourceID, 'a');
      expect(state.entries['e1']!.date, DateTime.utc(2026, 3, 14));
    });

    test(
      'replacingACategorizedExpenseWithATransferClearsTheCategory',
      () async {
        await seedLedgerHolders();
        await writeEntryChange(
          buildNotedEntry('e-u', categoryID: 'c1', note: 'keep'),
        );

        await writeEntryChange(
          buildNotedEntry(
            'e-u',
            amount: '20',
            sourceID: 'a',
            destinationID: 'b',
          ),
        );

        final row = await selectEntryRow('e-u');
        expect(row.categoryId, isNull);
        expect(row.destinationId, 'b');
        final state = await store.load();
        expect(state.entries['e-u']!.categoryID, isNull);
        expect(state.entries['e-u']!.destinationID, 'b');
        expect(state.entries['e-u']!.note, isNull);
      },
    );

    test(
      'replacingATransferWithACategorizedExpenseClearsTheDestination',
      () async {
        await seedLedgerHolders();
        await writeEntryChange(
          buildNotedEntry(
            'e-u',
            amount: '20',
            destinationID: 'b',
            note: 'keep',
          ),
        );

        await writeEntryChange(buildNotedEntry('e-u', categoryID: 'c1'));

        final row = await selectEntryRow('e-u');
        expect(row.destinationId, isNull);
        expect(row.categoryId, 'c1');
        final state = await store.load();
        expect(state.entries['e-u']!.destinationID, isNull);
        expect(state.entries['e-u']!.categoryID, 'c1');
        expect(state.entries['e-u']!.note, isNull);
      },
    );

    test('replacingANoteWithBlankOrNullClearsTheColumn', () async {
      await seedLedgerHolders();
      await writeEntryChange(buildNotedEntry('e-w', note: 'memo'));
      await writeEntryChange(buildNotedEntry('e-w', note: '   '));
      expect((await selectEntryRow('e-w')).note, isNull);
      expect((await store.load()).entries['e-w']!.note, isNull);

      await writeEntryChange(buildNotedEntry('e-n', note: 'memo'));
      await writeEntryChange(buildNotedEntry('e-n'));
      expect((await selectEntryRow('e-n')).note, isNull);
      expect((await store.load()).entries['e-n']!.note, isNull);
    });

    test('replacingASystemEntryWithAPlainEntryClearsTheKind', () async {
      await seedLedgerHolders();
      await writeEntryChange(
        buildNotedEntry(
          'e-u',
          amount: '250',
          name: 'Opening balance',
          includeInAnalysis: false,
          systemKind: domain.SystemEntryKind.openingBalance,
        ),
      );

      await writeEntryChange(
        buildNotedEntry(
          'e-u',
          amount: '250',
          name: 'Opening balance',
          includeInAnalysis: false,
        ),
      );

      final row = await selectEntryRow('e-u');
      expect(row.systemKind, isNull);
      expect((await store.load()).entries['e-u']!.systemKind, isNull);
    });

    test(
      'aNotedArchivedEntryReloadsIntoTheBinAndKeepsItsNoteOnRestore',
      () async {
        await seedLedgerHolders();
        final noted = buildNotedEntry('e1', note: 'memo');
        store.enqueue([UpsertEntry(noted)]);
        await store.flushNow();

        store.enqueue([
          UpsertEntry(noted.settingLifecycle(LifecycleState.archived)),
        ]);
        await store.flushNow();

        final binned = await store.load();
        expect(binned.entries, isEmpty);
        expect(binned.binnedEntries['e1']!.note, 'memo');

        store.enqueue([UpsertEntry(noted)]);
        await store.flushNow();

        final restored = await store.load();
        expect(restored.binnedEntries, isEmpty);
        expect(restored.entries['e1']!.note, 'memo');
      },
    );
  });

  group('plan note persistence', () {
    domain.RecurringPlan buildNotedPlan(
      String id, {
      String? note,
      DateTime? endDate,
    }) => domain.RecurringPlan(
      id: id,
      template: domain.EntryTemplate(
        amount: Decimal.parse('-15.50'),
        name: 'Gym',
        categoryID: 'c1',
        sourceID: 'a',
        note: note,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 5),
      endDate: endDate,
      lastResolvedDate: DateTime.utc(2026, 1, 5),
    );

    Future<void> seedPlanHolders() async {
      store.enqueue([
        UpsertAccount(account('a', 'wallet')),
        UpsertCategory(category('c1', 'food', parentID: null)),
      ]);
      await store.flushNow();
    }

    Future<void> writePlanChange(domain.RecurringPlan planValue) async {
      store.enqueue([UpsertPlan(planValue)]);
      await store.flushNow();
    }

    Future<rows.Plan> selectPlanRow(String id) async =>
        (db.select(db.plans)..where((row) => row.id.equals(id))).getSingle();

    test('aNotedPlanRoundTripsThroughTheStore', () async {
      await seedPlanHolders();
      store.enqueue([UpsertPlan(buildNotedPlan('p1', note: '  Pack shoes '))]);
      await store.flushNow();

      expect((await selectPlanRow('p1')).templateNote, 'Pack shoes');

      final state = await store.load();
      expect(state.plans['p1']!.template.note, 'Pack shoes');
      expect(state.plans['p1'], buildNotedPlan('p1', note: 'Pack shoes'));
    });

    test('aLegacyNullNoteLoadsWithEveryFieldUnchanged', () async {
      await seedPlanHolders();
      final legacy = buildNotedPlan('p1', endDate: DateTime.utc(2027, 1, 5));
      await db.into(db.plans).insert(planToRow(legacy));

      final state = await store.load();

      expect(state.plans['p1']!.template.note, isNull);
      expect(state.plans['p1']!.template.amount, Decimal.parse('-15.50'));
      expect(state.plans['p1']!.template.name, 'Gym');
      expect(state.plans['p1']!.template.categoryID, 'c1');
      expect(state.plans['p1']!.endDate, DateTime.utc(2027, 1, 5));
    });

    test('replacingANoteWithBlankOrNullClearsTheColumn', () async {
      await seedPlanHolders();
      final end = DateTime.utc(2027, 1, 5);
      await writePlanChange(buildNotedPlan('p-w', note: 'memo', endDate: end));

      await writePlanChange(buildNotedPlan('p-w', note: '   ', endDate: end));
      final cleared = await selectPlanRow('p-w');
      expect(cleared.templateNote, isNull);
      expect(cleared.endDate, millisFromDay(end));
      expect((await store.load()).plans['p-w']!.template.note, isNull);

      await writePlanChange(buildNotedPlan('p-n', note: 'memo'));
      await writePlanChange(buildNotedPlan('p-n'));
      expect((await selectPlanRow('p-n')).templateNote, isNull);
      expect((await store.load()).plans['p-n']!.template.note, isNull);
    });

    test('resolvingFromAReloadedNotedPlanGeneratesNotedOccurrences', () async {
      await seedPlanHolders();
      store.enqueue([UpsertPlan(buildNotedPlan('p1', note: 'memo'))]);
      await store.flushNow();

      final state = await store.load();
      state.resolvePlans(DateTime.utc(2026, 4, 20));

      expect(state.entries, hasLength(3));
      for (final made in state.entries.values) {
        expect(made.note, 'memo');
      }
      expect(state.plans['p1']!.template.note, 'memo');
    });

    test('coalescingKeepsTheFinalClearedNote', () async {
      await seedPlanHolders();
      final noted = UpsertPlan(buildNotedPlan('p-cu', note: 'memo'));
      final cleared = UpsertPlan(buildNotedPlan('p-cu'));
      store.enqueue([noted, cleared]);
      await store.flushNow();

      expect((await selectPlanRow('p-cu')).templateNote, isNull);
      expect((await store.load()).plans['p-cu']!.template.note, isNull);
    });
  });
}
