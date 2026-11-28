import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

String hexID(int n) =>
    'abcdef00-0000-4abc-8abc-${n.toRadixString(16).padLeft(12, 'a')}';

LedgerState fullState(int base) {
  final accountID = hexID(base + 1);
  final pocketID = hexID(base + 2);
  final parentID = hexID(base + 3);
  final childID = hexID(base + 4);
  final binnedEntryID = hexID(base + 6);
  return LedgerState(
    moneySources: {
      accountID: AccountSource(account(accountID, subPocketIDs: {pocketID})),
      pocketID: PocketSource(pocket(pocketID)),
    },
    categories: {
      childID: category(childID, parent: parentID),
      parentID: category(parentID),
    },
    entries: {
      hexID(base + 5): entry(
        id: hexID(base + 5),
        sourceID: pocketID,
        categoryID: childID,
      ),
    },
    binnedEntries: {
      binnedEntryID: Entry(
        id: binnedEntryID,
        date: DateTime.utc(2026),
        amount: Decimal.fromInt(-5),
        name: 'binned',
        sourceID: accountID,
        categoryID: parentID,
        lifecycle: LifecycleState.archived,
      ),
    },
    plans: {
      hexID(base + 7): RecurringPlan(
        id: hexID(base + 7),
        template: EntryTemplate(
          amount: Decimal.fromInt(-10),
          name: 'rent',
          sourceID: accountID,
          categoryID: parentID,
        ),
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026),
        lastResolvedDate: DateTime.utc(2026),
      ),
    },
    budgets: {
      hexID(base + 8): Budget(
        id: hexID(base + 8),
        categoryID: parentID,
        limit: Decimal.fromInt(100),
      ),
    },
  );
}

LedgerState copyOf(LedgerState state) => LedgerState(
  moneySources: state.moneySources,
  entries: state.entries,
  binnedEntries: state.binnedEntries,
  categories: state.categories,
  plans: state.plans,
  budgets: state.budgets,
);

void expectSameSixMaps(LedgerState actual, LedgerState expected) {
  expect(actual.moneySources, expected.moneySources);
  expect(actual.entries, expected.entries);
  expect(actual.binnedEntries, expected.binnedEntries);
  expect(actual.categories, expected.categories);
  expect(actual.plans, expected.plans);
  expect(actual.budgets, expected.budgets);
}

void main() {
  test('replacing a full ledger leaves exactly the replacement', () {
    final state = fullState(0x10);
    final replacement = fullState(0x20);

    state.replaceContents(replacement);

    expectSameSixMaps(state, replacement);
  });

  test('the changes are deletes then upserts in the stated order', () {
    final state = fullState(0x10);
    final replacement = fullState(0x20);

    final changes = state.replaceContents(replacement);

    final kinds = [for (final change in changes) change.runtimeType];
    expect(kinds, [
      DeleteBudget,
      DeletePlan,
      DeleteEntry,
      DeleteEntry,
      DeleteCategory,
      DeleteCategory,
      DeleteMoneySource,
      DeleteMoneySource,
      UpsertAccount,
      UpsertPocket,
      UpsertCategory,
      UpsertCategory,
      UpsertEntry,
      UpsertEntry,
      UpsertPlan,
      UpsertBudget,
    ]);
    final upsertedCategories = changes.whereType<UpsertCategory>().toList();
    expect(upsertedCategories.first.category.parentID, isNull);
    expect(upsertedCategories.last.category.parentID, isNotNull);
    final upsertedEntries = changes.whereType<UpsertEntry>().toList();
    expect(upsertedEntries.first.entry.lifecycle, LifecycleState.active);
    expect(upsertedEntries.last.entry.lifecycle, LifecycleState.archived);
  });

  test(
    'applying the changes to a copy of the old maps gives the replacement',
    () {
      final state = fullState(0x10);
      final replacement = fullState(0x20);
      final copy = copyOf(state);

      final changes = state.replaceContents(replacement);
      copy.apply(changes);

      expectSameSixMaps(copy, replacement);
    },
  );

  test('replacing an empty ledger with an empty one returns no changes', () {
    final state = LedgerState();

    expect(state.replaceContents(LedgerState()), isEmpty);
  });

  test('an invalid replacement throws and leaves the receiver unchanged', () {
    final state = fullState(0x10);
    final before = copyOf(state);
    final invalid = LedgerState(
      entries: {hexID(0x30): entry(id: hexID(0x30), sourceID: hexID(0x31))},
    );

    expect(() => state.replaceContents(invalid), throwsStateError);

    expectSameSixMaps(state, before);
  });

  test('a shared id moving from referenceOnly to active is accepted', () {
    final accountID = hexID(0x40);
    final categoryID = hexID(0x41);
    final state = LedgerState();
    state.addAccount(account(accountID));
    state.addCategory(category(categoryID));
    state.addEntry(
      entry(id: hexID(0x42), sourceID: accountID, categoryID: categoryID),
    );
    state.deleteCategory(categoryID);
    state.purgeCategory(categoryID);
    expect(
      state.categories[categoryID]?.lifecycle,
      LifecycleState.referenceOnly,
    );
    final replacement = LedgerState(
      categories: {categoryID: category(categoryID)},
    );

    state.replaceContents(replacement);

    expectSameSixMaps(state, replacement);
  });
}
