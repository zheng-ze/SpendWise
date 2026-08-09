import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const planID = '00000000-0000-4000-8000-000000000001';
  const sourceID = '00000000-0000-4000-8000-000000000002';
  const categoryID = '00000000-0000-4000-8000-000000000003';

  EntryTemplate template({String? destinationID, String? category}) =>
      EntryTemplate(
        amount: Decimal.fromInt(-25),
        name: 'rent',
        categoryID: category,
        sourceID: sourceID,
        destinationID: destinationID,
      );

  test('ids are canonicalized at construction', () {
    final stored = EntryTemplate(
      amount: Decimal.fromInt(-25),
      name: 'rent',
      categoryID: categoryID.toUpperCase(),
      sourceID: sourceID.toUpperCase(),
      destinationID: planID.toUpperCase(),
    );

    expect(stored.sourceID, sourceID);
    expect(stored.categoryID, categoryID);
    expect(stored.destinationID, planID);
  });

  test('makeEntry takes the occurrence id for its plan and date', () {
    final date = DateTime.utc(2026, 3, 15);
    final made = template().makeEntry(planID, date);

    expect(made.id, OccurrenceID.make(planID, date));
    expect(made.date, date);
  });

  test('makeEntry carries the template fields through', () {
    final made = template(
      destinationID: planID,
      category: categoryID,
    ).makeEntry(planID, DateTime.utc(2026, 3, 15));

    expect(made.amount, Decimal.fromInt(-25));
    expect(made.name, 'rent');
    expect(made.categoryID, categoryID);
    expect(made.sourceID, sourceID);
    expect(made.destinationID, planID);
    expect(made.includeInAnalysis, isTrue);
    expect(made.lifecycle, LifecycleState.active);
  });

  test('the same occurrence rebuilds to the same entry', () {
    final date = DateTime.utc(2026, 3, 15);

    expect(
      template().makeEntry(planID, date),
      template().makeEntry(planID, date),
    );
  });

  test('holder queries read through the mixin', () {
    final transfer = template(destinationID: planID);

    expect(transfer.holderIDs, {sourceID, planID});
    expect(transfer.references(sourceID), isTrue);
    expect(transfer.touches({planID}), isTrue);
    expect(template().holderIDs, {sourceID});
  });

  test('equality covers every field', () {
    expect(template(), template());
    expect(template().hashCode, template().hashCode);
    expect(template(), isNot(template(category: categoryID)));
    expect(template(), isNot(template(destinationID: planID)));
  });
}
