import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const planID = '00000000-0000-4000-8000-000000000001';

  test('the same plan and day give the same id', () {
    expect(
      OccurrenceID.make(planID, DateTime.utc(2026, 3, 15)),
      OccurrenceID.make(planID, DateTime.utc(2026, 3, 15)),
    );
  });

  test('time of day is collapsed', () {
    expect(
      OccurrenceID.make(planID, DateTime.utc(2026, 3, 15, 23, 59, 59)),
      OccurrenceID.make(planID, DateTime.utc(2026, 3, 15)),
    );
  });

  test('the plan id is matched case-insensitively', () {
    expect(
      OccurrenceID.make(planID.toUpperCase(), DateTime.utc(2026, 3, 15)),
      OccurrenceID.make(planID, DateTime.utc(2026, 3, 15)),
    );
  });

  test('a different day gives a different id', () {
    expect(
      OccurrenceID.make(planID, DateTime.utc(2026, 3, 16)),
      isNot(OccurrenceID.make(planID, DateTime.utc(2026, 3, 15))),
    );
  });

  test('a different plan gives a different id', () {
    expect(
      OccurrenceID.make(
        '00000000-0000-4000-8000-000000000002',
        DateTime.utc(2026, 3, 15),
      ),
      isNot(OccurrenceID.make(planID, DateTime.utc(2026, 3, 15))),
    );
  });

  test('dates before the reference date are usable', () {
    expect(
      OccurrenceID.make(planID, DateTime.utc(1999, 6, 1)),
      isNot(OccurrenceID.make(planID, DateTime.utc(2026, 3, 15))),
    );
  });

  test('the id is a lowercase version 5 uuid', () {
    final id = OccurrenceID.make(planID, DateTime.utc(2026, 3, 15));

    expect(id, id.toLowerCase());
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
