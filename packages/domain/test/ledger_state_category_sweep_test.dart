import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

/// The category branch of the dereference sweep, reached only by dropping the
/// last entry that carries a referenceOnly category.
void main() {
  LedgerState referenceOnlyCategoryLedger({
    required Map<String, Entry> entries,
  }) => LedgerState(
    moneySources: {uuid(1): AccountSource(account(uuid(1)))},
    categories: {
      uuid(2): category(uuid(2), lifecycle: LifecycleState.referenceOnly),
    },
    entries: entries,
  );

  test('deleting the last entry carrying it removes the category row', () {
    final ledger = referenceOnlyCategoryLedger(
      entries: {
        uuid(3): entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(2)),
      },
    );

    final changes = ledger.deleteEntry(uuid(3));

    expect(changes, [DeleteEntry(uuid(3)), DeleteCategory(uuid(2))]);
    expect(ledger.categories, isEmpty);
  });

  test('a surviving entry keeps the category row', () {
    final ledger = referenceOnlyCategoryLedger(
      entries: {
        uuid(3): entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(2)),
        uuid(4): entry(id: uuid(4), sourceID: uuid(1), categoryID: uuid(2)),
      },
    );

    final changes = ledger.deleteEntry(uuid(3));

    expect(changes, [DeleteEntry(uuid(3))]);
    expect(ledger.categories[uuid(2)]?.lifecycle, LifecycleState.referenceOnly);
  });

  test('an active category is left alone when its last entry goes', () {
    final ledger = LedgerState(
      moneySources: {uuid(1): AccountSource(account(uuid(1)))},
      categories: {uuid(2): category(uuid(2))},
      entries: {
        uuid(3): entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(2)),
      },
    );

    final changes = ledger.deleteEntry(uuid(3));

    expect(changes, [DeleteEntry(uuid(3))]);
    expect(ledger.categories[uuid(2)]?.lifecycle, LifecycleState.active);
  });

  test('retargeting the last entry off it removes the category row', () {
    final ledger = LedgerState(
      moneySources: {uuid(1): AccountSource(account(uuid(1)))},
      categories: {
        uuid(2): category(uuid(2), lifecycle: LifecycleState.referenceOnly),
        uuid(5): category(uuid(5), name: 'other'),
      },
      entries: {
        uuid(3): entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(2)),
      },
    );

    final changes = ledger.updateEntry(
      entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(5)),
    );

    expect(changes.last, DeleteCategory(uuid(2)));
    expect(ledger.categories[uuid(2)], isNull);
    expect(ledger.categories[uuid(5)]?.lifecycle, LifecycleState.active);
  });

  test('holders sweep before the category', () {
    final ledger = LedgerState(
      moneySources: {
        uuid(1): AccountSource(
          account(uuid(1), lifecycle: LifecycleState.referenceOnly),
        ),
      },
      categories: {
        uuid(2): category(uuid(2), lifecycle: LifecycleState.referenceOnly),
      },
      entries: {
        uuid(3): entry(
          id: uuid(3),
          amount: Decimal.fromInt(-10),
          sourceID: uuid(1),
          categoryID: uuid(2),
        ),
      },
    );

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
