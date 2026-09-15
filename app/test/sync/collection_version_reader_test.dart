import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/ledger_database.dart' hide Account, SubPocket;
import 'package:spendwise/persistence/mappers.dart';
import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:sync/sync.dart';

const _rowA = '11111111-1111-1111-1111-111111111111';
const _rowB = '22222222-2222-2222-2222-222222222222';
const _rowC = '33333333-3333-3333-3333-333333333333';

Account _account(String id, {LifecycleState lifecycle = LifecycleState.active}) =>
    Account(
      id: id,
      name: 'Checking',
      type: AccountType.checking,
      subPocketIDs: const {},
      incomingTransfersAsExpenses: false,
      includeInNetWorth: true,
      statementDay: null,
      lifecycle: lifecycle,
    );

SubPocket _pocket(String id, {LifecycleState lifecycle = LifecycleState.active}) =>
    SubPocket(
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

  test('a live row reads back with its stored vector and live lifecycle', () async {
    final version = VersionVector({'device-a': 2});
    await db
        .into(db.categories)
        .insert(categoryToRow(_category(_rowA), version));

    final result = await reader.readRowVersions(SyncCollection.categories);

    final id = SyncRowID.of(SyncCollection.categories, _rowA);
    expect(result.keys, [id]);
    expect(result[id]!.versionVector, version);
    expect(result[id]!.lifecycle, SiblingLifecycle.live);
  });

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

  test('moneySources unions accounts and subPockets', () async {
    final accountVersion = VersionVector({'device-a': 1});
    final pocketVersion = VersionVector({'device-a': 5});
    await db.into(db.accounts).insert(accountToRow(_account(_rowA), accountVersion));
    await db.into(db.subPockets).insert(pocketToRow(_pocket(_rowB), pocketVersion));

    final result = await reader.readRowVersions(SyncCollection.moneySources);

    final accountID = SyncRowID.of(SyncCollection.moneySources, _rowA);
    final pocketID = SyncRowID.of(SyncCollection.moneySources, _rowB);
    expect(result.keys, unorderedEquals([accountID, pocketID]));
    expect(result[accountID]!.versionVector, accountVersion);
    expect(result[pocketID]!.versionVector, pocketVersion);
  });
}
