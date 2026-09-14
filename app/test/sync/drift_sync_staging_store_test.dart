import 'dart:async';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart';
import 'package:spendwise/persistence/ledger_database.dart' as persistence;
import 'package:spendwise/sync/drift_sync_staging_store.dart';

String siblingDevice(int i) => 'device-$i';

void main() {
  late persistence.LedgerDatabase db;
  late DriftSyncStagingStore store;

  setUp(() async {
    db = persistence.LedgerDatabase(NativeDatabase.memory());
    store = await DriftSyncStagingStore.open(db);
  });

  tearDown(() async {
    // Drains write-through writes before closing. Staging calls return
    // synchronously and persist in the background.
    await store.flush();
    await db.close();
  });

  // Builds a valid group. Each sibling uses its own vector so none
  // dominates another.
  StagedConflict makeGroup(LedgerChange change, {int siblingCount = 2}) {
    final collection = collectionFor(change);
    final rowID = normalizedID(change.targetID);
    return StagedConflict(collection, rowID, [
      for (var i = 0; i < siblingCount; i++)
        DecodedSibling(
          VersionVector({siblingDevice(i): 1}),
          change,
          'sibling-$i',
        ),
    ]);
  }

  LedgerChange changeFor(SyncCollection collection, String rowID) {
    final id = normalizedID(rowID);
    switch (collection) {
      case SyncCollection.moneySources:
        return UpsertAccount(
          Account(id: id, name: 'acct-$id', type: AccountType.cash),
        );
      case SyncCollection.entries:
        return UpsertEntry(
          Entry(
            id: id,
            date: DateTime.utc(2026, 1, 1),
            amount: Decimal.parse('1'),
            name: 'n',
            sourceID: id,
          ),
        );
      case SyncCollection.categories:
        return UpsertCategory(
          TransactionCategory(
            id: id,
            name: 'cat-$id',
            kind: CategoryKind.expense,
            colorHex: '#ff0000',
            includeInAnalysis: true,
            parentID: null,
            symbol: 'fork',
          ),
        );
      case SyncCollection.plans:
        return UpsertPlan(
          RecurringPlan(
            id: id,
            template: EntryTemplate(
              amount: Decimal.parse('1'),
              name: 'rent',
              sourceID: id,
            ),
            frequency: RecurrenceFrequency.monthly,
            anchor: DateTime.utc(2026, 1, 1),
            lastResolvedDate: DateTime.utc(2026, 1, 1),
          ),
        );
      case SyncCollection.budgets:
        return UpsertBudget(
          Budget(
            id: id,
            categoryID: id,
            limitEvents: const [],
            createdAtMonth: const YearMonth(2026, 1),
          ),
        );
    }
  }

  group('engine seam', () {
    test('satisfies the SyncStagingStore interface', () {
      // Assigning to the package seam type proves the store compiles as the
      // actual SyncStagingStore the engine receives, not a lookalike.
      final SyncStagingStore seam = store;
      final group = makeGroup(changeFor(SyncCollection.entries, 'e1'));

      seam.stage(group);
      expect(seam.pendingConflicts, [group]);

      seam.resolve(group);
      expect(seam.pendingConflicts, isEmpty);
    });

    test('can be injected into SyncEngine as its staging store', () {
      final SyncStagingStore seam = store;
      final engine = SyncEngine(
        userID: 'device-a',
        keyAccessor: () async => Uint8List(0),
        stagingStore: seam,
      );
      expect(engine, isA<SyncEngine>());
    });

    test('synchronous reads observe writes immediately', () {
      expect(store.pendingConflicts, isEmpty);

      store.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));

      expect(store.pendingConflicts, hasLength(1));
      expect(store.pendingConflicts.single.rowID, 'e1');
    });
  });

  group('contract', () {
    test('is empty when nothing is staged', () {
      expect(store.pendingConflicts, isEmpty);
    });

    test('stage adds a conflict group', () {
      store.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));

      final pending = store.pendingConflicts;
      expect(pending, hasLength(1));
      expect(pending.single.collection, SyncCollection.entries);
      expect(pending.single.rowID, 'e1');
    });

    test('stage replaces the prior group for the same collection and row', () {
      store.stage(
        makeGroup(changeFor(SyncCollection.entries, 'e1'), siblingCount: 2),
      );
      store.stage(
        makeGroup(changeFor(SyncCollection.entries, 'e1'), siblingCount: 3),
      );

      final pending = store.pendingConflicts;
      expect(pending, hasLength(1));
      expect(pending.single.siblings, hasLength(3));
    });

    test(
      'stage replaces only the matching collection for one shared row id',
      () async {
        // Stages one shared row id in two collections. Replacing one group
        // leaves the other intact.
        store.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));
        store.stage(makeGroup(changeFor(SyncCollection.categories, 'e1')));
        expect(store.pendingConflicts, hasLength(2));

        store.stage(
          makeGroup(changeFor(SyncCollection.entries, 'e1'), siblingCount: 3),
        );
        await store.flush();

        final pending = store.pendingConflicts;
        expect(pending, hasLength(2));
        final entries = pending.firstWhere(
          (group) => group.collection == SyncCollection.entries,
        );
        final categories = pending.firstWhere(
          (group) => group.collection == SyncCollection.categories,
        );
        expect(entries.siblings, hasLength(3));
        expect(categories.siblings, hasLength(2));

        // The durable rows match the cache with two keyed rows.
        final reloaded = await DriftSyncStagingStore.open(db);
        expect(reloaded.pendingConflicts, hasLength(2));
        expect(
          reloaded.pendingConflicts.map((group) => group.collection).toSet(),
          {SyncCollection.entries, SyncCollection.categories},
        );
      },
    );

    test('resolve removes a group', () {
      store.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));

      store.resolve(makeGroup(changeFor(SyncCollection.entries, 'e1')));

      expect(store.pendingConflicts, isEmpty);
    });

    test('resolve is an idempotent no-op when the group is absent', () {
      // No group exists. Resolving throws nothing.
      store.resolve(makeGroup(changeFor(SyncCollection.entries, 'e1')));
      expect(store.pendingConflicts, isEmpty);

      // Stage one group, then resolve a different row.
      store.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));
      store.resolve(makeGroup(changeFor(SyncCollection.entries, 'e2')));
      expect(store.pendingConflicts, hasLength(1));
    });

    test('pendingConflicts returns groups oldest first', () {
      store.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));
      store.stage(makeGroup(changeFor(SyncCollection.entries, 'e2')));

      final pending = store.pendingConflicts;
      expect(pending.map((c) => c.rowID).toList(), ['e1', 'e2']);

      // Re-staging 'e1' advances its sequence, so it now sorts last.
      store.stage(
        makeGroup(changeFor(SyncCollection.entries, 'e1'), siblingCount: 2),
      );
      final reordered = store.pendingConflicts;
      expect(reordered.map((c) => c.rowID).toList(), ['e2', 'e1']);
    });

    test('staged siblings survive a store roundtrip', () async {
      final conflict = makeGroup(changeFor(SyncCollection.entries, 'e1'));
      store.stage(conflict);
      await store.flush();

      // Reloading from Drift reconstructs the same in-memory state.
      final reloaded = await DriftSyncStagingStore.open(db);
      final read = reloaded.pendingConflicts.single;
      // Equality checks every sibling field, so the roundtrip preserves
      // the group.
      expect(read, conflict);
    });

    test('tombstone siblings roundtrip to deletes for the group row', () async {
      // Deletes encode as empty payloads, so the decode path must rebuild the
      // delete from the group row id rather than the sibling id.
      final rowID = normalizedID('e1');
      final conflict = StagedConflict(SyncCollection.entries, rowID, [
        DecodedSibling(
          VersionVector({'device-0': 1}),
          DeleteEntry(rowID),
          'sibling-0',
        ),
        DecodedSibling(
          VersionVector({'device-1': 1}),
          DeleteEntry(rowID),
          'sibling-1',
        ),
      ]);
      store.stage(conflict);
      await store.flush();

      final reloaded = await DriftSyncStagingStore.open(db);
      final read = reloaded.pendingConflicts.single;
      expect(read, conflict);
      expect(read.siblings.map((sibling) => sibling.change).toList(), [
        DeleteEntry(rowID),
        DeleteEntry(rowID),
      ]);
    });

    test('staged siblings survive close and reopen', () async {
      // Opens one file with two database objects to prove durable staging.
      // Silences the multiple-database warning for this test.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final directory = await Directory.systemTemp.createTemp('staging');
      try {
        final path = '${directory.path}${Platform.pathSeparator}ledger.db';
        final conflict = makeGroup(changeFor(SyncCollection.entries, 'e1'));

        final first = persistence.LedgerDatabase(NativeDatabase(File(path)));
        final firstStore = await DriftSyncStagingStore.open(first);
        firstStore.stage(conflict);
        await firstStore.flush();
        await first.close();

        // A fresh store over the same file reconstructs the staged group,
        // modelling a force-quit between stage and review.
        final second = persistence.LedgerDatabase(NativeDatabase(File(path)));
        try {
          expect((await DriftSyncStagingStore.open(second)).pendingConflicts, [
            conflict,
          ]);
        } finally {
          await second.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  group('write-through failures', () {
    test(
      'a failed durable write surfaces instead of diverging silently',
      () async {
        final failures = <Object>[];
        final localDb = persistence.LedgerDatabase(NativeDatabase.memory());
        addTearDown(localDb.close);
        final local = await DriftSyncStagingStore.open(
          localDb,
          onWriteError: (error, _) => failures.add(error),
        );
        // Dropping the table forces every subsequent write-through to fail,
        // the way a full disk or a corrupt page would.
        await localDb.customStatement('DROP TABLE sync_staging_group');

        local.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));
        await expectLater(local.flush(), throwsA(isA<Exception>()));
        expect(failures, hasLength(1));
        // The cache keeps what the database lost for the callback to show.
        expect(local.pendingConflicts, hasLength(1));

        // A failed write never blocks later ones. The next write still runs
        // and reports.
        local.resolve(makeGroup(changeFor(SyncCollection.entries, 'e1')));
        await expectLater(local.flush(), throwsA(isA<Exception>()));
        expect(failures, hasLength(2));
      },
    );

    test(
      'flush throws the first failure even when a later write succeeds',
      () async {
        final failures = <Object>[];
        final firstFailure = Completer<void>();
        final localDb = persistence.LedgerDatabase(NativeDatabase.memory());
        addTearDown(localDb.close);
        final local = await DriftSyncStagingStore.open(
          localDb,
          onWriteError: (error, _) {
            failures.add(error);
            if (!firstFailure.isCompleted) {
              firstFailure.complete();
            }
          },
        );
        final stagingDdl = await localDb
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type = 'table' "
              "AND name = 'sync_staging_group'",
            )
            .getSingle();
        // Dropping the table forces the next write-through to fail, the way
        // a full disk or a corrupt page would.
        await localDb.customStatement('DROP TABLE sync_staging_group');

        local.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));
        // Waits for the first failure before restoring the table. This keeps
        // the failure and success split deterministic.
        await firstFailure.future;

        // Restores the table from saved DDL, so the next write succeeds.
        await localDb.customStatement(stagingDdl.read<String>('sql'));
        local.stage(makeGroup(changeFor(SyncCollection.entries, 'e2')));

        // The later write succeeds, but flush still reports the earlier
        // failure that never reached the database.
        await expectLater(local.flush(), throwsA(isA<Exception>()));
        expect(failures, hasLength(1));

        // The cache holds both groups, but only the later write reached
        // the database.
        expect(local.pendingConflicts.map((group) => group.rowID).toList(), [
          'e1',
          'e2',
        ]);
        final reloaded = await DriftSyncStagingStore.open(localDb);
        expect(reloaded.pendingConflicts.map((group) => group.rowID).toList(), [
          'e2',
        ]);
      },
    );
  });
}
