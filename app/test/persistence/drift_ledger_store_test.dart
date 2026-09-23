import 'package:domain/domain.dart';
import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/drift_ledger_store.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/persistence/mappers.dart';
import 'package:sync/sync.dart';

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

  Future<int> versionBumpsOnAccount(String id) async {
    final row = await (db.select(
      db.accounts,
    )..where((row) => row.id.equals(id))).getSingle();
    return versionFromRow(row.versionData).counters.values.single;
  }

  Future<Map<String, VersionVector>> orphanVectors(
    SyncCollection collection,
  ) async {
    final found = await db
        .customSelect(
          'SELECT row_id, version_data FROM sync_orphan_tombstones '
          'WHERE collection = ?',
          variables: [Variable<String>(collection.wireName)],
        )
        .get();
    return {
      for (final row in found)
        row.read<String>('row_id'): versionFromRow(
          row.read<Uint8List>('version_data'),
        ),
    };
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

      expect(row.amount, '10');
    });

    test('a budget upsert followed by a delete of the same id applies only the delete', () async {
      domain.Budget budget(String amount) => domain.Budget(
        id: 'b1',
        categoryID: 'c1',
        limitEvents: [
          LimitEvent(
            effectiveFromMonth: null,
            value: Decimal.parse(amount),
            kind: LimitEventKind.defaultLimit,
          ),
        ],
        createdAtMonth: const YearMonth(2026, 1),
      );

      store.enqueue([UpsertBudget(budget('10'))]);
      await debouncedSave();

      store
        ..enqueue([UpsertBudget(budget('99'))])
        ..enqueue([const DeleteBudget('b1')]);

      await debouncedSave();

      final row = await db.select(db.budgets).getSingle();
      expect(row.lifecycle, LifecycleState.tombstoned.code);

      expect(row.limitEvents, contains('"value":"10"'));
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
      expect(await versionBumpsOnAccount('a1'), 1);
    });

    test('saves are serialized behind one in-flight future', () async {
      store.enqueue([UpsertAccount(account('a1', 'v1'))]);
      await settle();

      final first = store.flushNow();
      final second = store.flushNow();
      await Future.wait([first, second]);
      await settle();

      final row = await db.select(db.accounts).getSingle();
      expect(versionFromRow(row.versionData).counters.values.single, 1);
      expect(flaky.transactionAttempts, 1);
    });
  });

  group('terminal save failure', () {
    Future<void> corruptVersion(String id) => db.customUpdate(
      'UPDATE accounts SET version_data = ? WHERE id = ?',
      variables: [
        Variable<Uint8List>(Uint8List.fromList([0xff, 0xfe])),
        Variable<String>(id),
      ],
      updates: {db.accounts},
    );

    test('a corrupt version vector reports the terminal state once', () async {
      store.enqueue([UpsertAccount(account('a1', 'wallet'))]);
      await debouncedSave();
      expect((await db.select(db.accounts).getSingle()).name, 'wallet');

      await corruptVersion('a1');
      reported.clear();

      store.enqueue([UpsertAccount(account('a1', 'changed name'))]);
      await debouncedSave();

      expect(reported, [SaveBannerState.permanentlyFailed]);

      for (var i = 0; i < 10; i++) {
        expect(clock.armedCount, 0);
        clock.fire();
        await settle();
      }
      expect(reported, [SaveBannerState.permanentlyFailed]);

      expect((await db.select(db.accounts).getSingle()).name, 'wallet');
    });

    test('the terminal save never drains the pending batch', () async {
      store.enqueue([UpsertAccount(account('a1', 'wallet'))]);
      await debouncedSave();

      await corruptVersion('a1');
      reported.clear();

      store.enqueue([UpsertAccount(account('a1', 'changed name'))]);
      final flush = expectLater(
        store.flushNow(),
        throwsA(
          isA<PersistenceBarrierFailure>()
              .having(
                (error) => error.cause,
                'cause',
                isA<PermanentSaveError>(),
              )
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

      expect(reported.last, SaveBannerState.permanentlyFailed);
      expect(store.pendingCount, 1);

      expect((await db.select(db.accounts).getSingle()).name, 'wallet');
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

    test(
      'a budget upsert stores an active row and a delete tombstones',
      () async {
        final budget = domain.Budget(
          id: 'b1',
          categoryID: 'c1',
          limitEvents: [
            LimitEvent(
              effectiveFromMonth: null,
              value: Decimal.fromInt(500),
              kind: LimitEventKind.defaultLimit,
            ),
          ],
          createdAtMonth: const YearMonth(2026, 1),
        );

        store.enqueue([UpsertBudget(budget)]);
        await debouncedSave();
        expect(
          (await db.select(db.budgets).getSingle()).lifecycle,
          LifecycleState.active.code,
        );

        store.enqueue([const DeleteBudget('b1')]);
        await debouncedSave();

        expect(
          (await db.select(db.budgets).getSingle()).lifecycle,
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

    domain.Budget budget(String id) => domain.Budget(
      id: id,
      categoryID: 'c1',
      limitEvents: [
        LimitEvent(
          effectiveFromMonth: null,
          value: Decimal.fromInt(500),
          kind: LimitEventKind.defaultLimit,
        ),
      ],
      createdAtMonth: const YearMonth(2026, 1),
    );

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

      final counters = versionFromRow(row.read<Uint8List>('version_data'))
          .counters;
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

    test('budgetPersistsAndTombstonesAcrossLoad', () async {
      store.enqueue([
        UpsertCategory(category('c1', 'food', parentID: null)),
        UpsertBudget(budget('b1')),
      ]);
      await store.flushNow();

      expect((await store.load()).budgets.keys.toSet(), {'b1'});

      store.enqueue([const DeleteBudget('b1')]);
      await store.flushNow();

      expect((await store.load()).budgets, isEmpty);
      expect(
        (await db.select(db.budgets).getSingle()).lifecycle,
        LifecycleState.tombstoned.code,
      );
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

      final state = await store.load();
      expect(state.moneySources.keys.toSet(), {'a1'});
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

  group('stamped ingestion', () {
    Map<SyncRowID, VersionVector> stampsFor(
      LedgerChange change,
      VersionVector stamp,
    ) => {SyncRowID.of(collectionFor(change), change.targetID): stamp};

    Future<VersionVector> accountVersion(String id) async => versionFromRow(
      (await (db.select(
        db.accounts,
      )..where((row) => row.id.equals(id))).getSingle()).versionData,
    );

    test(
      'a stamped upsert persists its stamp verbatim without a local bump',
      () async {
        final stamp = VersionVector({'remote-a': 3});
        final change = UpsertAccount(account('a1', 'remote'));
        store.enqueueStamped([change], stampsFor(change, stamp));

        await debouncedSave();

        final row = await db.select(db.accounts).getSingle();
        expect(row.name, 'remote');
        expect(versionFromRow(row.versionData), stamp);
      },
    );

    test('stamped batches flattened by the drain keep their stamps', () async {
      final first = UpsertAccount(account('a1', 'remote-a1'));
      final second = UpsertAccount(account('a2', 'remote-a2'));
      final firstStamp = VersionVector({'remote-a': 1});
      final secondStamp = VersionVector({'remote-b': 2});
      store.enqueueStamped([first], stampsFor(first, firstStamp));
      store.enqueueStamped([second], stampsFor(second, secondStamp));

      await store.flushNow();

      expect(await accountVersion('a1'), firstStamp);
      expect(await accountVersion('a2'), secondStamp);
    });

    test('a stamped remote then local edit stores local content with a '
        'dominating vector', () async {
      final remote = UpsertEntry(entry('e1', '10'));
      final stamp = VersionVector({'remote-a': 2});
      store.enqueueStamped([remote], stampsFor(remote, stamp));
      store.enqueue([UpsertEntry(entry('e1', '42'))]);

      await debouncedSave();

      final row = await db.select(db.entries).getSingle();
      expect(row.amount, '42');
      expect(
        versionFromRow(row.versionData),
        VersionVector({'remote-a': 2, await deviceID(db): 1}),
      );
    });

    test('a local edit then stamped remote stores remote content with its '
        'stamp verbatim', () async {
      store.enqueue([UpsertEntry(entry('e1', '10'))]);
      final remote = UpsertEntry(entry('e1', '99'));
      final stamp = VersionVector({'remote-a': 5});
      store.enqueueStamped([remote], stampsFor(remote, stamp));

      await debouncedSave();

      final row = await db.select(db.entries).getSingle();
      expect(row.amount, '99');
      expect(versionFromRow(row.versionData), stamp);
    });

    test(
      'every observed stamp contributes to the carried maximum independently '
      'of last arrival',
      () async {
        final first = UpsertAccount(account('a1', 'remote-v1'));
        final second = UpsertAccount(account('a1', 'remote-v2'));
        store.enqueueStamped([
          first,
        ], stampsFor(first, VersionVector({'remote-a': 1})));
        store.enqueueStamped([
          second,
        ], stampsFor(second, VersionVector({'remote-b': 1})));
        store.enqueue([UpsertAccount(account('a1', 'local'))]);

        await debouncedSave();

        final row = await db.select(db.accounts).getSingle();
        expect(row.name, 'local');
        expect(
          versionFromRow(row.versionData),
          VersionVector({'remote-a': 1, 'remote-b': 1, await deviceID(db): 1}),
        );
      },
    );

    test('a stamped survivor keeps its own stamp verbatim', () async {
      final first = UpsertAccount(account('a1', 'remote-v1'));
      final second = UpsertAccount(account('a1', 'remote-v2'));
      store.enqueueStamped([
        first,
      ], stampsFor(first, VersionVector({'remote-a': 1})));
      final survivorStamp = VersionVector({'remote-b': 1});
      store.enqueueStamped([second], stampsFor(second, survivorStamp));

      await debouncedSave();

      final row = await db.select(db.accounts).getSingle();
      expect(row.name, 'remote-v2');
      expect(versionFromRow(row.versionData), survivorStamp);
    });

    test(
      'a stamp survives a failed attempt and lands verbatim on retry',
      () async {
        flaky.failures = 1;
        final change = UpsertAccount(account('a1', 'remote'));
        final stamp = VersionVector({'remote-a': 4});
        store.enqueueStamped([change], stampsFor(change, stamp));

        await debouncedSave();
        expect(reported, [SaveBannerState.retrying]);
        expect(await db.select(db.accounts).get(), isEmpty);

        clock.fire();
        await settle();

        final row = await db.select(db.accounts).getSingle();
        expect(row.name, 'remote');
        expect(versionFromRow(row.versionData), stamp);
        expect(reported.last, SaveBannerState.clear);
      },
    );

    test(
      'a local edit buffered mid-save still dominates the stamped prefix',
      () async {
        final remote = UpsertAccount(account('a1', 'remote'));
        final stamp = VersionVector({'remote-a': 2});
        store.enqueueStamped([remote], stampsFor(remote, stamp));
        await settle();

        flaky.onTransactionBegin = () {
          store.enqueue([UpsertAccount(account('a1', 'local'))]);
        };

        await store.flushNow();

        final row = await db.select(db.accounts).getSingle();
        expect(row.name, 'local');
        expect(
          versionFromRow(row.versionData),
          VersionVector({'remote-a': 2, await deviceID(db): 1}),
        );
      },
    );

    test('an upsert pocket followed by delete money source coalesces to one '
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
      final pocket = await db.select(db.subPockets).getSingle();
      expect(pocket.lifecycle, LifecycleState.tombstoned.code);
      expect(pocket.name, 'original');
    });

    test(
      'a stamped pocket and delete coalesce to one stamped deletion',
      () async {
        store.enqueue([
          UpsertPocket(domain.SubPocket(id: 'p1', name: 'original')),
        ]);
        await debouncedSave();

        final pocket = UpsertPocket(
          domain.SubPocket(id: 'p1', name: 'replacement'),
        );
        store.enqueueStamped([
          pocket,
        ], stampsFor(pocket, VersionVector({'remote-a': 1})));
        const deletion = DeleteMoneySource('p1');
        final deleteStamp = VersionVector({'remote-a': 2});
        store.enqueueStamped([deletion], stampsFor(deletion, deleteStamp));

        await debouncedSave();

        expect(await db.select(db.accounts).get(), isEmpty);
        final row = await db.select(db.subPockets).getSingle();
        expect(row.lifecycle, LifecycleState.tombstoned.code);
        expect(row.name, 'original');
        expect(versionFromRow(row.versionData), deleteStamp);
      },
    );

    test('identical ids in different collections stay independent', () async {
      final accountChange = UpsertAccount(account('shared', 'wallet'));
      final entryChange = UpsertEntry(entry('shared', '10'));
      final accountStamp = VersionVector({'remote-a': 1});
      final entryStamp = VersionVector({'remote-b': 2});
      store.enqueueStamped(
        [accountChange, entryChange],
        {
          ...stampsFor(accountChange, accountStamp),
          ...stampsFor(entryChange, entryStamp),
        },
      );

      await debouncedSave();

      expect((await db.select(db.accounts).getSingle()).name, 'wallet');
      expect((await db.select(db.entries).getSingle()).amount, '10');
      expect(await accountVersion('shared'), accountStamp);
      expect(
        versionFromRow((await db.select(db.entries).getSingle()).versionData),
        entryStamp,
      );
    });

    test('an empty stamps map keeps the local bump path', () async {
      store.enqueueStamped([UpsertAccount(account('a1', 'v1'))], {});

      await debouncedSave();

      expect(await versionBumpsOnAccount('a1'), 1);
    });

    test(
      'a stamped delete persists its stamp verbatim on the tombstone',
      () async {
        store.enqueue([UpsertEntry(entry('e1', '10'))]);
        await debouncedSave();

        const deletion = DeleteEntry('e1');
        final stamp = VersionVector({'remote-a': 7});
        store.enqueueStamped([deletion], stampsFor(deletion, stamp));

        await debouncedSave();

        final row = await db.select(db.entries).getSingle();
        expect(row.lifecycle, LifecycleState.tombstoned.code);
        expect(versionFromRow(row.versionData), stamp);
      },
    );

    test(
      'a stamped delete for an absent id persists an orphan tombstone',
      () async {
        const deletion = DeleteEntry('ghost');
        final stamp = VersionVector({'remote-a': 1});
        store.enqueueStamped([deletion], stampsFor(deletion, stamp));

        await debouncedSave();

        expect(reported, isEmpty);
        expect(await db.select(db.entries).get(), isEmpty);
        expect(await orphanVectors(SyncCollection.entries), {'ghost': stamp});
      },
    );
  });

  group('orphan tombstones', () {
    Map<SyncRowID, VersionVector> stampsFor(
      LedgerChange change,
      VersionVector stamp,
    ) => {SyncRowID.of(collectionFor(change), change.targetID): stamp};

    Future<VersionVector> contentVersion(String table, String id) async {
      final row = await db
          .customSelect(
            'SELECT version_data FROM $table WHERE id = ?',
            variables: [Variable<String>(id)],
          )
          .getSingle();
      return versionFromRow(row.read<Uint8List>('version_data'));
    }

    test('a stamped money-source delete absent from both tables writes an '
        'orphan', () async {
      const deletion = DeleteMoneySource('ghost');
      final stamp = VersionVector({'remote-a': 2});
      store.enqueueStamped([deletion], stampsFor(deletion, stamp));

      await debouncedSave();

      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.subPockets).get(), isEmpty);
      expect(await orphanVectors(SyncCollection.moneySources), {
        'ghost': stamp,
      });
    });

    test(
      'a stamped money-source delete hitting accounts writes no orphan',
      () async {
        store.enqueue([UpsertAccount(account('a1', 'wallet'))]);
        await debouncedSave();

        const deletion = DeleteMoneySource('a1');
        final stamp = VersionVector({'remote-a': 2});
        store.enqueueStamped([deletion], stampsFor(deletion, stamp));

        await debouncedSave();

        expect(
          (await db.select(db.accounts).getSingle()).lifecycle,
          LifecycleState.tombstoned.code,
        );
        expect(await orphanVectors(SyncCollection.moneySources), isEmpty);
      },
    );

    test(
      'a stamped money-source delete hitting pockets writes no orphan',
      () async {
        store.enqueue([
          UpsertPocket(domain.SubPocket(id: 'p1', name: 'envelope')),
        ]);
        await debouncedSave();

        const deletion = DeleteMoneySource('p1');
        final stamp = VersionVector({'remote-a': 2});
        store.enqueueStamped([deletion], stampsFor(deletion, stamp));

        await debouncedSave();

        expect(
          (await db.select(db.subPockets).getSingle()).lifecycle,
          LifecycleState.tombstoned.code,
        );
        expect(await orphanVectors(SyncCollection.moneySources), isEmpty);
      },
    );

    test('an unstamped delete for an absent id writes no orphan', () async {
      store.enqueue([
        const DeleteMoneySource('ghost'),
        const DeleteCategory('ghost'),
        const DeleteEntry('ghost'),
        const DeletePlan('ghost'),
        const DeleteBudget('ghost'),
      ]);

      await debouncedSave();

      expect(reported, isEmpty);
      for (final collection in SyncCollection.values) {
        expect(await orphanVectors(collection), isEmpty);
      }
    });

    test('duplicate delivery of the same stamp is idempotent', () async {
      const deletion = DeleteEntry('ghost');
      final stamp = VersionVector({'remote-a': 1});
      store.enqueueStamped([deletion], stampsFor(deletion, stamp));
      await debouncedSave();

      store.enqueueStamped([deletion], stampsFor(deletion, stamp));
      await debouncedSave();

      expect(await orphanVectors(SyncCollection.entries), {'ghost': stamp});
    });

    test('a later different stamp replaces the stored orphan vector', () async {
      const deletion = DeleteEntry('ghost');
      store.enqueueStamped([
        deletion,
      ], stampsFor(deletion, VersionVector({'remote-a': 1})));
      await debouncedSave();

      final replacement = VersionVector({'remote-a': 2, 'remote-b': 1});
      store.enqueueStamped([deletion], stampsFor(deletion, replacement));
      await debouncedSave();

      expect(await orphanVectors(SyncCollection.entries), {
        'ghost': replacement,
      });
    });

    test('an uppercase-id stamped deletion stores its orphan under the '
        'lowercase key', () async {
      const deletion = DeleteEntry('GHOST-ROW');
      final stamp = VersionVector({'remote-a': 1});
      store.enqueueStamped([deletion], stampsFor(deletion, stamp));

      await debouncedSave();

      expect(await orphanVectors(SyncCollection.entries), {'ghost-row': stamp});
    });

    test('a stamped upsert absorbs its orphan and clears it', () async {
      const deletion = DeleteEntry('e1');
      final orphan = VersionVector({'remote-o': 5});
      store.enqueueStamped([deletion], stampsFor(deletion, orphan));
      await debouncedSave();

      final stamp = VersionVector({'remote-s': 1});
      final upsert = UpsertEntry(entry('e1', '10'));
      store.enqueueStamped([upsert], stampsFor(upsert, stamp));
      await debouncedSave();

      expect(await orphanVectors(SyncCollection.entries), isEmpty);
      expect(
        await contentVersion('entries', 'e1'),
        VersionVector({'remote-o': 5, 'remote-s': 1}),
      );
    });

    test(
      'an unstamped upsert absorbs its orphan under a device bump',
      () async {
        const deletion = DeleteEntry('e1');
        store.enqueueStamped([
          deletion,
        ], stampsFor(deletion, VersionVector({'remote-o': 3})));
        await debouncedSave();

        store.enqueue([UpsertEntry(entry('e1', '10'))]);
        await debouncedSave();

        expect(await orphanVectors(SyncCollection.entries), isEmpty);
        expect(
          await contentVersion('entries', 'e1'),
          VersionVector({'remote-o': 3, await deviceID(db): 1}),
        );
      },
    );

    test('a stamped survivor ignores stamps carried from discarded '
        'occurrences', () async {
      const deletion = DeleteEntry('e9');
      store.enqueueStamped([
        deletion,
      ], stampsFor(deletion, VersionVector({'remote-o': 2})));
      await debouncedSave();

      final first = UpsertEntry(entry('e9', '10'));
      final second = UpsertEntry(entry('e9', '99'));
      store.enqueueStamped([
        first,
      ], stampsFor(first, VersionVector({'remote-a': 1})));
      store.enqueueStamped([
        second,
      ], stampsFor(second, VersionVector({'remote-b': 1})));
      await debouncedSave();

      final row = await db.select(db.entries).getSingle();
      expect(row.amount, '99');
      expect(
        versionFromRow(row.versionData),
        VersionVector({'remote-o': 2, 'remote-b': 1}),
      );
      expect(await orphanVectors(SyncCollection.entries), isEmpty);
    });

    test(
      'an unstamped survivor folds the orphan into its carried floor',
      () async {
        const deletion = DeleteEntry('e8');
        store.enqueueStamped([
          deletion,
        ], stampsFor(deletion, VersionVector({'remote-o': 3})));
        await debouncedSave();

        final first = UpsertEntry(entry('e8', '10'));
        store.enqueueStamped([
          first,
        ], stampsFor(first, VersionVector({'remote-c': 1})));
        store.enqueue([UpsertEntry(entry('e8', '42'))]);
        await debouncedSave();

        final row = await db.select(db.entries).getSingle();
        expect(row.amount, '42');
        expect(
          versionFromRow(row.versionData),
          VersionVector({'remote-o': 3, 'remote-c': 1, await deviceID(db): 1}),
        );
        expect(await orphanVectors(SyncCollection.entries), isEmpty);
      },
    );

    test('a lowercase upsert absorbs an orphan stored from an uppercase '
        'delete', () async {
      const deletion = DeleteEntry('ABSORB-ME');
      store.enqueueStamped([
        deletion,
      ], stampsFor(deletion, VersionVector({'remote-o': 1})));
      await debouncedSave();
      expect(
        await orphanVectors(SyncCollection.entries),
        contains('absorb-me'),
      );

      store.enqueue([UpsertEntry(entry('absorb-me', '10'))]);
      await debouncedSave();

      expect(await orphanVectors(SyncCollection.entries), isEmpty);
      expect((await db.select(db.entries).getSingle()).amount, '10');
    });

    test('orphan X, live sub-pocket X, delete X, reload leaves X absent with '
        'a vector descending from the orphan', () async {
      final orphan = VersionVector({'remote-o': 4});
      store.enqueueStamped([
        const DeleteMoneySource('ac2x'),
      ], stampsFor(const DeleteMoneySource('ac2x'), orphan));
      await debouncedSave();

      store.enqueue([
        UpsertPocket(domain.SubPocket(id: 'ac2x', name: 'envelope')),
      ]);
      await debouncedSave();

      store.enqueue([const DeleteMoneySource('ac2x')]);
      await debouncedSave();

      final state = await store.load();
      expect(state.moneySources, isEmpty);

      final row = await db.select(db.subPockets).getSingle();
      expect(row.lifecycle, LifecycleState.tombstoned.code);
      expect(versionFromRow(row.versionData).dominates(orphan), isTrue);
      expect(await orphanVectors(SyncCollection.moneySources), isEmpty);
    });

    test('a corrupt orphan vector reports the terminal state once', () async {
      await db.customStatement(
        "INSERT INTO sync_orphan_tombstones (collection, row_id, version_data) "
        "VALUES ('entries', 'e1', X'FFFE')",
      );
      reported.clear();

      store.enqueue([UpsertEntry(entry('e1', '10'))]);
      await debouncedSave();

      expect(reported, [SaveBannerState.permanentlyFailed]);

      for (var i = 0; i < 10; i++) {
        expect(clock.armedCount, 0);
        clock.fire();
        await settle();
      }
      expect(reported, [SaveBannerState.permanentlyFailed]);

      final orphans = await db
          .customSelect(
            'SELECT row_id FROM sync_orphan_tombstones '
            "WHERE collection = 'entries'",
          )
          .get();
      expect([for (final row in orphans) row.read<String>('row_id')], ['e1']);
      expect(await db.select(db.entries).get(), isEmpty);
    });
  });
}
