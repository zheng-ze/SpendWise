import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const sourceID = '00000000-0000-4000-8000-000000000002';

  final template = EntryTemplate(
    amount: Decimal.fromInt(-25),
    name: 'rent',
    sourceID: sourceID,
  );

  RecurringPlan plan({
    DateTime? anchor,
    DateTime? endDate,
    DateTime? lastResolvedDate,
  }) => RecurringPlan(
    template: template,
    frequency: RecurrenceFrequency.monthly,
    anchor: anchor ?? DateTime.utc(2026, 1, 15),
    endDate: endDate,
    lastResolvedDate: lastResolvedDate ?? DateTime.utc(2026, 1, 15),
  );

  group('date normalization', () {
    test('a local anchor is stored as the utc midnight of its own day', () {
      final stored = plan(anchor: DateTime(2026, 3, 15, 23, 30));

      expect(stored.anchor, DateTime.utc(2026, 3, 15));
      expect(stored.anchor.isUtc, isTrue);
    });

    test('the cursor and end date normalize too', () {
      final stored = plan(
        endDate: DateTime(2026, 12, 31, 18),
        lastResolvedDate: DateTime(2026, 3, 15, 9),
      );

      expect(stored.endDate, DateTime.utc(2026, 12, 31));
      expect(stored.lastResolvedDate, DateTime.utc(2026, 3, 15));
    });
  });

  group('nextOccurrence', () {
    test('is inclusive of a reference landing on an occurrence', () {
      expect(
        plan().nextOccurrence(onOrAfter: DateTime.utc(2026, 2, 15)),
        DateTime.utc(2026, 2, 15),
      );
    });

    test('returns null once the end date is passed', () {
      final ending = plan(endDate: DateTime.utc(2026, 3, 20));

      expect(
        ending.nextOccurrence(onOrAfter: DateTime.utc(2026, 4, 1)),
        isNull,
      );
    });
  });

  group('occurrences', () {
    test('exclude the start and include the ceiling', () {
      final dates = plan().occurrences(
        after: DateTime.utc(2026, 1, 15),
        upTo: DateTime.utc(2026, 4, 15),
      );

      expect(dates, [
        DateTime.utc(2026, 2, 15),
        DateTime.utc(2026, 3, 15),
        DateTime.utc(2026, 4, 15),
      ]);
    });

    test('are capped by the end date when it precedes the ceiling', () {
      final dates = plan(endDate: DateTime.utc(2026, 3, 1)).occurrences(
        after: DateTime.utc(2026, 1, 1),
        upTo: DateTime.utc(2026, 6, 1),
      );

      expect(dates, [DateTime.utc(2026, 1, 15), DateTime.utc(2026, 2, 15)]);
    });

    test('ascend and clamp from a month-end anchor', () {
      final dates = plan(anchor: DateTime.utc(2026, 1, 31)).occurrences(
        after: DateTime.utc(2026, 1, 31),
        upTo: DateTime.utc(2026, 4, 30),
      );

      expect(dates, [
        DateTime.utc(2026, 2, 28),
        DateTime.utc(2026, 3, 31),
        DateTime.utc(2026, 4, 30),
      ]);
    });
  });

  group('isExhausted', () {
    test('is false without an end date', () {
      expect(plan().isExhausted(asOf: DateTime.utc(2030)), isFalse);
    });

    test('is false when the cursor has not reached the end date', () {
      final ending = plan(
        endDate: DateTime.utc(2026, 3, 1),
        lastResolvedDate: DateTime.utc(2026, 2, 1),
      );

      expect(ending.isExhausted(asOf: DateTime.utc(2026, 6, 1)), isFalse);
    });

    test('is true once the cursor has passed a bygone end date', () {
      final ending = plan(
        endDate: DateTime.utc(2026, 3, 1),
        lastResolvedDate: DateTime.utc(2026, 3, 1),
      );

      expect(ending.isExhausted(asOf: DateTime.utc(2026, 6, 1)), isTrue);
    });

    test('is true once the cursor lands exactly on the end date', () {
      final ending = plan(
        endDate: DateTime.utc(2026, 3, 1),
        lastResolvedDate: DateTime.utc(2026, 3, 1),
      );

      expect(ending.isExhausted(asOf: DateTime.utc(2026, 3, 1)), isTrue);
    });
  });

  test('resolvedAt advances only the cursor', () {
    final original = plan(endDate: DateTime.utc(2026, 9, 1));
    final advanced = original.resolvedAt(DateTime.utc(2026, 5, 1));

    expect(advanced.lastResolvedDate, DateTime.utc(2026, 5, 1));
    expect(advanced.id, original.id);
    expect(advanced.anchor, original.anchor);
    expect(advanced.endDate, original.endDate);
    expect(advanced.template, original.template);
    expect(advanced.frequency, original.frequency);
  });

  test('the id is normalized', () {
    final base = RecurringPlan(
      id: '00000000-0000-4000-8000-00000000000A',
      template: template,
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 15),
      lastResolvedDate: DateTime.utc(2026, 1, 15),
    );

    expect(base.id, '00000000-0000-4000-8000-00000000000a');
  });
}
