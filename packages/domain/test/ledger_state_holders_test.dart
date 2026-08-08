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

    test('stores the statement day it is given', () {
      ledger.addAccount(
        account(uuid(1), type: AccountType.savings, statementDay: 15),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.statementDay, 15);
    });
  });

  group('updateAccount', () {
    test('edits attributes in place', () {
      ledger.addAccount(account(uuid(1)));
      final changes = ledger.updateAccount(
        account(
          uuid(1),
          name: 'renamed',
          type: AccountType.checking,
          incomingTransfersAsExpenses: true,
          includeInNetWorth: false,
        ),
      );

      final stored = ledger.moneySources[uuid(1)]!.asAccount!;
      expect(ledger.moneySources, hasLength(1));
      expect(stored.name, 'renamed');
      expect(stored.type, AccountType.checking);
      expect(stored.incomingTransfersAsExpenses, isTrue);
      expect(stored.includeInNetWorth, isFalse);
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
      ledger.updateAccount(
        account(uuid(1), type: AccountType.savings, statementDay: 15),
      );

      expect(ledger.moneySources[uuid(1)]?.asAccount?.statementDay, isNull);
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
