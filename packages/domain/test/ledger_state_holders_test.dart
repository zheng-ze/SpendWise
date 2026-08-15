import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  late LedgerState ledger;

  setUp(() => ledger = LedgerState());

  group('addPocket', () {
    test('attaches the pocket to its parent and to the table', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));

      expect(ledger.moneySources[uuid(2)]?.asPocket, pocket(uuid(2)));
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
    });

    test('emits the pocket upsert then the parent upsert', () {
      ledger.addAccount(account(uuid(1)));
      final changes = ledger.addPocket(pocket(uuid(2)), uuid(1));

      expect(changes, [
        UpsertPocket(pocket(uuid(2))),
        UpsertAccount(account(uuid(1), subPocketIDs: {uuid(2)})),
      ]);
    });

    test('throws unknownAccount for a missing parent', () {
      expect(
        () => ledger.addPocket(pocket(uuid(2)), uuid(1)),
        throwsA(UnknownAccount(uuid(1))),
      );
      expect(ledger.moneySources, isEmpty);
    });

    test('throws unknownAccount when the parent id is a pocket', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));

      expect(
        () => ledger.addPocket(pocket(uuid(3)), uuid(2)),
        throwsA(UnknownAccount(uuid(2))),
      );
    });

    test('the parent check precedes the collision check', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));

      expect(
        () => ledger.addPocket(pocket(uuid(2)), uuid(9)),
        throwsA(UnknownAccount(uuid(9))),
      );
    });

    test('rejects an id already held by another pocket', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));

      expect(
        () => ledger.addPocket(pocket(uuid(2)), uuid(1)),
        throwsA(IdCollision(uuid(2))),
      );
    });

    test('an archived account rejects a new pocket', () {
      ledger.addAccount(account(uuid(1)));
      ledger.deleteAccount(uuid(1));

      expect(
        () => ledger.addPocket(pocket(uuid(2)), uuid(1)),
        throwsA(InactiveReference(uuid(1))),
      );
      expect(ledger.moneySources[uuid(2)], isNull);
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, isEmpty);
    });

    test('a referenceOnly account rejects a new pocket', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addEntry(entry(id: uuid(3), sourceID: uuid(1)));
      ledger.deleteAccount(uuid(1));
      ledger.purgeAccount(uuid(1));

      expect(
        () => ledger.addPocket(pocket(uuid(2)), uuid(1)),
        throwsA(InactiveReference(uuid(1))),
      );
      expect(ledger.moneySources[uuid(2)], isNull);
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, isEmpty);
    });

    test('a pocket may start less alive than an active account', () {
      ledger.addAccount(account(uuid(1)));

      ledger.addPocket(
        pocket(uuid(2), lifecycle: LifecycleState.archived),
        uuid(1),
      );

      expect(ledger.moneySources[uuid(2)]?.lifecycle, LifecycleState.archived);
    });
  });

  group('addAccount', () {
    test('rejects an id already held by a pocket: one id space', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));

      expect(
        () => ledger.addAccount(account(uuid(2))),
        throwsA(IdCollision(uuid(2))),
      );
    });

    test('rejects a duplicate account id', () {
      ledger.addAccount(account(uuid(1)));

      expect(
        () => ledger.addAccount(account(uuid(1), name: 'other')),
        throwsA(IdCollision(uuid(1))),
      );
      expect(ledger.moneySources[uuid(1)]?.name, 'acc');
    });

    test('discards passed pocket links', () {
      final changes = ledger.addAccount(
        account(uuid(1), subPocketIDs: {uuid(7), uuid(8)}),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, isEmpty);
      expect(changes, [UpsertAccount(account(uuid(1)))]);
    });

    test('stores the statement day a card is given', () {
      ledger.addAccount(
        account(uuid(1), type: AccountType.card, statementDay: 15),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.statementDay, 15);
    });

    // Matches updateAccount, which has always cleared it for a non-card.
    test('clears the statement day for a non-card type', () {
      ledger.addAccount(
        account(uuid(1), type: AccountType.savings, statementDay: 15),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.statementDay, isNull);
    });

    test('clamps a statement day above the 28th', () {
      ledger.addAccount(
        account(uuid(1), type: AccountType.card, statementDay: 999),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.statementDay, 28);
    });

    test('clamps a statement day below the first', () {
      ledger.addAccount(
        account(uuid(1), type: AccountType.card, statementDay: -5),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.statementDay, 1);
    });

    test('forces the transfer flag off for an ineligible type', () {
      ledger.addAccount(
        account(
          uuid(1),
          type: AccountType.checking,
          incomingTransfersAsExpenses: true,
        ),
      );

      expect(
        ledger.moneySources[uuid(1)]?.asAccount?.incomingTransfersAsExpenses,
        isFalse,
      );
    });
  });

  group('updateAccount', () {
    test('edits attributes in place', () {
      ledger.addAccount(account(uuid(1)));
      final changes = ledger.updateAccount(
        account(
          uuid(1),
          name: 'renamed',
          type: AccountType.investment,
          incomingTransfersAsExpenses: true,
          includeInNetWorth: false,
        ),
      );

      final stored = ledger.moneySources[uuid(1)]!.asAccount!;
      expect(ledger.moneySources, hasLength(1));
      expect(stored.name, 'renamed');
      expect(stored.type, AccountType.investment);
      expect(stored.incomingTransfersAsExpenses, isTrue);
      expect(stored.includeInNetWorth, isFalse);
      expect(changes, [UpsertAccount(stored)]);
    });

    test('forces the transfer flag off when the type becomes ineligible', () {
      ledger.addAccount(
        account(
          uuid(1),
          type: AccountType.savings,
          incomingTransfersAsExpenses: true,
        ),
      );
      final changes = ledger.updateAccount(
        account(
          uuid(1),
          type: AccountType.checking,
          incomingTransfersAsExpenses: true,
        ),
      );

      final stored = ledger.moneySources[uuid(1)]!.asAccount!;
      expect(stored.incomingTransfersAsExpenses, isFalse);
      expect(changes, [UpsertAccount(stored)]);
    });

    test('preserves pocket links', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.updateAccount(account(uuid(1), name: 'renamed'));

      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
    });

    test('ignores passed pocket links', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      ledger.updateAccount(account(uuid(1), subPocketIDs: {uuid(8), uuid(9)}));

      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
    });

    test('clears the statement day for a non-card type', () {
      ledger.addAccount(
        account(uuid(1), type: AccountType.card, statementDay: 15),
      );
      final changes = ledger.updateAccount(
        account(uuid(1), type: AccountType.savings, statementDay: 15),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.statementDay, isNull);
      expect(changes, [
        UpsertAccount(account(uuid(1), type: AccountType.savings)),
      ]);
    });

    test('clamps an out-of-range statement day for a card', () {
      ledger.addAccount(account(uuid(1), type: AccountType.card));
      ledger.updateAccount(
        account(uuid(1), type: AccountType.card, statementDay: 31),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.statementDay, 28);
    });

    test('keeps the statement day for a card', () {
      ledger.addAccount(account(uuid(1), type: AccountType.card));
      ledger.updateAccount(
        account(uuid(1), type: AccountType.card, statementDay: 15),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.statementDay, 15);
    });

    test('emits an upsert of the stored account, not the argument', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      final changes = ledger.updateAccount(
        account(
          uuid(1),
          name: 'renamed',
          subPocketIDs: {uuid(9)},
          statementDay: 15,
        ),
      );

      expect(changes, [
        UpsertAccount(
          account(uuid(1), name: 'renamed', subPocketIDs: {uuid(2)}),
        ),
      ]);
    });

    test('throws unknownAccount for a missing id', () {
      expect(
        () => ledger.updateAccount(account(uuid(1))),
        throwsA(UnknownAccount(uuid(1))),
      );
    });

    test('throws unknownAccount when the id resolves to a pocket', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));

      expect(
        () => ledger.updateAccount(account(uuid(2))),
        throwsA(UnknownAccount(uuid(2))),
      );
      expect(ledger.moneySources[uuid(2)]?.asPocket, isNotNull);
    });
  });

  group('updatePocket', () {
    test('changes fields without touching the parent link', () {
      ledger.addAccount(account(uuid(1)));
      ledger.addPocket(pocket(uuid(2)), uuid(1));
      final changes = ledger.updatePocket(
        pocket(uuid(2), name: 'renamed', incomingTransfersAsExpenses: true),
      );

      final stored = ledger.moneySources[uuid(2)]!.asPocket!;
      expect(stored.name, 'renamed');
      expect(stored.incomingTransfersAsExpenses, isTrue);
      expect(ledger.moneySources[uuid(1)]?.asAccount?.subPocketIDs, {uuid(2)});
      expect(changes, [UpsertPocket(stored)]);
    });

    test('throws unknownHolder for a missing id', () {
      expect(
        () => ledger.updatePocket(pocket(uuid(2))),
        throwsA(UnknownHolder(uuid(2))),
      );
    });

    test('throws unknownHolder when the id resolves to an account', () {
      ledger.addAccount(account(uuid(1)));

      expect(
        () => ledger.updatePocket(pocket(uuid(1))),
        throwsA(UnknownHolder(uuid(1))),
      );
      expect(ledger.moneySources[uuid(1)]?.asAccount, isNotNull);
    });
  });
}
