import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

/// An account counts as referenced through a surviving pocket, not only through
/// its own entries. Counting direct references alone would let an account funded
/// solely through its pockets be removed while those pockets survived.
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
    // The deleted entry also references an unrelated reference-only account, so
    // a sweep that does nothing fails here rather than passing by inaction.
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
