import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/seed_data.dart';

List<T> _rowsOf<T extends LedgerChange>(List<LedgerChange> changes) =>
    changes.whereType<T>().toList();

void main() {
  test('seedChangesCoversTheDeliberateEdgeCases', () {
    final changes = seedChanges();
    final entries = _rowsOf<UpsertEntry>(changes)
        .map((change) => change.entry)
        .toList();
    final categoryIDs = _rowsOf<UpsertCategory>(changes)
        .map((change) => change.category.id)
        .toSet();

    final transfer = entries.singleWhere((entry) => entry.name == 'To savings');
    final rent = entries.singleWhere((entry) => entry.name == 'Rent');
    final subcategoryNames = entries
        .where(
          (entry) =>
              entry.name == 'FairPrice groceries' ||
              entry.name == 'Tekka wet market',
        )
        .map((entry) => entry.categoryID);

    expect(transfer.destinationID, isNotNull);
    expect(transfer.categoryID, isNull);
    expect(transfer.amount, Decimal.fromInt(500));
    expect(rent.categoryID, isNull);
    expect(rent.amount, Decimal.fromInt(-1200));
    expect(subcategoryNames, everyElement(isIn(categoryIDs)));
  });

  test('plansDoNotBackfillOnFirstResolve', () {
    final today = DateTime.utc(2026, 3, 31);
    final plans = seedChanges(today: today)
        .whereType<UpsertPlan>()
        .map((change) => change.plan)
        .toList();

    expect(plans, hasLength(2));
    for (final plan in plans) {
      expect(plan.frequency, RecurrenceFrequency.monthly);
      expect(plan.lastResolvedDate, plan.anchor);
      expect(
        plan.occurrences(after: plan.lastResolvedDate, upTo: today),
        isEmpty,
      );
    }

    final netflix = plans.singleWhere(
      (plan) => plan.template.name == 'Netflix',
    );
    final salary = plans.singleWhere(
      (plan) => plan.template.name == 'Monthly salary',
    );

    expect(netflix.anchor, DateTime.utc(2026, 3, 20));
    expect(netflix.template.amount, Decimal.parse('-19.98'));
    expect(salary.anchor, DateTime.utc(2026, 3, 25));
    expect(salary.template.amount, Decimal.fromInt(3200));
  });

  test('duplicateIdsAreRejected', () {
    const repeatedID = '00000000-0000-4000-8000-000000000001';

    expect(
      () =>
          buildSeed(LedgerState(), today: _fixedToday, newID: () => repeatedID),
      throwsA(isA<IdCollision>()),
    );
  });
}

final _fixedToday = DateTime.utc(2026, 8, 12);
