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
  test('revisionStartsAtZero', () {
    expect(Ledger().revision, 0);
  });

  test('localCommitAdvancesRevisionOnce', () {
    final ledger = Ledger();

    ledger.addAccount(_account());

    expect(ledger.revision, 1);
  });

  test('multiChangeCommitAdvancesRevisionOnce', () {
    final ledger = Ledger();
    final account = _account();
    ledger.addAccount(account);

    ledger.addPocket(SubPocket(name: 'pocket'), account.id);

    expect(ledger.revision, 2);
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

  test('emptyResolvePlansLeavesRevisionWithoutPublicationOrNotification', () {
    final ledger = Ledger();
    var publications = 0;
    ledger.bus.subscribe().listen((_) => publications++);
    var notifications = 0;
    ledger.addListener(() => notifications++);

    ledger.resolvePlans(DateTime.utc(2026, 4, 7));

    expect(ledger.revision, 0);
    expect(publications, 0);
    expect(notifications, 0);
  });

  test('emptySyncBatchLeavesRevisionWithoutPublicationOrNotification', () {
    final ledger = Ledger();
    var publications = 0;
    ledger.bus.subscribe().listen((_) => publications++);
    var notifications = 0;
    ledger.addListener(() => notifications++);

    ledger.applySyncBatch([], {});

    expect(ledger.revision, 0);
    expect(publications, 0);
    expect(notifications, 0);
  });

  test('rejectedLocalMutationLeavesRevisionUnchanged', () {
    final ledger = Ledger();
    ledger.addAccount(_account());

    expect(
      () => ledger.addEntry(_entry('4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43')),
      throwsA(isA<UnknownHolder>()),
    );

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

  test('busListenerSeesTheNewRevisionBeforeLedgerNotification', () {
    final ledger = Ledger();
    final order = <String>[];
    var publishedRevision = -1;
    ledger.bus.subscribe().listen((_) {
      publishedRevision = ledger.revision;
      order.add('publish');
    });
    ledger.addListener(() => order.add('notify'));

    ledger.addAccount(_account());

    expect(publishedRevision, 1);
    expect(order, ['publish', 'notify']);
  });
}
