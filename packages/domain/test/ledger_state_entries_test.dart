import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  late LedgerState ledger;

  setUp(() {
    ledger = LedgerState();
    ledger.addAccount(account(uuid(1), name: 'a'));
    ledger.addAccount(account(uuid(2), name: 'b'));
    ledger.addCategory(category(uuid(3)));
  });

  group('entry validation', () {
    test('a zero amount throws', () {
      expect(
        () => ledger.addEntry(entry(amount: Decimal.zero, sourceID: uuid(1))),
        throwsA(const ZeroAmount()),
      );
      expect(ledger.entries, isEmpty);
    });

    test('an unknown source throws unknownHolder', () {
      expect(
        () => ledger.addEntry(entry(sourceID: uuid(9))),
        throwsA(UnknownHolder(uuid(9))),
      );
      expect(ledger.entries, isEmpty);
    });

    test('a self transfer throws', () {
      expect(
        () => ledger.addEntry(
          entry(
            amount: Decimal.fromInt(10),
            sourceID: uuid(1),
            destinationID: uuid(1),
          ),
        ),
        throwsA(const SelfTransfer()),
      );
      expect(ledger.entries, isEmpty);
    });

    test('an unknown category throws unknownCategory', () {
      expect(
        () => ledger.addEntry(entry(sourceID: uuid(1), categoryID: uuid(9))),
        throwsA(UnknownCategory(uuid(9))),
      );
      expect(ledger.entries, isEmpty);
    });

    test('zero amount beats an unknown source', () {
      expect(
        () => ledger.addEntry(entry(amount: Decimal.zero, sourceID: uuid(9))),
        throwsA(const ZeroAmount()),
      );
      expect(ledger.entries, isEmpty);
    });

    test(
      'a categorised transfer with a bad destination is a kind mismatch',
      () {
        expect(
          () => ledger.addEntry(
            entry(
              amount: Decimal.fromInt(10),
              sourceID: uuid(1),
              destinationID: uuid(9),
              categoryID: uuid(3),
            ),
          ),
          throwsA(const CategoryKindMismatch()),
        );
        expect(ledger.entries, isEmpty);
      },
    );

    test('a transfer may not carry a category', () {
      expect(
        () => ledger.addEntry(
          entry(
            amount: Decimal.fromInt(50),
            sourceID: uuid(1),
            destinationID: uuid(2),
            categoryID: uuid(3),
          ),
        ),
        throwsA(const CategoryKindMismatch()),
      );
      expect(ledger.entries, isEmpty);
    });

    test('an update may not turn a categorised entry into a transfer', () {
      ledger.addEntry(
        entry(id: uuid(4), sourceID: uuid(1), categoryID: uuid(3)),
      );

      expect(
        () => ledger.updateEntry(
          entry(
            id: uuid(4),
            amount: Decimal.fromInt(50),
            sourceID: uuid(1),
            destinationID: uuid(2),
            categoryID: uuid(3),
          ),
        ),
        throwsA(const CategoryKindMismatch()),
      );
      expect(ledger.entries[uuid(4)]?.destinationID, isNull);
    });

    test('an unknown destination throws unknownHolder', () {
      expect(
        () => ledger.addEntry(
          entry(
            amount: Decimal.fromInt(10),
            sourceID: uuid(1),
            destinationID: uuid(9),
          ),
        ),
        throwsA(UnknownHolder(uuid(9))),
      );
      expect(ledger.entries, isEmpty);
    });
  });

  group('transfer storage', () {
    test('a negative transfer normalizes and swaps endpoints', () {
      final changes = ledger.addEntry(
        entry(
          id: uuid(4),
          amount: Decimal.fromInt(-100),
          sourceID: uuid(1),
          destinationID: uuid(2),
        ),
      );

      final stored = ledger.entries[uuid(4)]!;
      expect(stored.amount, Decimal.fromInt(100));
      expect(stored.sourceID, uuid(2));
      expect(stored.destinationID, uuid(1));
      expect(changes, [UpsertEntry(stored)]);
    });

    test('a positive transfer is stored unchanged', () {
      final given = entry(
        id: uuid(4),
        amount: Decimal.fromInt(100),
        sourceID: uuid(1),
        destinationID: uuid(2),
      );
      ledger.addEntry(given);

      expect(ledger.entries[uuid(4)], given);
    });
  });

  group('opening balance', () {
    test('is excluded from analysis and carries no category', () {
      final changes = ledger.setOpeningBalance(
        Decimal.fromInt(250),
        uuid(1),
        date: DateTime.utc(2026),
      );

      final stored = ledger.entries.values.single;
      expect(stored.amount, Decimal.fromInt(250));
      expect(stored.name, 'Opening balance');
      expect(stored.categoryID, isNull);
      expect(stored.destinationID, isNull);
      expect(stored.includeInAnalysis, isFalse);
      expect(changes, [UpsertEntry(stored)]);
    });

    test('a negative opening balance keeps its sign', () {
      ledger.setOpeningBalance(Decimal.fromInt(-250), uuid(1));

      expect(ledger.entries.values.single.amount, Decimal.fromInt(-250));
    });

    test('zero records nothing', () {
      final changes = ledger.setOpeningBalance(Decimal.zero, uuid(1));

      expect(changes, isEmpty);
      expect(ledger.entries, isEmpty);
    });

    test('an unknown holder throws even at zero', () {
      expect(
        () => ledger.setOpeningBalance(Decimal.zero, uuid(9)),
        throwsA(UnknownHolder(uuid(9))),
      );
    });
  });

  group('addEntry', () {
    test('emits an upsert of the stored entry', () {
      final given = entry(id: uuid(4), sourceID: uuid(1));
      final changes = ledger.addEntry(given);

      expect(changes, [UpsertEntry(given)]);
      expect(ledger.entries[uuid(4)], given);
    });

    test('rejects a duplicate id', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));

      expect(
        () => ledger.addEntry(entry(id: uuid(4), sourceID: uuid(2))),
        throwsA(IdCollision(uuid(4))),
      );
      expect(ledger.entries[uuid(4)]?.sourceID, uuid(1));
    });
  });

  group('updateEntry', () {
    test('overwrites the same id', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      final changes = ledger.updateEntry(
        entry(id: uuid(4), amount: Decimal.fromInt(-99), sourceID: uuid(1)),
      );

      expect(ledger.entries, hasLength(1));
      expect(ledger.entries[uuid(4)]?.amount, Decimal.fromInt(-99));
      expect(changes, [UpsertEntry(ledger.entries[uuid(4)]!)]);
    });

    test('moves the money when the source changes', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      ledger.updateEntry(entry(id: uuid(4), sourceID: uuid(2)));

      expect(ledger.entries[uuid(4)]?.sourceID, uuid(2));
    });

    test('revalidates new holders and leaves the original untouched', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));

      expect(
        () => ledger.updateEntry(entry(id: uuid(4), sourceID: uuid(9))),
        throwsA(UnknownHolder(uuid(9))),
      );
      expect(ledger.entries[uuid(4)]?.sourceID, uuid(1));
    });

    test('can change the category', () {
      ledger.addCategory(category(uuid(5), name: 'other'));
      ledger.addEntry(
        entry(id: uuid(4), sourceID: uuid(1), categoryID: uuid(3)),
      );
      ledger.updateEntry(
        entry(id: uuid(4), sourceID: uuid(1), categoryID: uuid(5)),
      );

      expect(ledger.entries[uuid(4)]?.categoryID, uuid(5));
    });

    /// Editing an entry whose holder was archived after the fact stays legal,
    /// so a row already naming that holder is exempt from the active-holder
    /// rule. A brand new entry on the same holder is not.
    group('the prior-reference exemption', () {
      test('an edit keeps a source archived since the entry was made', () {
        ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
        ledger.deleteAccount(uuid(1));

        final changes = ledger.updateEntry(
          entry(id: uuid(4), amount: Decimal.fromInt(-99), sourceID: uuid(1)),
        );

        expect(ledger.entries[uuid(4)]?.amount, Decimal.fromInt(-99));
        expect(changes, [UpsertEntry(ledger.entries[uuid(4)]!)]);
      });

      test('a new entry on that same archived source is refused', () {
        ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
        ledger.deleteAccount(uuid(1));

        expect(
          () => ledger.addEntry(entry(id: uuid(5), sourceID: uuid(1))),
          throwsA(InactiveReference(uuid(1))),
        );
        expect(ledger.entries[uuid(5)], isNull);
      });

      test('an edit keeps a destination archived since the entry was made', () {
        ledger.addEntry(
          entry(
            id: uuid(4),
            amount: Decimal.fromInt(50),
            sourceID: uuid(1),
            destinationID: uuid(2),
          ),
        );
        ledger.deleteAccount(uuid(2));

        final changes = ledger.updateEntry(
          entry(
            id: uuid(4),
            amount: Decimal.fromInt(75),
            sourceID: uuid(1),
            destinationID: uuid(2),
          ),
        );

        expect(ledger.entries[uuid(4)]?.amount, Decimal.fromInt(75));
        expect(changes, [UpsertEntry(ledger.entries[uuid(4)]!)]);
      });

      test('a new entry on that same archived destination is refused', () {
        ledger.addEntry(
          entry(
            id: uuid(4),
            amount: Decimal.fromInt(50),
            sourceID: uuid(1),
            destinationID: uuid(2),
          ),
        );
        ledger.deleteAccount(uuid(2));

        expect(
          () => ledger.addEntry(
            entry(
              id: uuid(5),
              amount: Decimal.fromInt(50),
              sourceID: uuid(1),
              destinationID: uuid(2),
            ),
          ),
          throwsA(InactiveReference(uuid(2))),
        );
        expect(ledger.entries[uuid(5)], isNull);
      });
    });

    test('throws unknownEntry for a missing id', () {
      expect(
        () => ledger.updateEntry(entry(id: uuid(4), sourceID: uuid(1))),
        throwsA(UnknownEntry(uuid(4))),
      );
      expect(ledger.entries, isEmpty);
    });
  });

  group('deleteEntry', () {
    test('removes only that entry', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      ledger.addEntry(entry(id: uuid(5), sourceID: uuid(2)));
      final changes = ledger.deleteEntry(uuid(4));

      expect(ledger.entries.keys, [uuid(5)]);
      expect(changes, [DeleteEntry(uuid(4))]);
    });

    test('a missing id is a no-op', () {
      expect(ledger.deleteEntry(uuid(9)), isEmpty);
    });
  });
}
