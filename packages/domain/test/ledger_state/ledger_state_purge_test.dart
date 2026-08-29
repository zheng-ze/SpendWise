import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

void main() {
  late LedgerState ledger;

  setUp(() {
    ledger = LedgerState();
    ledger.addAccount(account(uuid(1), name: 'main'));
    ledger.addPocket(pocket(uuid(2)), uuid(1));
    ledger.addAccount(account(uuid(3), name: 'other'));
  });

  group('purgePocket', () {
    test('removes the row and the parent link together', () {
      ledger.deletePocket(uuid(2));

      final changes = ledger.purgePocket(uuid(2));

      expect(ledger.moneySources[uuid(2)], isNull);
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, isEmpty);
      expect(changes, [
        UpsertAccount(ledger.moneySources[uuid(1)]!.asAccount!),
        DeleteMoneySource(uuid(2)),
      ]);
    });

    test('the detach upsert carries the link already dropped', () {
      ledger.deletePocket(uuid(2));

      final changes = ledger.purgePocket(uuid(2));

      final detached = (changes.first as UpsertAccount).account;
      expect(detached.subPocketIDs, isEmpty);
      expect(detached.id, uuid(1));
    });

    test('a referenced pocket survives as referenceOnly', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(2)));
      ledger.deletePocket(uuid(2));

      final changes = ledger.purgePocket(uuid(2));

      expect(
        ledger.moneySources[uuid(2)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
      expect(changes, [UpsertPocket(ledger.moneySources[uuid(2)]!.asPocket!)]);
    });

    test('an active pocket is a no-op', () {
      final changes = ledger.purgePocket(uuid(2));

      expect(changes, isEmpty);
      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.active);
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
    });

    test('a missing id is a no-op', () {
      final before = {...ledger.moneySources};

      expect(ledger.purgePocket(uuid(9)), isEmpty);
      expect(ledger.moneySources, before);
    });

    test('an account id is a no-op', () {
      ledger.deleteAccount(uuid(1));
      final before = {...ledger.moneySources};

      final changes = ledger.purgePocket(uuid(1));

      expect(changes, isEmpty);
      expect(ledger.moneySources, before);
    });
  });

  group('purgeAccount', () {
    test('removes an unreferenced account with no pockets', () {
      ledger.deleteAccount(uuid(3));

      final changes = ledger.purgeAccount(uuid(3));

      expect(ledger.moneySources[uuid(3)], isNull);
      expect(changes, [DeleteMoneySource(uuid(3))]);
    });

    test('keeps a directly referenced account with no pockets', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(3)));
      ledger.deleteAccount(uuid(3));

      final changes = ledger.purgeAccount(uuid(3));

      expect(
        ledger.moneySources[uuid(3)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
      expect(changes, [
        UpsertAccount(ledger.moneySources[uuid(3)]!.asAccount!),
      ]);
    });

    test('emits every pocket change before the account change', () {
      ledger.addPocket(pocket(uuid(8), name: 'second'), uuid(1));
      ledger.deleteAccount(uuid(1));

      final changes = ledger.purgeAccount(uuid(1));

      expect(ledger.moneySources[uuid(1)], isNull);
      expect(ledger.moneySources[uuid(2)], isNull);
      expect(ledger.moneySources[uuid(8)], isNull);
      // The two pockets purge in subPocketIDs order, which is unspecified, so
      // this only asserts that the account trails both of them.
      expect(changes.last, DeleteMoneySource(uuid(1)));
      expect(changes, hasLength(5));
      expect(changes.whereType<DeleteMoneySource>().map((c) => c.targetID), [
        uuid(2),
        uuid(8),
        uuid(1),
      ]);
    });

    test(
      'a single tombstoning pocket emits the whole change list in order',
      () {
        ledger.deleteAccount(uuid(1));

        final changes = ledger.purgeAccount(uuid(1));

        expect(changes, [
          UpsertAccount(
            account(uuid(1), name: 'main')
                .removeSubPocket(uuid(2))
                .settingLifecycle(LifecycleState.archived),
          ),
          DeleteMoneySource(uuid(2)),
          DeleteMoneySource(uuid(1)),
        ]);
      },
    );

    test(
      'a surviving referenceOnly pocket keeps the account referenceOnly',
      () {
        ledger.addEntry(
          entry(id: uuid(4), amount: Decimal.fromInt(100), sourceID: uuid(2)),
        );
        ledger.deleteAccount(uuid(1));

        final changes = ledger.purgeAccount(uuid(1));

        expect(
          ledger.moneySources[uuid(2)]?.lifecycle,
          LifecycleState.referenceOnly,
        );
        expect(
          ledger.moneySources[uuid(1)]?.lifecycle,
          LifecycleState.referenceOnly,
        );
        expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {
          uuid(2),
        });
        expect(changes, [
          UpsertPocket(ledger.moneySources[uuid(2)]!.asPocket!),
          UpsertAccount(ledger.moneySources[uuid(1)]!.asAccount!),
        ]);
      },
    );

    test('an unreferenced pocket goes while a referenced sibling stays', () {
      ledger.addPocket(pocket(uuid(8), name: 'second'), uuid(1));
      ledger.addEntry(
        entry(id: uuid(4), amount: Decimal.fromInt(100), sourceID: uuid(8)),
      );
      ledger.deleteAccount(uuid(1));

      ledger.purgeAccount(uuid(1));

      expect(ledger.moneySources[uuid(2)], isNull);
      expect(
        ledger.moneySources[uuid(8)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(8)});
    });

    test('an active account is a no-op', () {
      final before = {...ledger.moneySources};

      final changes = ledger.purgeAccount(uuid(1));

      expect(changes, isEmpty);
      expect(ledger.moneySources, before);
    });

    test('a referenceOnly account is a no-op', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));

      expect(ledger.purgeAccount(uuid(1)), isEmpty);
      expect(
        ledger.moneySources[uuid(1)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
    });

    test('a missing id is a no-op', () {
      final before = {...ledger.moneySources};

      expect(ledger.purgeAccount(uuid(9)), isEmpty);
      expect(ledger.moneySources, before);
    });

    test('a pocket id is a no-op', () {
      ledger.deletePocket(uuid(2));
      final before = {...ledger.moneySources};

      final changes = ledger.purgeAccount(uuid(2));

      expect(changes, isEmpty);
      expect(ledger.moneySources, before);
    });
  });

  group('purge never touches entries', () {
    test('purgeAccount leaves the entries map unchanged', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      ledger.addEntry(
        entry(id: uuid(5), amount: Decimal.fromInt(100), sourceID: uuid(2)),
      );
      ledger.addEntry(
        entry(id: uuid(6), amount: Decimal.fromInt(-20), sourceID: uuid(3)),
      );
      ledger.deleteAccount(uuid(1));
      final before = {...ledger.entries};

      final changes = ledger.purgeAccount(uuid(1));

      expect(ledger.entries, before);
      expect(changes.whereType<DeleteEntry>(), isEmpty);
      expect(changes.whereType<UpsertEntry>(), isEmpty);
    });

    test('a tombstoning purge leaves unrelated entries unchanged', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(3)));
      ledger.deleteAccount(uuid(1));
      final before = {...ledger.entries};

      ledger.purgeAccount(uuid(1));

      expect(ledger.entries, before);
    });
  });
}
