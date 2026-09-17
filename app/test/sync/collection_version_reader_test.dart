import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/ledger_database.dart'
    hide Account, SubPocket, Entry, Budget;
import 'package:spendwise/persistence/mappers.dart';
import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:sync/sync.dart';

const _rowA = '11111111-1111-1111-1111-111111111111';
const _rowB = '22222222-2222-2222-2222-222222222222';
const _rowC = '33333333-3333-3333-3333-333333333333';
const _sourceID = 'aaaaaaaa-0000-1111-2222-333333333333';

Account _account(
  String id, {
  LifecycleState lifecycle = LifecycleState.active,
}) => Account(
  id: id,
  name: 'Checking',
  type: AccountType.checking,
  subPocketIDs: const {},
  incomingTransfersAsExpenses: false,
  includeInNetWorth: true,
  statementDay: null,
  lifecycle: lifecycle,
);

SubPocket _pocket(
  String id, {
  LifecycleState lifecycle = LifecycleState.active,
}) => SubPocket(
  id: id,
  name: 'Envelope',
  incomingTransfersAsExpenses: false,
  lifecycle: lifecycle,
);

TransactionCategory _category(
  String id, {
  LifecycleState lifecycle = LifecycleState.active,
}) => TransactionCategory(
  id: id,
  name: 'Groceries',
  kind: CategoryKind.expense,
  colorHex: '#44AA55',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'food',
  lifecycle: lifecycle,
);

Entry _entry(String id) => Entry(
  id: id,
  date: DateTime.utc(2024, 3, 15),
  amount: Decimal.parse('-12.50'),
  name: 'Coffee',
  categoryID: null,
  sourceID: _sourceID,
  destinationID: null,
  includeInAnalysis: true,
);

RecurringPlan _plan(String id) => RecurringPlan(
  id: id,
  template: EntryTemplate(
    amount: Decimal.parse('50.00'),
    name: 'Rent',
    categoryID: null,
    sourceID: _sourceID,
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

void main() {
  late LedgerDatabase db;
  late CollectionVersionReader reader;

  setUp(() {
    db = LedgerDatabase(NativeDatabase.memory());
    reader = DriftCollectionVersionReader(db);
  });

  tearDown(() => db.close());

  test('an empty collection reads back no rows', () async {
    final result = await reader.readRowVersions(SyncCollection.categories);
    expect(result, isEmpty);
  });

  test(
    'a live row reads back with its stored vector and live lifecycle',
    () async {
      final version = VersionVector({'device-a': 2});
      await db
          .into(db.categories)
          .insert(categoryToRow(_category(_rowA), version));

      final result = await reader.readRowVersions(SyncCollection.categories);

      final id = SyncRowID.of(SyncCollection.categories, _rowA);
      expect(result.keys, [id]);
      expect(result[id]!.versionVector, version);
      expect(result[id]!.lifecycle, SiblingLifecycle.live);
    },
  );

  test('a tombstoned row reads back with tombstone lifecycle', () async {
    final version = VersionVector({'device-a': 3});
    await db
        .into(db.categories)
        .insert(
          categoryToRow(
            _category(_rowB, lifecycle: LifecycleState.tombstoned),
            version,
          ),
        );

    final result = await reader.readRowVersions(SyncCollection.categories);

    final id = SyncRowID.of(SyncCollection.categories, _rowB);
    expect(result[id]!.lifecycle, SiblingLifecycle.tombstone);
  });

  test('an archived row reads back as live, not tombstone', () async {
    final version = VersionVector({'device-a': 1});
    await db
        .into(db.categories)
        .insert(
          categoryToRow(
            _category(_rowC, lifecycle: LifecycleState.archived),
            version,
          ),
        );

    final result = await reader.readRowVersions(SyncCollection.categories);

    final id = SyncRowID.of(SyncCollection.categories, _rowC);
    expect(result[id]!.lifecycle, SiblingLifecycle.live);
  });

  test(
    'an entries row reads back with its stored vector and live lifecycle',
    () async {
      final version = VersionVector({'device-a': 4});
      await db.into(db.entries).insert(entryToRow(_entry(_rowA), version));

      final result = await reader.readRowVersions(SyncCollection.entries);

      final id = SyncRowID.of(SyncCollection.entries, _rowA);
      expect(result.keys, [id]);
      expect(result[id]!.versionVector, version);
      expect(result[id]!.lifecycle, SiblingLifecycle.live);
    },
  );

  test(
    'a plans row reads back with its stored vector and live lifecycle',
    () async {
      final version = VersionVector({'device-a': 6});
      await db.into(db.plans).insert(planToRow(_plan(_rowB), version));

      final result = await reader.readRowVersions(SyncCollection.plans);

      final id = SyncRowID.of(SyncCollection.plans, _rowB);
      expect(result.keys, [id]);
      expect(result[id]!.versionVector, version);
      expect(result[id]!.lifecycle, SiblingLifecycle.live);
    },
  );

  test(
    'a budgets row reads back with its stored vector and live lifecycle',
    () async {
      final version = VersionVector({'device-a': 7});
      await db.into(db.budgets).insert(budgetToRow(_budget(_rowC), version));

      final result = await reader.readRowVersions(SyncCollection.budgets);

      final id = SyncRowID.of(SyncCollection.budgets, _rowC);
      expect(result.keys, [id]);
      expect(result[id]!.versionVector, version);
      expect(result[id]!.lifecycle, SiblingLifecycle.live);
    },
  );

  test('moneySources unions accounts and subPockets', () async {
    final accountVersion = VersionVector({'device-a': 1});
    final pocketVersion = VersionVector({'device-a': 5});
    await db
        .into(db.accounts)
        .insert(accountToRow(_account(_rowA), accountVersion));
    await db
        .into(db.subPockets)
        .insert(pocketToRow(_pocket(_rowB), pocketVersion));

    final result = await reader.readRowVersions(SyncCollection.moneySources);

    final accountID = SyncRowID.of(SyncCollection.moneySources, _rowA);
    final pocketID = SyncRowID.of(SyncCollection.moneySources, _rowB);
    expect(result.keys, unorderedEquals([accountID, pocketID]));
    expect(result[accountID]!.versionVector, accountVersion);
    expect(result[pocketID]!.versionVector, pocketVersion);
  });

  group('orphan tombstones', () {
    // Seeds an orphan directly against the table: no content row exists for
    // the key, so the union can only see the orphan.
    Future<void> seedOrphan(
      SyncCollection collection,
      String rowID,
      VersionVector version,
    ) => db
        .into(db.syncOrphanTombstones)
        .insert(
          OrphanTombstoneRow(
            collection: collection,
            rowId: rowID,
            versionData: version,
          ),
        );

    test('an orphan-only row reads back with its vector and tombstone '
        'lifecycle', () async {
      final version = VersionVector({'remote-a': 2});
      await seedOrphan(SyncCollection.categories, _rowA, version);

      final result = await reader.readRowVersions(SyncCollection.categories);

      final id = SyncRowID.of(SyncCollection.categories, _rowA);
      expect(result.keys, [id]);
      expect(result[id]!.versionVector, version);
      expect(result[id]!.lifecycle, SiblingLifecycle.tombstone);
    });

    test('content wins when both hold the same key', () async {
      final contentVersion = VersionVector({'device-a': 3});
      await db
          .into(db.categories)
          .insert(categoryToRow(_category(_rowA), contentVersion));
      await seedOrphan(
        SyncCollection.categories,
        _rowA,
        VersionVector({'remote-a': 9}),
      );

      final result = await reader.readRowVersions(SyncCollection.categories);

      final id = SyncRowID.of(SyncCollection.categories, _rowA);
      expect(result.keys, [id]);
      expect(result[id]!.versionVector, contentVersion);
      expect(result[id]!.lifecycle, SiblingLifecycle.live);
    });

    test('moneySources unions accounts, subPockets, and orphans', () async {
      final accountVersion = VersionVector({'device-a': 1});
      final pocketVersion = VersionVector({'device-a': 5});
      final orphanVersion = VersionVector({'remote-a': 2});
      await db
          .into(db.accounts)
          .insert(accountToRow(_account(_rowA), accountVersion));
      await db
          .into(db.subPockets)
          .insert(pocketToRow(_pocket(_rowB), pocketVersion));
      await seedOrphan(SyncCollection.moneySources, _rowC, orphanVersion);

      final result = await reader.readRowVersions(SyncCollection.moneySources);

      final accountID = SyncRowID.of(SyncCollection.moneySources, _rowA);
      final pocketID = SyncRowID.of(SyncCollection.moneySources, _rowB);
      final orphanID = SyncRowID.of(SyncCollection.moneySources, _rowC);
      expect(result.keys, unorderedEquals([accountID, pocketID, orphanID]));
      expect(result[accountID]!.versionVector, accountVersion);
      expect(result[pocketID]!.versionVector, pocketVersion);
      expect(result[orphanID]!.versionVector, orphanVersion);
      expect(result[orphanID]!.lifecycle, SiblingLifecycle.tombstone);
    });

    test('an entries orphan reads back as a tombstone', () async {
      final version = VersionVector({'remote-a': 4});
      await seedOrphan(SyncCollection.entries, _rowA, version);

      final result = await reader.readRowVersions(SyncCollection.entries);

      final id = SyncRowID.of(SyncCollection.entries, _rowA);
      expect(result.keys, [id]);
      expect(result[id]!.versionVector, version);
      expect(result[id]!.lifecycle, SiblingLifecycle.tombstone);
    });

    test('a plans orphan reads back as a tombstone', () async {
      final version = VersionVector({'remote-a': 6});
      await seedOrphan(SyncCollection.plans, _rowB, version);

      final result = await reader.readRowVersions(SyncCollection.plans);

      final id = SyncRowID.of(SyncCollection.plans, _rowB);
      expect(result.keys, [id]);
      expect(result[id]!.versionVector, version);
      expect(result[id]!.lifecycle, SiblingLifecycle.tombstone);
    });

    test('a budgets orphan reads back as a tombstone', () async {
      final version = VersionVector({'remote-a': 7});
      await seedOrphan(SyncCollection.budgets, _rowC, version);

      final result = await reader.readRowVersions(SyncCollection.budgets);

      final id = SyncRowID.of(SyncCollection.budgets, _rowC);
      expect(result.keys, [id]);
      expect(result[id]!.versionVector, version);
      expect(result[id]!.lifecycle, SiblingLifecycle.tombstone);
    });
  });
}
