import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

void main() {
  LedgerState referenceOnlyCategoryLedger({required Set<String> entryIDs}) {
    final ledger = LedgerState();
    ledger.addAccount(account(uuid(1)));
    ledger.addCategory(category(uuid(2)));
    for (final id in entryIDs) {
      ledger.addEntry(entry(id: id, sourceID: uuid(1), categoryID: uuid(2)));
    }
    ledger.deleteCategory(uuid(2));
    ledger.purgeCategory(uuid(2));
    return ledger;
  }

  test('deleting the last entry carrying it removes the category row', () {
    final ledger = referenceOnlyCategoryLedger(entryIDs: {uuid(3)});

    final changes = ledger.deleteEntry(uuid(3));

    expect(changes, [DeleteEntry(uuid(3)), DeleteCategory(uuid(2))]);
    expect(ledger.categories, isEmpty);
  });

  test('a surviving entry keeps the category row', () {
    final ledger = referenceOnlyCategoryLedger(entryIDs: {uuid(3), uuid(4)});

    final changes = ledger.deleteEntry(uuid(3));

    expect(changes, [DeleteEntry(uuid(3))]);
    expect(ledger.categories[uuid(2)]?.lifecycle, LifecycleState.referenceOnly);
  });

  test('an active category is left alone when its last entry goes', () {
    final ledger = LedgerState();
    ledger.addAccount(account(uuid(1)));
    ledger.addCategory(category(uuid(2)));
    ledger.addEntry(entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(2)));

    final changes = ledger.deleteEntry(uuid(3));

    expect(changes, [DeleteEntry(uuid(3))]);
    expect(ledger.categories[uuid(2)]?.lifecycle, LifecycleState.active);
  });

  test('retargeting the last entry off it removes the category row', () {
    final ledger = referenceOnlyCategoryLedger(entryIDs: {uuid(3)});
    ledger.addCategory(category(uuid(5), name: 'other'));

    final changes = ledger.updateEntry(
      entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(5)),
    );

    expect(changes.last, DeleteCategory(uuid(2)));
    expect(ledger.categories[uuid(2)], isNull);
    expect(ledger.categories[uuid(5)]?.lifecycle, LifecycleState.active);
  });

  test('holders sweep before the category', () {
    final ledger = LedgerState();
    ledger.addAccount(account(uuid(1)));
    ledger.addCategory(category(uuid(2)));
    ledger.addEntry(
      entry(
        id: uuid(3),
        amount: Decimal.fromInt(-10),
        sourceID: uuid(1),
        categoryID: uuid(2),
      ),
    );
    ledger.deleteCategory(uuid(2));
    ledger.purgeCategory(uuid(2));
    ledger.deleteAccount(uuid(1));
    ledger.purgeAccount(uuid(1));

    final changes = ledger.deleteEntry(uuid(3));

    expect(changes, [
      DeleteEntry(uuid(3)),
      DeleteMoneySource(uuid(1)),
      DeleteCategory(uuid(2)),
    ]);
    expect(ledger.moneySources, isEmpty);
    expect(ledger.categories, isEmpty);
  });
}
