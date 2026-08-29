import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

void main() {
  test('replaying init rebuilds an equivalent state', () {
    final built = LedgerState();
    built.addAccount(account(uuid(1), name: 'wallet'));
    built.addCategory(category(uuid(2), name: 'food'));
    built.addEntry(entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(2)));

    final replayed = LedgerState.replaying([
      UpsertAccount(account(uuid(1), name: 'wallet')),
      UpsertCategory(category(uuid(2), name: 'food')),
      UpsertEntry(entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(2))),
    ]);

    expectSameTables(replayed, built);
  });

  test('a state serialized to upserts and replayed is unchanged', () {
    final original = LedgerState();
    original.addAccount(account(uuid(1), name: 'wallet'));
    original.addPocket(pocket(uuid(2), name: 'jar'), uuid(1));
    original.addCategory(category(uuid(3), name: 'food'));
    original.addCategory(category(uuid(4), name: 'snacks', parent: uuid(3)));
    original.addEntry(
      entry(id: uuid(5), sourceID: uuid(2), categoryID: uuid(4)),
    );
    original.addPlan(plan(uuid(6), sourceID: uuid(1), categoryID: uuid(3)));

    final replayed = LedgerState.replaying(serializeToUpserts(original));

    expectSameTables(replayed, original);
  });

  test('purging a pocket unlinks it from the parent account', () {
    final state = LedgerState();
    state.addAccount(account(uuid(1)));
    state.addPocket(pocket(uuid(2)), uuid(1));

    state.deletePocket(uuid(2));
    state.purgePocket(uuid(2));

    expect(state.moneySources[uuid(2)], isNull);
    expect(state.moneySources[uuid(1)]!.asAccount!.subPocketIDs, isEmpty);
  });

  test('replaying that same deletion leaves the parent link in place', () {
    final state = LedgerState();
    state.addAccount(account(uuid(1)));
    state.addPocket(pocket(uuid(2)), uuid(1));

    state.apply([DeleteMoneySource(uuid(2))]);

    expect(state.moneySources[uuid(2)], isNull);
    expect(state.moneySources[uuid(1)]!.asAccount!.subPocketIDs, {uuid(2)});
  });

  test('replaying a stream that never upserted a referenced holder throws', () {
    expect(
      () => LedgerState.replaying([
        UpsertEntry(entry(id: uuid(3), sourceID: uuid(1))),
      ]),
      throwsStateError,
    );
  });

  test('a well-formed stream still loads normally through replaying', () {
    final replayed = LedgerState.replaying([
      UpsertAccount(account(uuid(1), name: 'wallet')),
      UpsertCategory(category(uuid(2), name: 'food')),
      UpsertEntry(entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(2))),
    ]);

    expect(replayed.entries[uuid(3)]!.name, 'e');
    expect(replayed.moneySources[uuid(1)]!.asAccount!.name, 'wallet');
    expect(replayed.categories[uuid(2)]!.name, 'food');
  });
}

RecurringPlan plan(
  String id, {
  required String sourceID,
  required String categoryID,
}) => RecurringPlan(
  id: id,
  template: EntryTemplate(
    amount: Decimal.fromInt(-10),
    name: 'rent',
    sourceID: sourceID,
    categoryID: categoryID,
  ),
  frequency: RecurrenceFrequency.monthly,
  anchor: DateTime.utc(2026),
  lastResolvedDate: DateTime.utc(2026),
);

List<LedgerChange> serializeToUpserts(LedgerState state) => [
  for (final source in state.moneySources.values)
    LedgerChange.upsertSource(source),
  for (final category in state.categories.values) UpsertCategory(category),
  for (final entry in state.entries.values) UpsertEntry(entry),
  for (final plan in state.plans.values) UpsertPlan(plan),
];

void expectSameTables(LedgerState actual, LedgerState expected) {
  expect(actual.moneySources, expected.moneySources);
  expect(actual.entries, expected.entries);
  expect(actual.categories, expected.categories);
  expect(actual.plans, expected.plans);
}
