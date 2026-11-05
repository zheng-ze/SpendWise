import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/plans/plan_last_added.dart';

void main() {
  final source = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Wallet',
    type: AccountType.cash,
  );

  RecurringPlan monthlyPlan({
    required DateTime anchor,
    required DateTime lastResolvedDate,
    DateTime? endDate,
  }) {
    return RecurringPlan(
      template: EntryTemplate(
        amount: Decimal.parse('-10'),
        name: 'Rent',
        sourceID: source.id,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: anchor,
      endDate: endDate,
      lastResolvedDate: lastResolvedDate,
    );
  }

  group('lastAddedDate', () {
    test('returns null when the cursor is before the anchor', () {
      final plan = monthlyPlan(
        anchor: DateTime.utc(2026, 3, 10),
        lastResolvedDate: DateTime.utc(2026, 3, 9),
      );

      expect(lastAddedDate(plan), isNull);
    });

    test('returns the anchor when the cursor equals the anchor', () {
      final plan = monthlyPlan(
        anchor: DateTime.utc(2026, 3, 10),
        lastResolvedDate: DateTime.utc(2026, 3, 10),
      );

      expect(lastAddedDate(plan), DateTime.utc(2026, 3, 10));
    });

    test(
      'returns the newest occurrence the cursor has covered mid-schedule',
      () {
        final plan = monthlyPlan(
          anchor: DateTime.utc(2026, 1, 15),
          lastResolvedDate: DateTime.utc(2026, 4, 20),
        );

        expect(lastAddedDate(plan), DateTime.utc(2026, 4, 15));
      },
    );

    test('is clamped by endDate when the cursor is past it', () {
      final plan = monthlyPlan(
        anchor: DateTime.utc(2026, 1, 15),
        endDate: DateTime.utc(2026, 3, 1),
        lastResolvedDate: DateTime.utc(2026, 6, 1),
      );

      expect(lastAddedDate(plan), DateTime.utc(2026, 2, 15));
    });

    test('Jan 31 monthly plan with cursor on Feb 27 returns Jan 31', () {
      final plan = monthlyPlan(
        anchor: DateTime.utc(2026, 1, 31),
        lastResolvedDate: DateTime.utc(2026, 2, 27),
      );

      expect(lastAddedDate(plan), DateTime.utc(2026, 1, 31));
    });

    test(
      'Jan 31 monthly plan with cursor on Feb 28 returns the clamped Feb 28',
      () {
        final plan = monthlyPlan(
          anchor: DateTime.utc(2026, 1, 31),
          lastResolvedDate: DateTime.utc(2026, 2, 28),
        );

        expect(lastAddedDate(plan), DateTime.utc(2026, 2, 28));
      },
    );

    test('edited earlier anchor with cursor at the old anchor reports the new schedule date (schedule-only)', () {
      final plan = monthlyPlan(
        anchor: DateTime.utc(2026, 3, 5),
        lastResolvedDate: DateTime.utc(2026, 3, 10),
      );

      expect(lastAddedDate(plan), DateTime.utc(2026, 3, 5));
    });
  });
}
