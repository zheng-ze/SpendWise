import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

// Reads outward from the pocket rows, so a pocket nobody claims is caught.
// Walking subPocketIDs instead would only visit pockets already claimed.
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

// The lifecycle half of the invariant, judged over every lifecycle rather than
// only the active rows.
void expectNoPocketOutlivingItsParent(LedgerState ledger) {
  for (final source in ledger.moneySources.values) {
    final account = source.asAccount;
    if (account == null) continue;

    for (final pocketID in account.subPocketIDs) {
      final pocket = ledger.moneySources[pocketID]?.asPocket;
      if (pocket == null) continue;

      expect(
        account.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle),
        isTrue,
        reason: '$pocketID is more alive than ${account.id}',
      );
    }
  }
}

void expectPocketInvariants(LedgerState ledger) {
  expectNoOrphanPocket(ledger);
  expectNoPocketOutlivingItsParent(ledger);
}

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

      expect(ledger.moneySources[uuid(1)]?.lifecycle, LifecycleState.archived);
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
      // The parent emits before its children. The children come from an
      // unordered scan, so this does not assert an order between them.
      expect(
        changes,
        containsAllInOrder([
          UpsertCategory(ledger.categories[uuid(10)]!),
          UpsertCategory(ledger.categories[uuid(11)]!),
        ]),
      );
      expect(changes, contains(UpsertCategory(ledger.categories[uuid(12)]!)));
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
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(2)));
      ledger.deletePocket(uuid(2));
      ledger.purgePocket(uuid(2));

      expect(ledger.restorePocket(uuid(2)), isEmpty);
      expect(
        ledger.moneySources[uuid(2)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
    });

    test('is blocked while the parent is referenceOnly', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(2)));
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));
      expect(
        ledger.moneySources[uuid(1)]?.lifecycle,
        LifecycleState.referenceOnly,
      );

      expect(ledger.restorePocket(uuid(2)), isEmpty);
      expect(
        ledger.moneySources[uuid(2)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
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
      expect(ledger.entries[uuid(4)], isNull);
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
      expect(ledger.entries[uuid(4)], isNull);
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

  group('a pocket may never outlive its parent', () {
    test('updatePocket cannot reactivate under an archived parent', () {
      ledger.deleteAccount(uuid(1));

      final changes = ledger.updatePocket(
        pocket(uuid(2), name: 'renamed', lifecycle: LifecycleState.active),
      );

      final stored = ledger.moneySources[uuid(2)]!.asPocket!;
      expect(stored.name, 'renamed');
      expect(stored.lifecycle, LifecycleState.archived);
      expect(changes, [UpsertPocket(stored)]);
    });

    test('updatePocket cannot reactivate under a referenceOnly parent', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(2)));
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));

      ledger.updatePocket(pocket(uuid(2), lifecycle: LifecycleState.active));

      expect(
        ledger.moneySources[uuid(2)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
    });
  });

  group('a category may never outlive its parent', () {
    setUp(() {
      ledger.addCategory(category(uuid(10)));
      ledger.addCategory(category(uuid(11), parent: uuid(10)));
    });

    test('a child cannot reactivate under an archived parent', () {
      ledger.deleteCategory(uuid(10));

      final changes = ledger.updateCategory(
        category(
          uuid(11),
          name: 'renamed',
          parent: uuid(10),
          lifecycle: LifecycleState.active,
        ),
      );

      final stored = ledger.categories[uuid(11)]!;
      expect(stored.name, 'renamed');
      expect(stored.lifecycle, LifecycleState.archived);
      expect(changes, [UpsertCategory(stored)]);
    });

    test('the emitted payload is the stored category, not the argument', () {
      ledger.deleteCategory(uuid(10));
      final argument = category(
        uuid(11),
        parent: uuid(10),
        lifecycle: LifecycleState.active,
      );

      final changes = ledger.updateCategory(argument);

      expect(changes, [UpsertCategory(ledger.categories[uuid(11)]!)]);
      expect(changes, isNot([UpsertCategory(argument)]));
    });

    test('reparenting under an archived parent cannot go active', () {
      ledger.addCategory(category(uuid(12)));
      ledger.deleteCategory(uuid(12));
      ledger.deleteCategory(uuid(11));

      ledger.updateCategory(
        category(uuid(11), parent: uuid(12), lifecycle: LifecycleState.active),
      );

      final stored = ledger.categories[uuid(11)]!;
      expect(stored.parentID, uuid(12));
      expect(stored.lifecycle, LifecycleState.archived);
    });
  });

  group('no mutator leaves an active pocket without an active parent', () {
    test('addPocket onto an archived parent is rejected', () {
      ledger.deleteAccount(uuid(1));

      expect(
        () => ledger.addPocket(pocket(uuid(8)), uuid(1)),
        throwsA(InactiveReference(uuid(1))),
      );
      expectPocketInvariants(ledger);
    });

    test('deleteAccount archives every pocket it holds', () {
      ledger.addPocket(pocket(uuid(8)), uuid(1));
      ledger.deleteAccount(uuid(1));

      expectPocketInvariants(ledger);
    });

    test('updatePocket cannot revive one under an archived parent', () {
      ledger.deleteAccount(uuid(1));
      ledger.updatePocket(pocket(uuid(2), lifecycle: LifecycleState.active));

      expectPocketInvariants(ledger);
    });

    test('restorePocket cannot revive one under an archived parent', () {
      ledger.deleteAccount(uuid(1));
      ledger.restorePocket(uuid(2));

      expectPocketInvariants(ledger);
    });

    test('updateAccount cannot rewrite links to strand a pocket', () {
      ledger.updateAccount(account(uuid(1), name: 'renamed'));

      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
      expectPocketInvariants(ledger);
    });

    test('an archive and restore round trip ends clean', () {
      ledger.deleteAccount(uuid(1));
      ledger.restoreAccount(uuid(1));

      expectPocketInvariants(ledger);
    });
  });

  group('no pocket can end up claimed by two accounts', () {
    void expectSingleClaimant(LedgerState state, String pocketID) {
      final claimants = state.moneySources.values
          .map((source) => source.asAccount)
          .nonNulls
          .where((account) => account.subPocketIDs.contains(pocketID))
          .toList();

      expect(claimants, hasLength(1));
    }

    test('addPocket rejects a second parent for a live pocket id', () {
      expect(
        () => ledger.addPocket(pocket(uuid(2)), uuid(3)),
        throwsA(IdCollision(uuid(2))),
      );

      expectSingleClaimant(ledger, uuid(2));
      expectPocketInvariants(ledger);
    });

    test('addAccount cannot arrive already holding a live pocket', () {
      ledger.addAccount(
        account(uuid(7), name: 'greedy', subPocketIDs: {uuid(2)}),
      );

      expect(ledger.moneySources[uuid(7)]?.asAccount?.subPocketIDs, isEmpty);
      expectSingleClaimant(ledger, uuid(2));
      expectPocketInvariants(ledger);
    });

    test('updateAccount cannot annex a pocket owned elsewhere', () {
      ledger.updateAccount(
        account(uuid(3), name: 'other', subPocketIDs: {uuid(2)}),
      );

      expect(ledger.moneySources[uuid(3)]?.asAccount?.subPocketIDs, isEmpty);
      expectSingleClaimant(ledger, uuid(2));
      expectPocketInvariants(ledger);
    });

    test('updateAccount cannot re-add a pocket its own purge detached', () {
      ledger.deletePocket(uuid(2));
      ledger.purgePocket(uuid(2));

      ledger.updateAccount(
        account(uuid(1), name: 'main', subPocketIDs: {uuid(2)}),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, isEmpty);
      expectPocketInvariants(ledger);
    });

    test('a detached and re-added pocket id lands under one parent only', () {
      ledger.deletePocket(uuid(2));
      ledger.purgePocket(uuid(2));
      ledger.addPocket(pocket(uuid(2)), uuid(3));

      expectSingleClaimant(ledger, uuid(2));
      expectPocketInvariants(ledger);
    });
  });

  group('sourceName does not depend on map insertion order', () {
    LedgerState buildInOrder(List<String> accountIDs) {
      final state = LedgerState();
      for (final id in accountIDs) {
        state.addAccount(account(id, name: id == uuid(1) ? 'main' : 'other'));
      }
      state.addPocket(pocket(uuid(2), name: 'pkt'), uuid(1));
      return state;
    }

    test('the owning account resolves the same in either insertion order', () {
      final first = buildInOrder([uuid(1), uuid(3)]);
      final second = buildInOrder([uuid(3), uuid(1)]);

      expect(first.sourceName(uuid(2)), 'main/pkt');
      expect(second.sourceName(uuid(2)), first.sourceName(uuid(2)));
      expectPocketInvariants(first);
      expectPocketInvariants(second);
    });

    test('a rename resolves through the one claimant either way', () {
      final first = buildInOrder([uuid(1), uuid(3)]);
      final second = buildInOrder([uuid(3), uuid(1)]);
      for (final state in [first, second]) {
        state.updateAccount(account(uuid(1), name: 'renamed'));
      }

      expect(first.sourceName(uuid(2)), 'renamed/pkt');
      expect(second.sourceName(uuid(2)), first.sourceName(uuid(2)));
    });

    test('archiving the parent leaves the name resolvable and stable', () {
      final first = buildInOrder([uuid(1), uuid(3)]);
      final second = buildInOrder([uuid(3), uuid(1)]);
      for (final state in [first, second]) {
        state.deleteAccount(uuid(1));
      }

      expect(first.sourceName(uuid(2)), 'main/pkt');
      expect(second.sourceName(uuid(2)), first.sourceName(uuid(2)));
      expectPocketInvariants(first);
      expectPocketInvariants(second);
    });
  });

  group('no mutator sequence leaves a detached pocket row alive', () {
    test('purgeAccount over a mix of referenced and free pockets', () {
      ledger.addPocket(pocket(uuid(8), name: 'second'), uuid(1));
      ledger.addEntry(
        entry(id: uuid(4), amount: Decimal.fromInt(100), sourceID: uuid(8)),
      );
      ledger.deleteAccount(uuid(1));

      ledger.purgeAccount(uuid(1));

      expect(ledger.moneySources[uuid(2)], isNull);
      expectPocketInvariants(ledger);
    });

    test('purgePocket detaches the link with the row', () {
      ledger.deletePocket(uuid(2));
      ledger.purgePocket(uuid(2));

      expect(ledger.moneySources[uuid(2)], isNull);
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, isEmpty);
      expectPocketInvariants(ledger);
    });

    test('deleteEntry sweeping the last reference clears both rows', () {
      ledger.addEntry(
        entry(id: uuid(4), amount: Decimal.fromInt(100), sourceID: uuid(2)),
      );
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));
      expectPocketInvariants(ledger);

      ledger.deleteEntry(uuid(4));

      expect(ledger.moneySources[uuid(2)], isNull);
      expect(ledger.moneySources[uuid(1)], isNull);
      expectPocketInvariants(ledger);
    });

    test('a delete, restore, delete, purge run stays consistent', () {
      ledger.addPocket(pocket(uuid(8), name: 'second'), uuid(1));

      ledger.deleteAccount(uuid(1));
      expectPocketInvariants(ledger);
      ledger.restoreAccount(uuid(1));
      expectPocketInvariants(ledger);
      ledger.deletePocket(uuid(8));
      expectPocketInvariants(ledger);
      ledger.deleteAccount(uuid(1));
      expectPocketInvariants(ledger);
      ledger.purgeAccount(uuid(1));

      expect(ledger.moneySources.keys, [uuid(3)]);
      expectPocketInvariants(ledger);
    });

    test('restorePocket after its parent purged away is a no-op', () {
      ledger.deletePocket(uuid(2));
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));

      ledger.restorePocket(uuid(2));
      ledger.restoreAccount(uuid(1));

      expect(ledger.moneySources.keys, [uuid(3)]);
      expectPocketInvariants(ledger);
    });

    test('addPocket onto a referenceOnly parent is rejected', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));

      expect(
        () => ledger.addPocket(pocket(uuid(8), name: 'second'), uuid(1)),
        throwsA(InactiveReference(uuid(1))),
      );
      expect(ledger.moneySources[uuid(8)], isNull);
      expectPocketInvariants(ledger);
    });

    test('purging a pocket then updating the account keeps links honest', () {
      ledger.addPocket(pocket(uuid(8), name: 'second'), uuid(1));
      ledger.deletePocket(uuid(8));
      ledger.purgePocket(uuid(8));

      ledger.updateAccount(account(uuid(1), name: 'renamed'));

      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
      expectPocketInvariants(ledger);
    });
  });

  group('repeating a lifecycle mutator changes nothing', () {
    test('deleteAccount twice', () {
      ledger.deleteAccount(uuid(1));
      final snapshot = Map.of(ledger.moneySources);

      expect(ledger.deleteAccount(uuid(1)), isEmpty);
      expect(ledger.moneySources, snapshot);
    });

    test('restoreAccount twice', () {
      ledger.deleteAccount(uuid(1));
      ledger.restoreAccount(uuid(1));
      final snapshot = Map.of(ledger.moneySources);

      expect(ledger.restoreAccount(uuid(1)), isEmpty);
      expect(ledger.moneySources, snapshot);
    });

    test('purgeAccount twice', () {
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));
      final snapshot = Map.of(ledger.moneySources);

      expect(ledger.purgeAccount(uuid(1)), isEmpty);
      expect(ledger.moneySources, snapshot);
      expectPocketInvariants(ledger);
    });

    test('deletePocket twice', () {
      ledger.deletePocket(uuid(2));
      final snapshot = Map.of(ledger.moneySources);

      expect(ledger.deletePocket(uuid(2)), isEmpty);
      expect(ledger.moneySources, snapshot);
    });

    test('deleteCategory twice', () {
      ledger.addCategory(category(uuid(7)));
      ledger.deleteCategory(uuid(7));
      final snapshot = Map.of(ledger.categories);

      expect(ledger.deleteCategory(uuid(7)), isEmpty);
      expect(ledger.categories, snapshot);
    });

    test('restoreCategory twice', () {
      ledger.addCategory(category(uuid(7)));
      ledger.deleteCategory(uuid(7));
      ledger.restoreCategory(uuid(7));
      final snapshot = Map.of(ledger.categories);

      expect(ledger.restoreCategory(uuid(7)), isEmpty);
      expect(ledger.categories, snapshot);
    });

    test('purgeCategory twice', () {
      ledger.addCategory(category(uuid(7)));
      ledger.deleteCategory(uuid(7));
      ledger.purgeCategory(uuid(7));
      final snapshot = Map.of(ledger.categories);

      expect(ledger.purgeCategory(uuid(7)), isEmpty);
      expect(ledger.categories, snapshot);
    });

    test('deleteEntry twice', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      ledger.deleteEntry(uuid(4));
      final snapshot = Map.of(ledger.entries);

      expect(ledger.deleteEntry(uuid(4)), isEmpty);
      expect(ledger.entries, snapshot);
    });
  });
}
