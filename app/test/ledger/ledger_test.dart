import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

SubPocket _pocket({String name = 'pocket'}) => SubPocket(name: name);

TransactionCategory _category({
  required String name,
  CategoryKind kind = CategoryKind.expense,
  String? parentID,
}) => TransactionCategory(
  name: name,
  kind: kind,
  colorHex: '#000000',
  includeInAnalysis: true,
  parentID: parentID,
  symbol: 'tag',
);

Entry _entry(String sourceID, {String name = 'entry', String? categoryID}) =>
    Entry(
      amount: Decimal.fromInt(-10),
      name: name,
      sourceID: sourceID,
      categoryID: categoryID,
    );

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
  ledger.bus.subscribe().listen(batches.add);
  return batches;
}

void main() {
  test('mutationPublishesItsFacts', () {
    final ledger = Ledger();
    final batches = _batchesOf(ledger);

    final account = _account();
    ledger.addAccount(account);

    expect(batches, [
      [UpsertAccount(account)],
    ]);
  });

  test('cascadeMutationPublishesAllFactsInOneBatch', () {
    final ledger = Ledger();
    final account = _account();
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

  test('rejectedMutationPublishesNothing', () {
    final ledger = Ledger();
    final batches = _batchesOf(ledger);
    var notifications = 0;
    ledger.addListener(() => notifications++);

    expect(
      () => ledger.addEntry(_entry('4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43')),
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
      () => ledger.updateBudgetAmount(
        '4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43',
        Decimal.fromInt(10),
        YearMonth(2026, 1),
      ),
      throwsA(isA<UnknownBudget>()),
    );

    expect(batches, isEmpty);
    expect(notifications, 0);
    expect(ledger.state.budgets, isEmpty);
  });

  test('sequentialMutationsPublishInOrder', () {
    final ledger = Ledger();
    final batches = _batchesOf(ledger);

    final first = _account(name: 'a');
    final second = _account(name: 'b');
    ledger.addAccount(first);
    ledger.addAccount(second);
    ledger.addEntry(_entry(first.id, name: 'e'));

    expect(batches, hasLength(3));
    expect(batches[0], [UpsertAccount(first)]);
    expect(batches[1], [UpsertAccount(second)]);
    expect(batches[2].single, isA<UpsertEntry>());
  });

  test('mutationNotifiesListenersOncePerMutation', () {
    final ledger = Ledger();
    var notifications = 0;
    ledger.addListener(() => notifications++);

    final account = _account();
    ledger.addAccount(account);
    ledger.addPocket(_pocket(), account.id);

    expect(notifications, 2);
  });

  test('publishHappensBeforeListenersAreNotified', () {
    final ledger = Ledger();
    final order = <String>[];
    ledger.bus.subscribe().listen((_) => order.add('publish'));
    ledger.addListener(() => order.add('notify'));

    ledger.addAccount(_account());

    expect(order, ['publish', 'notify']);
  });

  test('stateIsCommittedBeforeTheBatchIsPublished', () {
    final ledger = Ledger();
    final account = _account();
    final seen = <String?>[];
    ledger.bus.subscribe().listen(
      (_) => seen.add(ledger.state.moneySources[account.id]?.name),
    );

    ledger.addAccount(account);

    expect(seen, [account.name]);
  });

  test('categoriesOfKindOrdersRootsThenTheirChildrenByName', () {
    final ledger = Ledger();
    final beta = _category(name: 'Beta');
    final alpha = _category(name: 'Alpha');
    ledger.addCategory(beta);
    ledger.addCategory(alpha);
    final betaZ = _category(name: 'Zeta', parentID: beta.id);
    final betaA = _category(name: 'Ants', parentID: beta.id);
    final alphaB = _category(name: 'Bees', parentID: alpha.id);
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
    final expense = _category(name: 'Food');
    final income = _category(name: 'Salary', kind: CategoryKind.income);
    final archived = _category(name: 'Gone');
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
    final visible = _category(name: 'Visible');
    final parent = _category(name: 'Parent');
    ledger.addCategory(visible);
    ledger.addCategory(parent);
    // An archived parent still accepts new children, which is the one way an
    // active child ends up hanging from a row the active filter drops.
    ledger.deleteCategory(parent.id);
    final child = _category(name: 'Child', parentID: parent.id);
    ledger.addCategory(child);

    expect(ledger.state.categories[child.id]!.lifecycle, LifecycleState.active);
    expect(ledger.categories(CategoryKind.expense).map((c) => c.name), [
      'Visible',
    ]);
  });

  test('categoriesOfKindSortsOrdinallyNotByLocale', () {
    final ledger = Ledger();
    for (final name in ['b', 'A', 'a', 'B']) {
      ledger.addCategory(_category(name: name));
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
    final account = _account();
    ledger.addAccount(account);
    final category = _category(name: 'Rent');
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

    // Deleting the doomed plan's category leaves the plan active but makes
    // its occurrences fail validation on resolve.
    ledger.deleteCategory(category.id);

    final batches = _batchesOf(ledger);
    final reported = <List<PlanFailure>>[];
    ledger.onPlanError = (failures) {
      // Recorded inside the callback so the assertion below proves the batch
      // was already published when the failures arrived.
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
    final account = _account();
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
}
