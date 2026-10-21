import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

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
  ledger.bus.subscribe().listen(
    (publication) => batches.add(publication.changes),
  );
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
  test('entryLifecycleMutatorsPublishAndNotify', () {
    final ledger = Ledger();
    final account = _account();
    ledger.addAccount(account);
    final entry = _entry(account.id);
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
