import 'dart:io';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/ledger_database.dart' show LedgerDatabase;
import 'package:spendwise/sync/drift_sync_staging_store.dart';
import 'package:sync/sync.dart';

const _rowA = '11111111-1111-1111-1111-111111111111';
const _rowB = '22222222-2222-2222-2222-222222222222';
const _rowC = '33333333-3333-3333-3333-333333333333';

// Fails the commit of the next [failures] transactions, then behaves
// normally. Drift rolls the failed transaction back itself; throwing here
// keeps that real rollback in the path.
class FailingCommitInterceptor extends QueryInterceptor {
  int failures = 0;

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    if (failures > 0) {
      failures--;
      throw const _CommitFailure();
    }
    return super.commitTransaction(inner);
  }
}

class _CommitFailure implements Exception {
  const _CommitFailure();
}

Account _account(String id) => Account(
  id: id,
  name: 'Checking',
  type: AccountType.checking,
  subPocketIDs: const {},
  incomingTransfersAsExpenses: false,
  includeInNetWorth: true,
  statementDay: null,
);

TransactionCategory _category(String id) => TransactionCategory(
  id: id,
  name: 'Groceries',
  kind: CategoryKind.expense,
  colorHex: '#44AA55',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'food',
);

Entry _entry(String id) => Entry(
  id: id,
  date: DateTime.utc(2024, 3, 15),
  amount: Decimal.parse('-12.50'),
  name: 'Coffee',
  categoryID: null,
  sourceID: 'aaaaaaaa-0000-1111-2222-333333333333',
  destinationID: null,
  includeInAnalysis: true,
);

RecurringPlan _plan(String id) => RecurringPlan(
  id: id,
  template: EntryTemplate(
    amount: Decimal.parse('50.00'),
    name: 'Rent',
    categoryID: null,
    sourceID: 'aaaaaaaa-0000-1111-2222-333333333333',
    destinationID: null,
    includeInAnalysis: true,
  ),
  frequency: RecurrenceFrequency.monthly,
  anchor: DateTime.utc(2024, 1, 1),
  endDate: null,
  lastResolvedDate: DateTime.utc(2024, 6, 1),
);

Budget _budget(String id) => Budget(
  id: id,
  categoryID: null,
  limitEvents: <LimitEvent>[
    LimitEvent(
      effectiveFromMonth: const YearMonth(2024, 1),
      value: Decimal.parse('100.00'),
      kind: LimitEventKind.defaultLimit,
    ),
  ],
  createdAtMonth: const YearMonth(2024, 1),
);

LedgerChange _liveChange(SyncCollection collection, String rowID) {
  switch (collection) {
    case SyncCollection.moneySources:
      return UpsertAccount(_account(rowID));
    case SyncCollection.categories:
      return UpsertCategory(_category(rowID));
    case SyncCollection.entries:
      return UpsertEntry(_entry(rowID));
    case SyncCollection.plans:
      return UpsertPlan(_plan(rowID));
    case SyncCollection.budgets:
      return UpsertBudget(_budget(rowID));
  }
}

// Each sibling gets its own device key so distinct siblings are pairwise
// concurrent, matching what reconcile()'s frontier reduction produces for a
// genuine conflict group.
DecodedSibling _sibling(
  SyncCollection collection,
  String rowID,
  String device, {
  LedgerChange? change,
}) => DecodedSibling(
  VersionVector({device: 1}),
  change ?? _liveChange(collection, rowID),
  'sibling-$rowID-$device',
);

StagedConflict _conflict(
  SyncCollection collection,
  String rowID, {
  String firstDevice = 'device-a',
  String secondDevice = 'device-b',
}) => StagedConflict(collection, rowID, [
  _sibling(collection, rowID, '$firstDevice-$rowID'),
  _sibling(collection, rowID, '$secondDevice-$rowID'),
]);

void main() {
  late LedgerDatabase db;
  late DriftSyncStagingStore store;

  setUp(() async {
    db = LedgerDatabase(NativeDatabase.memory());
    store = await DriftSyncStagingStore.open(db);
  });

  tearDown(() => db.close());

  group('stage', () {
    test('round-trips a group with live and tombstone siblings', () async {
      final conflict = StagedConflict(SyncCollection.entries, _rowA, [
        _sibling(SyncCollection.entries, _rowA, 'device-a'),
        _sibling(
          SyncCollection.entries,
          _rowA,
          'device-b',
          change: DeleteEntry(_rowA),
        ),
      ]);
      await store.stageConflict(conflict);
      expect(await store.pendingConflictList(), [conflict]);
    });

    test('replaces the prior group for the same collection and row', () async {
      await store.stageConflict(_conflict(SyncCollection.entries, _rowA));
      final replacement = StagedConflict(SyncCollection.entries, _rowA, [
        _sibling(SyncCollection.entries, _rowA, 'device-c'),
        _sibling(SyncCollection.entries, _rowA, 'device-d'),
      ]);
      await store.stageConflict(replacement);
      final pending = await store.pendingConflictList();
      expect(pending, hasLength(1));
      expect(pending.single, replacement);
    });

    test('keeps distinct groups for different rows', () async {
      await store.stageConflict(_conflict(SyncCollection.entries, _rowA));
      await store.stageConflict(_conflict(SyncCollection.entries, _rowB));
      expect(await store.pendingConflictList(), hasLength(2));
    });

    test(
      'keeps distinct groups for the same row in different collections',
      () async {
        await store.stageConflict(_conflict(SyncCollection.entries, _rowA));
        await store.stageConflict(_conflict(SyncCollection.categories, _rowA));
        expect(await store.pendingConflictList(), hasLength(2));
      },
    );

    test('round-trips a live group for every collection', () async {
      for (final collection in SyncCollection.values) {
        await store.stageConflict(_conflict(collection, _rowA));
      }
      final pending = await store.pendingConflictList();
      expect(pending, hasLength(SyncCollection.values.length));
      for (final collection in SyncCollection.values) {
        expect(
          pending.singleWhere((group) => group.collection == collection),
          _conflict(collection, _rowA),
        );
      }
    });

    test('preserves sibling order inside a group', () async {
      final conflict = StagedConflict(SyncCollection.entries, _rowA, [
        _sibling(SyncCollection.entries, _rowA, 'device-a'),
        _sibling(SyncCollection.entries, _rowA, 'device-b'),
        _sibling(SyncCollection.entries, _rowA, 'device-c'),
      ]);
      await store.stageConflict(conflict);
      final pending = await store.pendingConflictList();
      expect(pending.single.siblings, [
        _sibling(SyncCollection.entries, _rowA, 'device-a'),
        _sibling(SyncCollection.entries, _rowA, 'device-b'),
        _sibling(SyncCollection.entries, _rowA, 'device-c'),
      ]);
    });
  });

  group('pendingConflicts', () {
    test('returns groups oldest first', () async {
      final first = _conflict(SyncCollection.entries, _rowA);
      final second = _conflict(SyncCollection.entries, _rowB);
      final third = _conflict(SyncCollection.entries, _rowC);
      await store.stageConflict(first);
      await store.stageConflict(second);
      await store.stageConflict(third);
      expect(await store.pendingConflictList(), [first, second, third]);
    });

    test('a replacement moves to the newest position', () async {
      final first = _conflict(SyncCollection.entries, _rowA);
      final second = _conflict(SyncCollection.entries, _rowB);
      await store.stageConflict(first);
      await store.stageConflict(second);
      await store.stageConflict(first);
      expect(await store.pendingConflictList(), [second, first]);
    });
  });

  group('resolve', () {
    test('removes the matching group', () async {
      final conflict = _conflict(SyncCollection.entries, _rowA);
      await store.stageConflict(conflict);
      await store.resolveConflict(conflict);
      expect(await store.pendingConflictList(), isEmpty);
    });

    test('keeps other groups when resolving one', () async {
      await store.stageConflict(_conflict(SyncCollection.entries, _rowA));
      final other = _conflict(SyncCollection.entries, _rowB);
      await store.stageConflict(other);
      await store.resolveConflict(_conflict(SyncCollection.entries, _rowA));
      expect(await store.pendingConflictList(), [other]);
    });

    test('is an idempotent no-op when the group is absent', () async {
      final conflict = _conflict(SyncCollection.entries, _rowA);
      await store.resolveConflict(conflict);
      expect(await store.pendingConflictList(), isEmpty);
      await store.stageConflict(conflict);
      await store.resolveConflict(conflict);
      await store.resolveConflict(conflict);
      expect(await store.pendingConflictList(), isEmpty);
    });
  });

  group('package contract through the synchronous interface', () {
    test('stage, pendingConflicts, and resolve work after flush', () async {
      final SyncStagingStore contract = store;
      final conflict = _conflict(SyncCollection.entries, _rowA);
      contract.stage(conflict);
      await store.flush();
      expect(contract.pendingConflicts, [conflict]);

      contract.resolve(conflict);
      await store.flush();
      expect(contract.pendingConflicts, isEmpty);
    });

    test('flush with no pending writes completes', () async {
      await store.flush();
      expect(store.pendingConflicts, isEmpty);
    });
  });

  group('transaction atomicity and rollback', () {
    test('a failed stage leaves no partial group behind', () async {
      final flaky = FailingCommitInterceptor();
      final fragileDb = LedgerDatabase(
        NativeDatabase.memory().interceptWith(flaky),
      );
      addTearDown(fragileDb.close);
      final fragile = await DriftSyncStagingStore.open(fragileDb);

      flaky.failures = 1;
      await expectLater(
        fragile.stageConflict(_conflict(SyncCollection.entries, _rowA)),
        throwsA(isA<_CommitFailure>()),
      );
      expect(await fragile.pendingConflictList(), isEmpty);

      await fragile.stageConflict(_conflict(SyncCollection.entries, _rowA));
      expect(await fragile.pendingConflictList(), hasLength(1));
    });

    test('a failed resolve keeps the staged group', () async {
      final flaky = FailingCommitInterceptor();
      final fragileDb = LedgerDatabase(
        NativeDatabase.memory().interceptWith(flaky),
      );
      addTearDown(fragileDb.close);
      final fragile = await DriftSyncStagingStore.open(fragileDb);

      final conflict = _conflict(SyncCollection.entries, _rowA);
      await fragile.stageConflict(conflict);
      flaky.failures = 1;
      await expectLater(
        fragile.resolveConflict(conflict),
        throwsA(isA<_CommitFailure>()),
      );
      expect(await fragile.pendingConflictList(), [conflict]);
    });
  });

  group('restart durability', () {
    test('staged groups survive close and reopen', () async {
      final directory = await Directory.systemTemp.createTemp(
        'spendwise-staging-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      LedgerDatabase open() => LedgerDatabase(
        NativeDatabase(File('${directory.path}/spendwise.db')),
      );

      final first = open();
      final writer = await DriftSyncStagingStore.open(first);
      final oldest = _conflict(SyncCollection.entries, _rowA);
      final newest = StagedConflict(SyncCollection.categories, _rowB, [
        _sibling(SyncCollection.categories, _rowB, 'device-a'),
        _sibling(
          SyncCollection.categories,
          _rowB,
          'device-b',
          change: DeleteCategory(_rowB),
        ),
      ]);
      await writer.stageConflict(oldest);
      await writer.stageConflict(newest);
      await first.close();

      final second = open();
      addTearDown(second.close);
      final reader = await DriftSyncStagingStore.open(second);
      expect(await reader.pendingConflictList(), [oldest, newest]);
    });
  });
}
