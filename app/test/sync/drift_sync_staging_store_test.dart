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
    store = DriftSyncStagingStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Builds a conflict group with [siblingCount] mutually concurrent siblings
  /// for [change]. Each sibling carries its own device vector, so no sibling
  /// causally dominates another and the group is valid.
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

  group('contract', () {
    test('is empty when nothing is staged', () async {
      expect(await store.pendingConflicts, isEmpty);
    });

    test('stage adds a conflict group', () async {
      await store.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));

      final pending = await store.pendingConflicts;
      expect(pending, hasLength(1));
      expect(pending.single.collection, SyncCollection.entries);
      expect(pending.single.rowID, 'e1');
    });

    test(
      'stage replaces the prior group for the same collection and row',
      () async {
        await store.stage(
          makeGroup(changeFor(SyncCollection.entries, 'e1'), siblingCount: 2),
        );
        await store.stage(
          makeGroup(changeFor(SyncCollection.entries, 'e1'), siblingCount: 3),
        );

        final pending = await store.pendingConflicts;
        expect(pending, hasLength(1));
        expect(pending.single.siblings, hasLength(3));
      },
    );

    test('resolve removes a group', () async {
      await store.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));

      await store.resolve(makeGroup(changeFor(SyncCollection.entries, 'e1')));

      expect(await store.pendingConflicts, isEmpty);
    });

    test('resolve is an idempotent no-op when the group is absent', () async {
      // Nothing staged; resolving must not throw.
      await store.resolve(makeGroup(changeFor(SyncCollection.entries, 'e1')));
      expect(await store.pendingConflicts, isEmpty);

      // Stage one group, then resolve a different row.
      await store.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));
      await store.resolve(makeGroup(changeFor(SyncCollection.entries, 'e2')));
      expect(await store.pendingConflicts, hasLength(1));
    });

    test('pendingConflicts returns groups oldest first', () async {
      await store.stage(makeGroup(changeFor(SyncCollection.entries, 'e1')));
      await store.stage(makeGroup(changeFor(SyncCollection.entries, 'e2')));

      final pending = await store.pendingConflicts;
      expect(pending.map((c) => c.rowID).toList(), ['e1', 'e2']);

      // Re-staging 'e1' advances its sequence, so it now sorts last.
      await store.stage(
        makeGroup(changeFor(SyncCollection.entries, 'e1'), siblingCount: 2),
      );
      final reordered = await store.pendingConflicts;
      expect(reordered.map((c) => c.rowID).toList(), ['e2', 'e1']);
    });

    test('staged siblings survive a store roundtrip', () async {
      final conflict = makeGroup(changeFor(SyncCollection.entries, 'e1'));
      await store.stage(conflict);

      final read = (await store.pendingConflicts).single;
      // Equality compares collection, row id, and every sibling (decoded change,
      // version vector, and sibling id), so the roundtrip preserved the group.
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
      await store.stage(conflict);

      final read = (await store.pendingConflicts).single;
      expect(read, conflict);
      expect(read.siblings.map((sibling) => sibling.change).toList(), [
        DeleteEntry(rowID),
        DeleteEntry(rowID),
      ]);
    });

    test('staged siblings survive close and reopen', () async {
      // Reopening one file-backed database as two `LedgerDatabase` instances
      // is what separates persisted staging from an in-memory cache, so
      // drift's warning against it is silenced for this test.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final directory = await Directory.systemTemp.createTemp('staging');
      try {
        final path = '${directory.path}${Platform.pathSeparator}ledger.db';
        final conflict = makeGroup(changeFor(SyncCollection.entries, 'e1'));

        final first = persistence.LedgerDatabase(NativeDatabase(File(path)));
        await DriftSyncStagingStore(first).stage(conflict);
        await first.close();

        // A fresh store over the same file reconstructs the staged group,
        // modelling a force-quit between stage and review.
        final second = persistence.LedgerDatabase(NativeDatabase(File(path)));
        try {
          expect(await DriftSyncStagingStore(second).pendingConflicts, [
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
}
