import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  late LedgerState ledger;

  setUp(() {
    ledger = LedgerState();
    ledger.addAccount(account(uuid(1), name: 'main'));
    ledger.addPocket(pocket(uuid(2)), uuid(1));
    ledger.addAccount(account(uuid(3), name: 'other'));
  });

  group('deleteAccount', () {
    test('archives it with its pockets and retains entries', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      ledger.addEntry(entry(id: uuid(5), sourceID: uuid(2)));
      ledger.addEntry(entry(id: uuid(6), sourceID: uuid(3)));

      final changes = ledger.deleteAccount(uuid(1));

      expect(ledger.moneySources[uuid(1)]?.lifecycle, LifecycleState.archived);
      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.archived);
      expect(ledger.moneySources[uuid(3)]?.lifecycle, LifecycleState.active);
      expect(ledger.entries, hasLength(3));
      expect(changes, [
        UpsertAccount(ledger.moneySources[uuid(1)]!.asAccount!),
        UpsertPocket(ledger.moneySources[uuid(2)]!.asPocket!),
      ]);
    });

    test('keeps the pocket links for restore', () {
      ledger.deleteAccount(uuid(1));

      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
    });

    test('leaves a non-active pocket untouched', () {
      ledger.deletePocket(uuid(2));
      final changes = ledger.deleteAccount(uuid(1));

      expect(changes, [
        UpsertAccount(ledger.moneySources[uuid(1)]!.asAccount!),
      ]);
    });

    test('emits no deleteMoneySource', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      final changes = ledger.deleteAccount(uuid(1));

      expect(changes.whereType<DeleteMoneySource>(), isEmpty);
    });

    test('the emitted payloads carry the archived lifecycle', () {
      final changes = ledger.deleteAccount(uuid(1));

      expect(changes.map((change) => change.targetID), [uuid(1), uuid(2)]);
      final archived = (changes[0] as UpsertAccount).account;
      expect(archived.lifecycle, LifecycleState.archived);
      expect(archived.subPocketIDs, {uuid(2)});
      expect(
        (changes[1] as UpsertPocket).pocket.lifecycle,
        LifecycleState.archived,
      );
    });

    test('an already archived account is a no-op', () {
      ledger.deleteAccount(uuid(1));

      expect(ledger.deleteAccount(uuid(1)), isEmpty);
    });

    test('a missing id is a no-op', () {
      expect(ledger.deleteAccount(uuid(9)), isEmpty);
    });
  });

  group('deletePocket', () {
    test('archives it keeping the parent link and entries', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(2)));
      final changes = ledger.deletePocket(uuid(2));

      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.archived);
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
      expect(ledger.entries, hasLength(1));
      expect(changes, [UpsertPocket(ledger.moneySources[uuid(2)]!.asPocket!)]);
    });

    test('does not re-emit the parent', () {
      final changes = ledger.deletePocket(uuid(2));

      expect(changes.whereType<UpsertAccount>(), isEmpty);
    });

    test('an already archived pocket is a no-op', () {
      ledger.deletePocket(uuid(2));

      expect(ledger.deletePocket(uuid(2)), isEmpty);
    });
  });

  group('deleteCategory', () {
    setUp(() {
      ledger.addCategory(category(uuid(10)));
      ledger.addCategory(category(uuid(11), parent: uuid(10)));
      ledger.addCategory(category(uuid(12), parent: uuid(10)));
      ledger.addCategory(category(uuid(13)));
    });

    test('archives it and its children keeping the entry categoryID', () {
      ledger.addEntry(
        entry(id: uuid(4), sourceID: uuid(1), categoryID: uuid(11)),
      );

      final changes = ledger.deleteCategory(uuid(10));

      expect(ledger.categories[uuid(10)]?.lifecycle, LifecycleState.archived);
      expect(ledger.categories[uuid(11)]?.lifecycle, LifecycleState.archived);
      expect(ledger.categories[uuid(12)]?.lifecycle, LifecycleState.archived);
      expect(ledger.categories[uuid(13)]?.lifecycle, LifecycleState.active);
      expect(ledger.entries[uuid(4)]?.categoryID, uuid(11));
      expect(changes.first, UpsertCategory(ledger.categories[uuid(10)]!));
      expect(changes, hasLength(3));
    });

    test('cascades to active children only', () {
      ledger.deleteCategory(uuid(11));
      final changes = ledger.deleteCategory(uuid(10));

      expect(changes, [
        UpsertCategory(ledger.categories[uuid(10)]!),
        UpsertCategory(ledger.categories[uuid(12)]!),
      ]);
    });

    test('an already archived category is a no-op', () {
      ledger.deleteCategory(uuid(10));

      expect(ledger.deleteCategory(uuid(10)), isEmpty);
    });
  });

  group('restoreAccount', () {
    test('reactivates it and its archived pockets', () {
      ledger.deleteAccount(uuid(1));
      final changes = ledger.restoreAccount(uuid(1));

      expect(ledger.moneySources[uuid(1)]?.lifecycle, LifecycleState.active);
      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.active);
      expect(changes, [
        UpsertAccount(ledger.moneySources[uuid(1)]!.asAccount!),
        UpsertPocket(ledger.moneySources[uuid(2)]!.asPocket!),
      ]);
    });

    test('an active account is a no-op', () {
      expect(ledger.restoreAccount(uuid(1)), isEmpty);
    });

    test('a missing id is a no-op', () {
      expect(ledger.restoreAccount(uuid(9)), isEmpty);
    });
  });

  group('restorePocket', () {
    test('is blocked while the parent is archived', () {
      ledger.deleteAccount(uuid(1));
      final changes = ledger.restorePocket(uuid(2));

      expect(changes, isEmpty);
      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.archived);
    });

    test('reactivates it under an active parent', () {
      ledger.deletePocket(uuid(2));
      final changes = ledger.restorePocket(uuid(2));

      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.active);
      expect(changes, [UpsertPocket(ledger.moneySources[uuid(2)]!.asPocket!)]);
    });

    test('an archived pocket survives an archive and restore round trip', () {
      ledger.deleteAccount(uuid(1));
      ledger.restoreAccount(uuid(1));

      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.active);
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
    });

    test('an active pocket is a no-op', () {
      expect(ledger.restorePocket(uuid(2)), isEmpty);
    });

    test('a referenceOnly pocket is not restorable', () {
      ledger.moneySources[uuid(2)] = PocketSource(
        pocket(uuid(2), lifecycle: LifecycleState.referenceOnly),
      );

      expect(ledger.restorePocket(uuid(2)), isEmpty);
      expect(
        ledger.moneySources[uuid(2)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
    });

    test('is blocked while the parent is referenceOnly', () {
      ledger.deletePocket(uuid(2));
      ledger.moneySources[uuid(1)] = AccountSource(
        account(
          uuid(1),
          subPocketIDs: {uuid(2)},
          lifecycle: LifecycleState.referenceOnly,
        ),
      );

      expect(ledger.restorePocket(uuid(2)), isEmpty);
      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.archived);
    });
  });

  group('restoreCategory', () {
    setUp(() {
      ledger.addCategory(category(uuid(10)));
      ledger.addCategory(category(uuid(11), parent: uuid(10)));
    });

    test('reactivates it and its archived children', () {
      ledger.deleteCategory(uuid(10));
      final changes = ledger.restoreCategory(uuid(10));

      expect(ledger.categories[uuid(10)]?.lifecycle, LifecycleState.active);
      expect(ledger.categories[uuid(11)]?.lifecycle, LifecycleState.active);
      expect(changes, [
        UpsertCategory(ledger.categories[uuid(10)]!),
        UpsertCategory(ledger.categories[uuid(11)]!),
      ]);
    });

    test('a child is blocked while its parent is archived', () {
      ledger.deleteCategory(uuid(10));
      final changes = ledger.restoreCategory(uuid(11));

      expect(changes, isEmpty);
      expect(ledger.categories[uuid(11)]?.lifecycle, LifecycleState.archived);
    });

    test('an active category is a no-op', () {
      expect(ledger.restoreCategory(uuid(10)), isEmpty);
    });
  });

  group('wrong-flavor guards', () {
    test('deleteAccount ignores a pocket id', () {
      final changes = ledger.deleteAccount(uuid(2));

      expect(changes, isEmpty);
      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.active);
    });

    test('deletePocket ignores an account id', () {
      final changes = ledger.deletePocket(uuid(1));

      expect(changes, isEmpty);
      expect(ledger.moneySources[uuid(1)]?.lifecycle, LifecycleState.active);
    });

    test('deleteEntry removes only that entry', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      ledger.addEntry(
        entry(id: uuid(5), amount: Decimal.fromInt(-20), sourceID: uuid(3)),
      );

      final changes = ledger.deleteEntry(uuid(4));

      expect(ledger.entries.keys, [uuid(5)]);
      expect(changes, [DeleteEntry(uuid(4))]);
    });
  });

  group('archived holders and entries', () {
    test('a new entry cannot reference an archived holder', () {
      ledger.deleteAccount(uuid(1));

      expect(
        () => ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1))),
        throwsA(InactiveReference(uuid(1))),
      );
    });

    test('a new entry cannot reference an archived category', () {
      ledger.addCategory(category(uuid(10)));
      ledger.deleteCategory(uuid(10));

      expect(
        () => ledger.addEntry(
          entry(id: uuid(4), sourceID: uuid(1), categoryID: uuid(10)),
        ),
        throwsA(InactiveReference(uuid(10))),
      );
    });

    test('editing an entry on an already archived category stays allowed', () {
      ledger.addCategory(category(uuid(10)));
      ledger.addEntry(
        entry(id: uuid(4), sourceID: uuid(1), categoryID: uuid(10)),
      );
      ledger.deleteCategory(uuid(10));

      ledger.updateEntry(
        entry(
          id: uuid(4),
          amount: Decimal.fromInt(-99),
          sourceID: uuid(1),
          categoryID: uuid(10),
        ),
      );

      expect(ledger.entries[uuid(4)]?.amount, Decimal.fromInt(-99));
      expect(ledger.entries[uuid(4)]?.categoryID, uuid(10));
    });
  });
}
