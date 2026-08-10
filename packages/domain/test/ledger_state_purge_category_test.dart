import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  late LedgerState ledger;

  setUp(() {
    ledger = LedgerState();
    ledger.addAccount(account(uuid(1)));
  });

  group('purgeCategory', () {
    test('an archived unreferenced category is removed', () {
      ledger.addCategory(category(uuid(2)));
      ledger.deleteCategory(uuid(2));

      final changes = ledger.purgeCategory(uuid(2));

      expect(changes, [DeleteCategory(uuid(2))]);
      expect(ledger.categories, isEmpty);
    });

    test('an archived referenced category survives as referenceOnly', () {
      ledger.addCategory(category(uuid(2)));
      ledger.addEntry(
        entry(id: uuid(3), categoryID: uuid(2), sourceID: uuid(1)),
      );
      ledger.deleteCategory(uuid(2));

      final changes = ledger.purgeCategory(uuid(2));

      expect(changes, [
        UpsertCategory(
          category(uuid(2), lifecycle: LifecycleState.referenceOnly),
        ),
      ]);
      expect(
        ledger.categories[uuid(2)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
    });

    test('an active child of the purged parent is swept too', () {
      ledger.addCategory(category(uuid(2)));
      ledger.deleteCategory(uuid(2));
      // Adding under an archived parent is legal, so the child stays active
      // while the parent sits in the bin.
      ledger.addCategory(category(uuid(3), parent: uuid(2)));
      expect(ledger.categories[uuid(3)]?.lifecycle, LifecycleState.active);

      final changes = ledger.purgeCategory(uuid(2));

      expect(changes, [DeleteCategory(uuid(2)), DeleteCategory(uuid(3))]);
      expect(ledger.categories, isEmpty);
    });

    test('each child row is judged by its own reference count', () {
      ledger.addCategory(category(uuid(2)));
      ledger.addCategory(category(uuid(3), parent: uuid(2)));
      ledger.addCategory(category(uuid(4), parent: uuid(2)));
      ledger.addEntry(
        entry(id: uuid(5), categoryID: uuid(3), sourceID: uuid(1)),
      );
      ledger.deleteCategory(uuid(2));

      ledger.purgeCategory(uuid(2));

      expect(
        ledger.categories[uuid(3)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
      expect(ledger.categories[uuid(4)], isNull);
      expect(
        ledger.categories[uuid(2)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
    });

    test('clearing the last child entry tombstones the whole chain', () {
      ledger.addCategory(category(uuid(2)));
      ledger.addCategory(category(uuid(3), parent: uuid(2)));
      ledger.addEntry(
        entry(id: uuid(5), categoryID: uuid(3), sourceID: uuid(1)),
      );
      ledger.deleteCategory(uuid(2));
      ledger.purgeCategory(uuid(2));

      final changes = ledger.deleteEntry(uuid(5));

      expect(ledger.categories, isEmpty);
      expect(changes, contains(DeleteCategory(uuid(3))));
      expect(changes, contains(DeleteCategory(uuid(2))));
    });

    test('a parent with its own entry outlives the swept child', () {
      ledger.addCategory(category(uuid(2)));
      ledger.addCategory(category(uuid(3), parent: uuid(2)));
      ledger.addEntry(
        entry(id: uuid(4), categoryID: uuid(2), sourceID: uuid(1)),
      );
      ledger.addEntry(
        entry(id: uuid(5), categoryID: uuid(3), sourceID: uuid(1)),
      );
      ledger.deleteCategory(uuid(2));
      ledger.purgeCategory(uuid(2));

      ledger.deleteEntry(uuid(5));

      expect(ledger.categories[uuid(3)], isNull);
      expect(
        ledger.categories[uuid(2)]?.lifecycle,
        LifecycleState.referenceOnly,
      );
    });

    test('a referenced parent survives while its children are removed', () {
      ledger.addCategory(category(uuid(2)));
      ledger.addCategory(category(uuid(3), parent: uuid(2)));
      ledger.addEntry(
        entry(id: uuid(4), categoryID: uuid(2), sourceID: uuid(1)),
      );
      ledger.deleteCategory(uuid(2));

      final changes = ledger.purgeCategory(uuid(2));

      // Parent first, then children.
      expect(changes, [
        UpsertCategory(
          category(uuid(2), lifecycle: LifecycleState.referenceOnly),
        ),
        DeleteCategory(uuid(3)),
      ]);
    });

    test('purging an active category is a no-op', () {
      ledger.addCategory(category(uuid(2)));

      final changes = ledger.purgeCategory(uuid(2));

      expect(changes, isEmpty);
      expect(ledger.categories[uuid(2)]?.lifecycle, LifecycleState.active);
    });

    test('purging an unknown id is a no-op', () {
      ledger.addCategory(category(uuid(2)));
      ledger.deleteCategory(uuid(2));

      final changes = ledger.purgeCategory(uuid(9));

      expect(changes, isEmpty);
      expect(ledger.categories.keys, [uuid(2)]);
    });

    test('purge leaves entries untouched', () {
      ledger.addCategory(category(uuid(2)));
      ledger.addEntry(
        entry(
          id: uuid(3),
          categoryID: uuid(2),
          amount: Decimal.fromInt(-25),
          sourceID: uuid(1),
        ),
      );
      final before = Map.of(ledger.entries);
      ledger.deleteCategory(uuid(2));

      ledger.purgeCategory(uuid(2));

      expect(ledger.entries, before);
      expect(ledger.entries[uuid(3)]?.categoryID, uuid(2));
    });
  });
}
