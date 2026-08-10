import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  /// Reads outward from the pocket rows, so a pocket nobody claims is caught.
  /// Walking subPocketIDs instead would only visit pockets already claimed.
  void expectNoOrphanPocket(LedgerState ledger) {
    final claimed = <String>{};
    for (final source in ledger.moneySources.values) {
      final account = source.asAccount;
      if (account == null) continue;
      claimed.addAll(account.subPocketIDs);
    }

    final pocketIDs = ledger.moneySources.values
        .map((source) => source.asPocket)
        .nonNulls
        .map((pocket) => pocket.id)
        .toSet();

    expect(
      pocketIDs.difference(claimed),
      isEmpty,
      reason: 'pocket rows with no owning account',
    );
    expect(
      claimed.difference(ledger.moneySources.keys.toSet()),
      isEmpty,
      reason: 'subPocketIDs links with no pocket row',
    );
  }

  group('purgeAccount', () {
    test('takes every pocket row with it when nothing is referenced', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.addPocket(pocket(uuid(3), name: 'second'), uuid(1));
      ledger.deleteAccount(uuid(1));

      ledger.purgeAccount(uuid(1));

      expect(ledger.moneySources, isEmpty);
      expectNoOrphanPocket(ledger);
    });

    test('keeps the account row while a referenced pocket survives', () {
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
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
      expect(
        ledger.moneySources[uuid(2)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
      expectNoOrphanPocket(ledger);
    });

    test('drops the unreferenced pocket and keeps the referenced one', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.addPocket(pocket(uuid(3), name: 'second'), uuid(1));
      ledger.addEntry(
        entry(id: uuid(4), amount: Decimal.fromInt(100), sourceID: uuid(3)),
      );
      ledger.deleteAccount(uuid(1));

      ledger.purgeAccount(uuid(1));

      expect(ledger.moneySources[uuid(2)], isNull);
      expect(
        ledger.moneySources[uuid(3)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(3)});
      expectNoOrphanPocket(ledger);
    });

    test('an account referenced only directly still drops its pockets', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.addEntry(entry(id: uuid(3), sourceID: uuid(1)));
      ledger.deleteAccount(uuid(1));

      ledger.purgeAccount(uuid(1));

      expect(ledger.moneySources[uuid(2)], isNull);
      expect(
        ledger.moneySources[uuid(1)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, isEmpty);
      expectNoOrphanPocket(ledger);
    });
  });

  group('dereference sweep', () {
    test('tombstones the pocket then the parent in one mutation', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.addEntry(entry(id: uuid(3), sourceID: uuid(2)));
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));

      final changes = ledger.deleteEntry(uuid(3));

      expect(ledger.moneySources, isEmpty);
      expect(changes, [
        DeleteEntry(uuid(3)),
        UpsertAccount(
          account(uuid(1), lifecycle: LifecycleState.referenceOnly),
        ),
        DeleteMoneySource(uuid(2)),
        DeleteMoneySource(uuid(1)),
      ]);
      expectNoOrphanPocket(ledger);
    });

    test('the last unreferenced sibling leaves no orphan behind', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.addPocket(pocket(uuid(3), name: 'second'), uuid(1));
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(2)));
      ledger.addEntry(entry(id: uuid(5), sourceID: uuid(3)));
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));

      ledger.deleteEntry(uuid(4));

      expect(ledger.moneySources[uuid(2)], isNull);
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(3)});
      expectNoOrphanPocket(ledger);

      ledger.deleteEntry(uuid(5));

      expect(ledger.moneySources, isEmpty);
      expectNoOrphanPocket(ledger);
    });

    test('a directly referenced parent outlives its swept pocket', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.addEntry(entry(id: uuid(3), sourceID: uuid(2)));
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));

      ledger.deleteEntry(uuid(3));

      expect(ledger.moneySources[uuid(2)], isNull);
      expect(
        ledger.moneySources[uuid(1)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, isEmpty);
      expectNoOrphanPocket(ledger);
    });

    test('retargeting the last reference away sweeps both rows', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.addAccount(account(uuid(5), name: 'other'));
      ledger.addEntry(entry(id: uuid(3), sourceID: uuid(2)));
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));

      ledger.updateEntry(entry(id: uuid(3), sourceID: uuid(5)));

      expect(ledger.moneySources[uuid(2)], isNull);
      expect(ledger.moneySources[uuid(1)], isNull);
      expectNoOrphanPocket(ledger);
    });
  });

  group('deleteAccount', () {
    test('archives the account and its pockets together', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.addPocket(pocket(uuid(3), name: 'second'), uuid(1));

      ledger.deleteAccount(uuid(1));

      expect(ledger.moneySources[uuid(1)]?.lifecycle, LifecycleState.archived);
      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.archived);
      expect(ledger.moneySources[uuid(3)]?.lifecycle, LifecycleState.archived);
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {
        uuid(2),
        uuid(3),
      });
      expectNoOrphanPocket(ledger);
    });

    test('leaves no pocket row more alive than its account', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.addPocket(pocket(uuid(3), name: 'second'), uuid(1));
      ledger.deletePocket(uuid(3));

      ledger.deleteAccount(uuid(1));

      final parent = ledger.moneySources[uuid(1)]!.lifecycle;
      for (final id in [uuid(2), uuid(3)]) {
        expect(
          parent.isAtLeastAsAliveAs(ledger.moneySources[id]!.lifecycle),
          isTrue,
          reason: '$id outlives its account',
        );
      }
      expectNoOrphanPocket(ledger);
    });
  });

  group('purge after a partial cascade', () {
    test('a purge following an archive and restore round trip is clean', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.deleteAccount(uuid(1));
      ledger.restoreAccount(uuid(1));
      ledger.deleteAccount(uuid(1));

      ledger.purgeAccount(uuid(1));

      expect(ledger.moneySources, isEmpty);
      expectNoOrphanPocket(ledger);
    });

    test('purging a pocket first still clears the account afterwards', () {
      final ledger = LedgerState();
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.deletePocket(uuid(2));
      ledger.purgePocket(uuid(2));
      ledger.deleteAccount(uuid(1));

      ledger.purgeAccount(uuid(1));

      expect(ledger.moneySources, isEmpty);
      expectNoOrphanPocket(ledger);
    });
  });
}
