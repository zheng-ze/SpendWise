import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  late LedgerState ledger;

  setUp(() {
    ledger = LedgerState();
    ledger.addAccount(account(uuid(1)));
  });

  group('category structure', () {
    test('a third nesting level throws categoryTooDeep', () {
      ledger.addCategory(category(uuid(2)));
      ledger.addCategory(category(uuid(3), parent: uuid(2)));

      expect(
        () => ledger.addCategory(category(uuid(4), parent: uuid(3))),
        throwsA(const CategoryTooDeep()),
      );
      expect(ledger.categories, hasLength(2));
    });

    test('an unknown parent throws unknownCategory', () {
      expect(
        () => ledger.addCategory(category(uuid(2), parent: uuid(9))),
        throwsA(UnknownCategory(uuid(9))),
      );
      expect(ledger.categories, isEmpty);
    });

    test('a child kind must match its parent', () {
      ledger.addCategory(category(uuid(2), kind: CategoryKind.expense));

      expect(
        () => ledger.addCategory(
          category(uuid(3), kind: CategoryKind.income, parent: uuid(2)),
        ),
        throwsA(const CategoryKindMismatch()),
      );
    });

    test('a child under an archived parent is allowed', () {
      ledger.addCategory(category(uuid(2), lifecycle: LifecycleState.archived));
      final changes = ledger.addCategory(category(uuid(3), parent: uuid(2)));

      expect(changes, [UpsertCategory(category(uuid(3), parent: uuid(2)))]);
    });

    test('the parent checks run in order, unknown before too deep', () {
      ledger.addCategory(category(uuid(2)));
      ledger.addCategory(category(uuid(3), parent: uuid(2)));

      expect(
        () => ledger.addCategory(category(uuid(4), parent: uuid(9))),
        throwsA(UnknownCategory(uuid(9))),
      );
    });

    test('depth is checked before kind', () {
      ledger.addCategory(category(uuid(2), kind: CategoryKind.expense));
      ledger.addCategory(
        category(uuid(3), kind: CategoryKind.expense, parent: uuid(2)),
      );

      expect(
        () => ledger.addCategory(
          category(uuid(4), kind: CategoryKind.income, parent: uuid(3)),
        ),
        throwsA(const CategoryTooDeep()),
      );
    });
  });

  group('category kind rules for entries', () {
    setUp(() {
      ledger.addCategory(category(uuid(2), kind: CategoryKind.expense));
      ledger.addCategory(category(uuid(3), kind: CategoryKind.income));
      ledger.addAccount(account(uuid(8), name: 'other'));
    });

    test('an expense entry with an income category throws', () {
      expect(
        () => ledger.addEntry(
          entry(
            amount: Decimal.fromInt(-10),
            sourceID: uuid(1),
            categoryID: uuid(3),
          ),
        ),
        throwsA(const CategoryKindMismatch()),
      );
    });

    test('an income entry with an expense category throws', () {
      expect(
        () => ledger.addEntry(
          entry(
            amount: Decimal.fromInt(10),
            sourceID: uuid(1),
            categoryID: uuid(2),
          ),
        ),
        throwsA(const CategoryKindMismatch()),
      );
    });

    test('matching kinds are accepted for both signs', () {
      ledger.addEntry(
        entry(
          id: uuid(5),
          amount: Decimal.fromInt(-10),
          sourceID: uuid(1),
          categoryID: uuid(2),
        ),
      );
      ledger.addEntry(
        entry(
          id: uuid(6),
          amount: Decimal.fromInt(10),
          sourceID: uuid(1),
          categoryID: uuid(3),
        ),
      );

      expect(ledger.entries[uuid(5)]?.categoryID, uuid(2));
      expect(ledger.entries[uuid(6)]?.categoryID, uuid(3));
    });

    test('a transfer carrying any category throws', () {
      expect(
        () => ledger.addEntry(
          entry(
            amount: Decimal.fromInt(10),
            sourceID: uuid(1),
            destinationID: uuid(8),
            categoryID: uuid(2),
          ),
        ),
        throwsA(const CategoryKindMismatch()),
      );
    });
  });

  group('updateCategory', () {
    test('replaces fields in place', () {
      ledger.addCategory(category(uuid(2)));
      final changes = ledger.updateCategory(
        category(
          uuid(2),
          name: 'renamed',
          colorHex: '#FF8800',
          symbol: 'cart',
          includeInAnalysis: false,
        ),
      );

      final stored = ledger.categories[uuid(2)]!;
      expect(ledger.categories, hasLength(1));
      expect(stored.name, 'renamed');
      expect(stored.colorHex, '#FF8800');
      expect(stored.symbol, 'cart');
      expect(stored.includeInAnalysis, isFalse);
      expect(changes, [UpsertCategory(stored)]);
    });

    test('throws unknownCategory for a missing id', () {
      expect(
        () => ledger.updateCategory(category(uuid(2))),
        throwsA(UnknownCategory(uuid(2))),
      );
    });

    test('revalidates the parent', () {
      ledger.addCategory(category(uuid(2)));

      expect(
        () => ledger.updateCategory(category(uuid(2), parent: uuid(9))),
        throwsA(UnknownCategory(uuid(9))),
      );
      expect(ledger.categories[uuid(2)]?.parentID, isNull);
    });

    test('rejects giving a parent to a category that has children', () {
      ledger.addCategory(category(uuid(2)));
      ledger.addCategory(category(uuid(3), parent: uuid(2)));
      ledger.addCategory(category(uuid(4)));

      expect(
        () => ledger.updateCategory(category(uuid(2), parent: uuid(4))),
        throwsA(const CategoryTooDeep()),
      );
      expect(ledger.categories[uuid(2)]?.parentID, isNull);
      expect(ledger.categories[uuid(3)]?.parentID, uuid(2));
    });

    test('rejects a kind change', () {
      ledger.addCategory(category(uuid(2)));

      expect(
        () =>
            ledger.updateCategory(category(uuid(2), kind: CategoryKind.income)),
        throwsA(const CategoryKindMismatch()),
      );
      expect(ledger.categories[uuid(2)]?.kind, CategoryKind.expense);
    });

    test('rejects a parent kind change with no entries', () {
      ledger.addCategory(category(uuid(2)));
      ledger.addCategory(category(uuid(3), parent: uuid(2)));

      expect(
        () =>
            ledger.updateCategory(category(uuid(2), kind: CategoryKind.income)),
        throwsA(const CategoryKindMismatch()),
      );
      expect(ledger.categories[uuid(2)]?.kind, CategoryKind.expense);
      expect(ledger.categories[uuid(3)]?.kind, CategoryKind.expense);
    });

    test('rejects making a category its own parent', () {
      ledger.addCategory(category(uuid(2)));

      expect(
        () => ledger.updateCategory(category(uuid(2), parent: uuid(2))),
        throwsA(const CategoryTooDeep()),
      );
      expect(ledger.categories[uuid(2)]?.parentID, isNull);
    });

    test('rejects a self parent given in mixed case', () {
      ledger.addCategory(category(uuid(2)));

      expect(
        () => ledger.updateCategory(
          category(uuid(2), parent: uuid(2).toUpperCase()),
        ),
        throwsA(const CategoryTooDeep()),
      );
      expect(ledger.categories[uuid(2)]?.parentID, isNull);
    });

    test('allows an edit that keeps the kind', () {
      ledger.addCategory(category(uuid(2)));
      final changes = ledger.updateCategory(
        category(uuid(2), name: 'renamed', kind: CategoryKind.expense),
      );

      expect(ledger.categories[uuid(2)]?.name, 'renamed');
      expect(changes, [UpsertCategory(ledger.categories[uuid(2)]!)]);
    });
  });

  group('addCategory', () {
    test('rejects a duplicate id', () {
      ledger.addCategory(category(uuid(2)));

      expect(
        () => ledger.addCategory(category(uuid(2), name: 'other')),
        throwsA(IdCollision(uuid(2))),
      );
      expect(ledger.categories[uuid(2)]?.name, 'cat');
    });

    test('rejects a category that names itself as parent', () {
      expect(
        () => ledger.addCategory(category(uuid(2), parent: uuid(2))),
        throwsA(const CategoryTooDeep()),
      );
      expect(ledger.categories, isEmpty);
    });

    test('stores the category verbatim', () {
      final given = category(uuid(2), name: 'groceries', colorHex: '#FF8800');
      final changes = ledger.addCategory(given);

      expect(ledger.categories[uuid(2)], given);
      expect(changes, [UpsertCategory(given)]);
    });
  });
}
