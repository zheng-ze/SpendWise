import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

void main() {
  test(
    'purgeAccountWhoseEntriesOnlyReferenceItsPocketsKeepsItReferenceOnly',
    () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.addEntry(
        entry(id: uuid(3), amount: Decimal.fromInt(100), sourceID: uuid(2)),
      );

      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));

      expect(
        ledger.moneySources[uuid(1)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
      expect(
        ledger.moneySources[uuid(2)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
    },
  );

  test('deletingLastDirectEntryKeepsAccountWhilePocketStillReferenced', () {
    final ledger = LedgerState();
    ledger.addAccount(account(uuid(1)));
    ledger.addPocket(pocket(uuid(2)), uuid(1));
    ledger.addAccount(account(uuid(5), name: 'other'));
    ledger.addEntry(
      entry(
        id: uuid(3),
        amount: Decimal.fromInt(-10),
        sourceID: uuid(1),
        destinationID: uuid(5),
      ),
    );
    ledger.addEntry(entry(id: uuid(4), sourceID: uuid(2)));
    ledger.deleteAccount(uuid(1));
    ledger.purgeAccount(uuid(1));
    ledger.deleteAccount(uuid(5));
    ledger.purgeAccount(uuid(5));

    final changes = ledger.deleteEntry(uuid(3));

    expect(
      ledger.moneySources[uuid(1)]?.lifecycle,
      LifecycleState.referenceOnly,
    );
    expect(
      ledger.moneySources[uuid(2)]?.lifecycle,
      LifecycleState.referenceOnly,
    );
    expect(ledger.moneySources[uuid(5)], isNull);
    expect(changes, contains(DeleteMoneySource(uuid(5))));
  });

  test('retargetingATransferOffItsDestinationRemovesTheDereferencedRow', () {
    final ledger = LedgerState();
    ledger.addAccount(account(uuid(1)));
    ledger.addAccount(account(uuid(2), name: 'other'));
    ledger.addAccount(account(uuid(5), name: 'dropped'));
    ledger.addEntry(
      entry(
        id: uuid(3),
        amount: Decimal.fromInt(10),
        sourceID: uuid(1),
        destinationID: uuid(5),
      ),
    );
    ledger.deleteAccount(uuid(5));
    ledger.purgeAccount(uuid(5));

    final changes = ledger.updateEntry(
      entry(
        id: uuid(3),
        amount: Decimal.fromInt(10),
        sourceID: uuid(1),
        destinationID: uuid(2),
      ),
    );

    expect(ledger.moneySources[uuid(5)], isNull);
    expect(changes, contains(DeleteMoneySource(uuid(5))));
  });

  test('lastPocketTombstoneCascadesToDereferencedParent', () {
    final ledger = LedgerState();
    ledger.addAccount(account(uuid(1)));
    ledger.addPocket(pocket(uuid(2)), uuid(1));
    ledger.addEntry(entry(id: uuid(3), sourceID: uuid(2)));
    ledger.deleteAccount(uuid(1));
    ledger.purgeAccount(uuid(1));

    final changes = ledger.deleteEntry(uuid(3));

    expect(changes, [
      DeleteEntry(uuid(3)),
      UpsertAccount(account(uuid(1), lifecycle: LifecycleState.referenceOnly)),
      DeleteMoneySource(uuid(2)),
      DeleteMoneySource(uuid(1)),
    ]);
    expect(ledger.moneySources, isEmpty);
  });
}
