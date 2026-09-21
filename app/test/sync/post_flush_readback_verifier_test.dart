import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/ledger_database.dart' hide Account;
import 'package:spendwise/persistence/mappers.dart';
import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:spendwise/sync/post_flush_readback_verifier.dart';
import 'package:spendwise/sync/row_readback_outcome.dart';
import 'package:sync/sync.dart';

const _rowA = '11111111-1111-1111-1111-111111111111';
const _rowB = '22222222-2222-2222-2222-222222222222';
const _rowC = '33333333-3333-3333-3333-333333333333';
const _rowD = '44444444-4444-4444-4444-444444444444';

Account _account(String id) => Account(
  id: id,
  name: 'Checking',
  type: AccountType.checking,
  subPocketIDs: const {},
  incomingTransfersAsExpenses: false,
  includeInNetWorth: true,
  statementDay: null,
);

void main() {
  late LedgerDatabase db;
  late PostFlushReadbackVerifier verifier;

  setUp(() {
    db = LedgerDatabase(NativeDatabase.memory());
    verifier = PostFlushReadbackVerifier(DriftCollectionVersionReader(db));
  });

  tearDown(() => db.close());

  Future<void> storeAccount(String id, VersionVector version) =>
      db.into(db.accounts).insert(accountToRow(_account(id), version));

  test('an exact stored stamp passes as equal', () async {
    final stamp = VersionVector({'device-a': 1});
    await storeAccount(_rowA, stamp);
    final id = SyncRowID.of(SyncCollection.moneySources, _rowA);

    final outcomes = await verifier.verify({id: stamp});

    expect(outcomes[id], isA<RowReadbackEqual>());
    expect(outcomes[id]!.passed, isTrue);
  });

  test(
    'a stored vector that strictly dominates the stamp passes as dominated',
    () async {
      final stamp = VersionVector({'device-a': 1});
      final stored = VersionVector({'device-a': 1, 'device-b': 1});
      await storeAccount(_rowB, stored);
      final id = SyncRowID.of(SyncCollection.moneySources, _rowB);

      final outcomes = await verifier.verify({id: stamp});

      final outcome = outcomes[id];
      expect(outcome, isA<RowReadbackDominated>());
      expect(outcome!.passed, isTrue);
      expect((outcome as RowReadbackDominated).storedVector, stored);
    },
  );

  test('a missing row is a persistent verification failure', () async {
    final stamp = VersionVector({'device-a': 1});
    final id = SyncRowID.of(SyncCollection.moneySources, _rowC);

    final outcomes = await verifier.verify({id: stamp});

    expect(outcomes[id], isA<RowReadbackMissing>());
    expect(outcomes[id]!.passed, isFalse);
  });

  test('a stored vector neither equal to nor dominating the stamp fails as incompatible', () async {
    final stamp = VersionVector({'device-a': 2});
    final stored = VersionVector({'device-b': 1});
    await storeAccount(_rowD, stored);
    final id = SyncRowID.of(SyncCollection.moneySources, _rowD);

    final outcomes = await verifier.verify({id: stamp});

    final outcome = outcomes[id];
    expect(outcome, isA<RowReadbackIncompatible>());
    expect(outcome!.passed, isFalse);
    expect((outcome as RowReadbackIncompatible).storedVector, stored);
  });

  test('one call verifies stamps across multiple collections', () async {
    final accountStamp = VersionVector({'device-a': 1});
    await storeAccount(_rowA, accountStamp);
    final missingID = SyncRowID.of(SyncCollection.categories, _rowC);
    final accountID = SyncRowID.of(SyncCollection.moneySources, _rowA);

    final outcomes = await verifier.verify({
      accountID: accountStamp,
      missingID: VersionVector({'device-a': 1}),
    });

    expect(outcomes[accountID], isA<RowReadbackEqual>());
    expect(outcomes[missingID], isA<RowReadbackMissing>());
  });
}
