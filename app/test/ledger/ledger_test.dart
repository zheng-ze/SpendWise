import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';

import '../support/ledger_fixtures.dart';

SubPocket _pocket({String name = 'pocket'}) => SubPocket(name: name);

RecurringPlan _plan({
  required EntryTemplate template,
  required DateTime anchor,
  required DateTime lastResolvedDate,
}) => RecurringPlan(
  template: template,
  frequency: RecurrenceFrequency.monthly,
  anchor: anchor,
  lastResolvedDate: lastResolvedDate,
);

List<List<LedgerChange>> _batchesOf(Ledger ledger) {
  final batches = <List<LedgerChange>>[];
  ledger.bus.subscribe().listen(
    (publication) => batches.add(publication.changes),
  );
  return batches;
}

void main() {
  test('mutationPublishesItsFacts', () {
    final ledger = Ledger();
    final batches = _batchesOf(ledger);

    final account = testAccount();
    ledger.addAccount(account);

    expect(batches, [
      [UpsertAccount(account)],
    ]);
  });

  test('localMutationsPublishUnstamped', () {
    final ledger = Ledger();
    final publications = <LedgerPublication>[];
    ledger.bus.subscribe().listen(publications.add);

    final account = testAccount();
    ledger.addAccount(account);

    expect(publications, hasLength(1));
    expect(publications.single.changes, [UpsertAccount(account)]);
    expect(publications.single.stamps, isNull);
  });

  test('cascadeMutationPublishesAllFactsInOneBatch', () {
    final ledger = Ledger();
    final account = testAccount();
    ledger.addAccount(account);
    final batches = _batchesOf(ledger);

    final pocket = _pocket();
    ledger.addPocket(pocket, account.id);

    expect(batches, hasLength(1));
    expect(batches.single, [
      UpsertPocket(pocket),
      UpsertAccount(ledger.state.moneySources[account.id]!.asAccount!),
    ]);
  });

  test('updatePocketCommitsAndPublishesTheChangedPocket', () {
    final ledger = Ledger();
    final account = testAccount();
    ledger.addAccount(account);
    final pocket = SubPocket(name: 'Bills');
    ledger.addPocket(pocket, account.id);
    final updated = SubPocket(id: pocket.id, name: 'Rent');
    final batches = _batchesOf(ledger);

    final changes = ledger.updatePocket(updated);

    expect(changes, [UpsertPocket(updated)]);
    expect(ledger.state.moneySources[pocket.id]?.name, 'Rent');
    expect(batches, [changes]);
  });

  test('rejectedMutationPublishesNothing', () {
    final ledger = Ledger();
    final batches = _batchesOf(ledger);
    var notifications = 0;
    ledger.addListener(() => notifications++);

    expect(
      () => ledger.addEntry(
        testEntry(sourceID: '4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43'),
      ),
      throwsA(isA<UnknownHolder>()),
    );

    expect(batches, isEmpty);
    expect(notifications, 0);
    expect(ledger.state.entries, isEmpty);
  });

  test('rejectedBudgetMutationPublishesNothing', () {
    final ledger = Ledger();
    final batches = _batchesOf(ledger);
    var notifications = 0;
    ledger.addListener(() => notifications++);

    expect(
      () => ledger.updateBudgetLimit(
        '4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43',
        Decimal.fromInt(10),
      ),
      throwsA(isA<UnknownBudget>()),
    );

    expect(batches, isEmpty);
    expect(notifications, 0);
    expect(ledger.state.budgets, isEmpty);
  });

  test('updateBudgetLimitReplacesLimitAndPublishesBudget', () {
    final ledger = Ledger();
    final batches = _batchesOf(ledger);

    final added = ledger.addBudget(null, Decimal.fromInt(100));
    final budget = (added.single as UpsertBudget).budget;
    ledger.updateBudgetLimit(budget.id, Decimal.fromInt(250));

    final updated = Budget(
      id: budget.id,
      categoryID: null,
      limit: Decimal.fromInt(250),
    );
    expect(batches, hasLength(2));
    expect(batches[1], [UpsertBudget(updated)]);
    expect(ledger.state.budgets[budget.id], updated);
  });

  test('applySyncBatchRejectsZeroLimitBudgetWithoutChangingState', () {
    final ledger = Ledger();
    final batches = _batchesOf(ledger);
    var notifications = 0;
    ledger.addListener(() => notifications++);
    final before = ledger.state;

    final zeroLimit = Budget(
      id: '4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43',
      categoryID: null,
      limit: Decimal.zero,
    );
    expect(
      () => ledger.applySyncBatch([UpsertBudget(zeroLimit)], {}),
      throwsA(isA<StateError>()),
    );

    expect(identical(ledger.state, before), isTrue);
    expect(ledger.state.budgets, isEmpty);
    expect(batches, isEmpty);
    expect(notifications, 0);
  });

  test('sequentialMutationsPublishInOrder', () {
    final ledger = Ledger();
    final batches = _batchesOf(ledger);

    final first = testAccount(name: 'a');
    final second = testAccount(name: 'b');
    ledger.addAccount(first);
    ledger.addAccount(second);
    ledger.addEntry(testEntry(sourceID: first.id, name: 'e'));

    expect(batches, hasLength(3));
    expect(batches[0], [UpsertAccount(first)]);
    expect(batches[1], [UpsertAccount(second)]);
    expect(batches[2].single, isA<UpsertEntry>());
  });

  test('mutationNotifiesListenersOncePerMutation', () {
    final ledger = Ledger();
    var notifications = 0;
    ledger.addListener(() => notifications++);

    final account = testAccount();
    ledger.addAccount(account);
    ledger.addPocket(_pocket(), account.id);

    expect(notifications, 2);
  });

  test('publishHappensBeforeListenersAreNotified', () {
    final ledger = Ledger();
    final order = <String>[];
    ledger.bus.subscribe().listen((_) => order.add('publish'));
    ledger.addListener(() => order.add('notify'));

    ledger.addAccount(testAccount());

    expect(order, ['publish', 'notify']);
  });

  test('stateIsCommittedBeforeTheBatchIsPublished', () {
    final ledger = Ledger();
    final account = testAccount();
    final seen = <String?>[];
    ledger.bus.subscribe().listen(
      (_) => seen.add(ledger.state.moneySources[account.id]?.name),
    );

    ledger.addAccount(account);

    expect(seen, [account.name]);
  });

  test('categoriesOfKindOrdersRootsThenTheirChildrenByName', () {
    final ledger = Ledger();
    final beta = testCategory(name: 'Beta');
    final alpha = testCategory(name: 'Alpha');
    ledger.addCategory(beta);
    ledger.addCategory(alpha);
    final betaZ = testCategory(name: 'Zeta', parentID: beta.id);
    final betaA = testCategory(name: 'Ants', parentID: beta.id);
    final alphaB = testCategory(name: 'Bees', parentID: alpha.id);
    ledger.addCategory(betaZ);
    ledger.addCategory(betaA);
    ledger.addCategory(alphaB);

    expect(ledger.categories(CategoryKind.expense).map((c) => c.name), [
      'Alpha',
      'Bees',
      'Beta',
      'Ants',
      'Zeta',
    ]);
  });

  test('categoriesOfKindExcludesOtherKindsAndInactiveRows', () {
    final ledger = Ledger();
    final expense = testCategory(name: 'Food');
    final income = testCategory(name: 'Salary', kind: CategoryKind.income);
    final archived = testCategory(name: 'Gone');
    ledger.addCategory(expense);
    ledger.addCategory(income);
    ledger.addCategory(archived);
    ledger.deleteCategory(archived.id);

    expect(ledger.categories(CategoryKind.expense).map((c) => c.name), [
      'Food',
    ]);
    expect(ledger.categories(CategoryKind.income).map((c) => c.name), [
      'Salary',
    ]);
  });

  test('categoriesOfKindDropsAChildWhoseParentIsFilteredOut', () {
    final ledger = Ledger();
    final visible = testCategory(name: 'Visible');
    final parent = testCategory(name: 'Parent');
    ledger.addCategory(visible);
    ledger.addCategory(parent);
    ledger.deleteCategory(parent.id);
    final child = testCategory(name: 'Child', parentID: parent.id);
    ledger.addCategory(child);

    expect(ledger.state.categories[child.id]!.lifecycle, LifecycleState.active);
    expect(ledger.categories(CategoryKind.expense).map((c) => c.name), [
      'Visible',
    ]);
  });

  test('categoriesOfKindSortsOrdinallyNotByLocale', () {
    final ledger = Ledger();
    for (final name in ['b', 'A', 'a', 'B']) {
      ledger.addCategory(testCategory(name: name));
    }

    expect(ledger.categories(CategoryKind.expense).map((c) => c.name), [
      'A',
      'B',
      'a',
      'b',
    ]);
  });

  test('resolvePlansCommitsSuccessesAndReportsFailuresAfterwards', () {
    final ledger = Ledger();
    final account = testAccount();
    ledger.addAccount(account);
    final category = testCategory(name: 'Rent');
    ledger.addCategory(category);

    final anchor = DateTime.utc(2026, 1, 10);
    final healthy = _plan(
      template: EntryTemplate(
        amount: Decimal.fromInt(-100),
        name: 'healthy',
        sourceID: account.id,
      ),
      anchor: anchor,
      lastResolvedDate: anchor,
    );
    final doomed = _plan(
      template: EntryTemplate(
        amount: Decimal.fromInt(-50),
        name: 'doomed',
        sourceID: account.id,
        categoryID: category.id,
      ),
      anchor: anchor,
      lastResolvedDate: anchor,
    );
    ledger.addPlan(healthy);
    ledger.addPlan(doomed);

    ledger.deleteCategory(category.id);

    final batches = _batchesOf(ledger);
    final reported = <List<PlanFailure>>[];
    ledger.onPlanError = (failures) {
      reported.add([...failures]);
      expect(batches, hasLength(1));
    };

    ledger.resolvePlans(DateTime.utc(2026, 2, 15));

    expect(reported, hasLength(1));
    expect(reported.single.map((f) => f.planID), [doomed.id]);
    expect(reported.single.single.error, InactiveReference(category.id));

    final entries = ledger.state.entries.values.toList();
    expect(entries.map((e) => e.name), ['healthy']);
    expect(batches.single, contains(UpsertEntry(entries.single)));
  });

  test('resolvePlansWithNoFailuresDoesNotCallOnPlanError', () {
    final ledger = Ledger();
    final account = testAccount();
    ledger.addAccount(account);
    ledger.addPlan(
      _plan(
        template: EntryTemplate(
          amount: Decimal.fromInt(-100),
          name: 'rent',
          sourceID: account.id,
        ),
        anchor: DateTime.utc(2026, 1, 10),
        lastResolvedDate: DateTime.utc(2026, 1, 10),
      ),
    );
    var called = 0;
    ledger.onPlanError = (_) => called++;

    ledger.resolvePlans(DateTime.utc(2026, 2, 15));

    expect(called, 0);
    expect(ledger.state.entries, hasLength(1));
  });

  test('entryLifecycleMutatorsPublishAndNotify', () {
    final ledger = Ledger();
    final account = testAccount();
    ledger.addAccount(account);
    final entry = testEntry(sourceID: account.id);
    ledger.addEntry(entry);
    var notifications = 0;
    ledger.addListener(() => notifications++);

    final archived = ledger.archiveEntry(entry.id);
    final archivedEntry = ledger.state.binnedEntries[entry.id]!;
    expect(ledger.state.entries, isEmpty);
    expect(ledger.state.binnedEntries.keys, [entry.id]);

    final restored = ledger.restoreEntry(entry.id);
    expect(ledger.state.entries.keys, [entry.id]);

    ledger.archiveEntry(entry.id);
    final purged = ledger.purgeEntry(entry.id);
    expect(purged, [DeleteEntry(entry.id)]);
    expect(ledger.state.binnedEntries, isEmpty);

    expect(archived, [UpsertEntry(archivedEntry)]);
    expect(restored, [UpsertEntry(entry)]);
    expect(notifications, 4);
    expect(ledger.purgeEntry(entry.id), isEmpty);
    expect(notifications, 4);
  });
}
