import 'package:domain/domain.dart';
import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/store/device_identity.dart';
import 'package:spendwise/persistence/store/drift_ledger_store.dart';
import 'package:spendwise/persistence/database/ledger_database.dart';
import 'package:spendwise/persistence/database/ledger_database.dart' as rows;
import 'package:spendwise/persistence/store/ledger_store.dart';
import 'package:spendwise/persistence/mappers/mappers.dart';
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

  Future<VersionVector> contentVersion(String table, String id) async {
    final row = await db
        .customSelect(
          'SELECT version_data FROM $table WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingle();
    return versionFromRow(row.read<Uint8List>('version_data'));
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
  });

  group('save bookkeeping', () {});

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

  group('banner reporting', () {});

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

    test('purgingAnArchivedEntryWritesTheTombstone', () async {
      store.enqueue([
        UpsertAccount(account('a', 'wallet')),
        UpsertEntry(
          entry('e1', '12.34').settingLifecycle(LifecycleState.archived),
        ),
      ]);
      await store.flushNow();

      store.enqueue([const DeleteEntry('e1')]);
      await store.flushNow();

      final row = await db.select(db.entries).getSingle();
      expect(row.lifecycle, LifecycleState.tombstoned.code);
      final state = await store.load();
      expect(state.binnedEntries, isEmpty);
      expect(state.entries, isEmpty);
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

    Map<SyncRowID, VersionVector> entryStamps(
      LedgerChange change,
      VersionVector stamp,
    ) => {SyncRowID.of(collectionFor(change), change.targetID): stamp};

    Future<void> writeEntryChange(
      domain.Entry entryValue, {
      required bool stamped,
    }) async {
      final change = UpsertEntry(entryValue);
      if (stamped) {
        store.enqueueStamped([
          change,
        ], entryStamps(change, VersionVector({'remote': 2})));
      } else {
        store.enqueue([change]);
      }
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

    test(
      'replacingACategorizedExpenseWithATransferClearsTheCategory',
      () async {
        await seedLedgerHolders();
        for (final stamped in [false, true]) {
          final id = stamped ? 'e-s' : 'e-u';
          await writeEntryChange(
            buildNotedEntry(id, categoryID: 'c1', note: 'keep'),
            stamped: false,
          );
          final before = versionFromRow((await selectEntryRow(id)).versionData);

          await writeEntryChange(
            buildNotedEntry(
              id,
              amount: '20',
              sourceID: 'a',
              destinationID: 'b',
            ),
            stamped: stamped,
          );

          final row = await selectEntryRow(id);
          expect(row.categoryId, isNull);
          expect(row.destinationId, 'b');
          final after = versionFromRow(row.versionData);
          if (stamped) {
            expect(after, VersionVector({'remote': 2}));
          } else {
            expect(after.dominates(before), isTrue);
          }
          final state = await store.load();
          expect(state.entries[id]!.categoryID, isNull);
          expect(state.entries[id]!.destinationID, 'b');
          expect(state.entries[id]!.note, isNull);
        }
      },
    );

    test(
      'replacingATransferWithACategorizedExpenseClearsTheDestination',
      () async {
        await seedLedgerHolders();
        for (final stamped in [false, true]) {
          final id = stamped ? 'e-s' : 'e-u';
          await writeEntryChange(
            buildNotedEntry(id, amount: '20', destinationID: 'b', note: 'keep'),
            stamped: false,
          );

          await writeEntryChange(
            buildNotedEntry(id, categoryID: 'c1'),
            stamped: stamped,
          );

          final row = await selectEntryRow(id);
          expect(row.destinationId, isNull);
          expect(row.categoryId, 'c1');
          final state = await store.load();
          expect(state.entries[id]!.destinationID, isNull);
          expect(state.entries[id]!.categoryID, 'c1');
          expect(state.entries[id]!.note, isNull);
        }
      },
    );

    test('replacingANoteWithBlankOrNullClearsTheColumn', () async {
      await seedLedgerHolders();
      for (final stamped in [false, true]) {
        final suffix = stamped ? 's' : 'u';
        await writeEntryChange(
          buildNotedEntry('e-w$suffix', note: 'memo'),
          stamped: stamped,
        );
        await writeEntryChange(
          buildNotedEntry('e-w$suffix', note: '   '),
          stamped: stamped,
        );
        expect((await selectEntryRow('e-w$suffix')).note, isNull);
        expect((await store.load()).entries['e-w$suffix']!.note, isNull);

        await writeEntryChange(
          buildNotedEntry('e-n$suffix', note: 'memo'),
          stamped: stamped,
        );
        await writeEntryChange(buildNotedEntry('e-n$suffix'), stamped: stamped);
        expect((await selectEntryRow('e-n$suffix')).note, isNull);
        expect((await store.load()).entries['e-n$suffix']!.note, isNull);
      }
    });

    test('replacingASystemEntryWithAPlainEntryClearsTheKind', () async {
      await seedLedgerHolders();
      for (final stamped in [false, true]) {
        final id = stamped ? 'e-s' : 'e-u';
        await writeEntryChange(
          buildNotedEntry(
            id,
            amount: '250',
            name: 'Opening balance',
            includeInAnalysis: false,
            systemKind: domain.SystemEntryKind.openingBalance,
          ),
          stamped: false,
        );

        await writeEntryChange(
          buildNotedEntry(
            id,
            amount: '250',
            name: 'Opening balance',
            includeInAnalysis: false,
          ),
          stamped: stamped,
        );

        final row = await selectEntryRow(id);
        expect(row.systemKind, isNull);
        expect((await store.load()).entries[id]!.systemKind, isNull);
      }
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

    Map<SyncRowID, VersionVector> planStamps(
      LedgerChange change,
      VersionVector stamp,
    ) => {SyncRowID.of(collectionFor(change), change.targetID): stamp};

    Future<void> writePlanChange(
      domain.RecurringPlan planValue, {
      required bool stamped,
    }) async {
      final change = UpsertPlan(planValue);
      if (stamped) {
        store.enqueueStamped([
          change,
        ], planStamps(change, VersionVector({'remote': 2})));
      } else {
        store.enqueue([change]);
      }
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

    test('replacingANoteWithBlankOrNullClearsTheColumn', () async {
      await seedPlanHolders();
      for (final stamped in [false, true]) {
        final suffix = stamped ? 's' : 'u';
        final end = DateTime.utc(2027, 1, 5);
        await writePlanChange(
          buildNotedPlan('p-w$suffix', note: 'memo', endDate: end),
          stamped: false,
        );
        final before = versionFromRow(
          (await selectPlanRow('p-w$suffix')).versionData,
        );

        await writePlanChange(
          buildNotedPlan('p-w$suffix', note: '   ', endDate: end),
          stamped: stamped,
        );
        final cleared = await selectPlanRow('p-w$suffix');
        expect(cleared.templateNote, isNull);
        expect(cleared.endDate, millisFromDay(end));
        expect((await store.load()).plans['p-w$suffix']!.template.note, isNull);

        final after = versionFromRow(cleared.versionData);
        if (stamped) {
          expect(after, VersionVector({'remote': 2}));
        } else {
          expect(after.dominates(before), isTrue);
        }

        await writePlanChange(
          buildNotedPlan('p-n$suffix', note: 'memo'),
          stamped: false,
        );
        await writePlanChange(buildNotedPlan('p-n$suffix'), stamped: stamped);
        expect((await selectPlanRow('p-n$suffix')).templateNote, isNull);
        expect((await store.load()).plans['p-n$suffix']!.template.note, isNull);
      }
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
  });
}
