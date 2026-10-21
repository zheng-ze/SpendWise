import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:sync/sync.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

Entry _entry(String sourceID) =>
    Entry(amount: Decimal.fromInt(-10), name: 'entry', sourceID: sourceID);

VersionVector _stamp(int counter) =>
    VersionVector({'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa': counter});

void main() {
  test('localCommitAdvancesRevisionOnce', () {
    final ledger = Ledger();

    ledger.addAccount(_account());

    expect(ledger.revision, 1);
  });
  test('stampedSyncCommitAdvancesRevisionOnce', () {
    final ledger = Ledger();
    final account = _account();
    final changes = <LedgerChange>[UpsertAccount(account)];

    ledger.applySyncBatch(changes, {
      SyncRowID.of(SyncCollection.moneySources, account.id): _stamp(3),
    });

    expect(ledger.revision, 1);
  });
  test('rejectedSyncBatchLeavesRevisionUnchanged', () {
    final ledger = Ledger();
    final orphan = _entry('4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43');
    var notifications = 0;
    ledger.addListener(() => notifications++);

    expect(
      () => ledger.applySyncBatch(
        [UpsertEntry(orphan)],
        {SyncRowID.of(SyncCollection.entries, orphan.id): _stamp(1)},
      ),
      throwsA(isA<StateError>()),
    );

    expect(ledger.revision, 0);
    expect(notifications, 0);
  });
}
