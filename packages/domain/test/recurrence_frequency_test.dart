import 'package:domain/src/recurrence_frequency.dart';
import 'package:test/test.dart';

void main() {
  group('stepFrom', () {
    test('k of zero returns the anchor', () {
      final anchor = DateTime.utc(2026, 1, 31);
      for (final frequency in RecurrenceFrequency.values) {
        expect(frequency.stepFrom(anchor, 0), anchor);
      }
    });

    test('day strides add whole weeks', () {
      final anchor = DateTime.utc(2026, 1, 31);

      expect(
        RecurrenceFrequency.weekly.stepFrom(anchor, 3),
        DateTime.utc(2026, 2, 21),
      );
      expect(
        RecurrenceFrequency.biweekly.stepFrom(anchor, 2),
        DateTime.utc(2026, 2, 28),
      );
    });

    test('a month-end anchor clamps to the shorter month', () {
      final anchor = DateTime.utc(2026, 1, 31);

      expect(
        RecurrenceFrequency.monthly.stepFrom(anchor, 1),
        DateTime.utc(2026, 2, 28),
      );
      expect(
        RecurrenceFrequency.monthly.stepFrom(anchor, 2),
        DateTime.utc(2026, 3, 31),
      );
      expect(
        RecurrenceFrequency.monthly.stepFrom(anchor, 3),
        DateTime.utc(2026, 4, 30),
      );
    });

    test('clamping follows the leap year', () {
      expect(
        RecurrenceFrequency.monthly.stepFrom(DateTime.utc(2024, 1, 31), 1),
        DateTime.utc(2024, 2, 29),
      );
      expect(
        RecurrenceFrequency.yearly.stepFrom(DateTime.utc(2024, 2, 29), 1),
        DateTime.utc(2025, 2, 28),
      );
    });

    test('clamping is judged per occurrence, not carried forward', () {
      final anchor = DateTime.utc(2026, 1, 31);
      final second = RecurrenceFrequency.monthly.stepFrom(anchor, 2);

      expect(second.day, 31);
    });

    test('month strides roll into later years', () {
      expect(
        RecurrenceFrequency.monthly.stepFrom(DateTime.utc(2026, 12, 15), 13),
        DateTime.utc(2028, 1, 15),
      );
      expect(
        RecurrenceFrequency.quarterly.stepFrom(DateTime.utc(2026, 1, 31), 4),
        DateTime.utc(2027, 1, 31),
      );
    });

    test('time of day and the utc flag survive a stride', () {
      final anchor = DateTime.utc(2026, 1, 31, 14, 30, 5, 250, 125);
      final stepped = RecurrenceFrequency.monthly.stepFrom(anchor, 1);

      expect(stepped, DateTime.utc(2026, 2, 28, 14, 30, 5, 250, 125));
      expect(stepped.isUtc, isTrue);
      expect(
        RecurrenceFrequency.monthly.stepFrom(DateTime(2026, 1, 31), 1).isUtc,
        isFalse,
      );
    });
  });

  group('codes', () {
    test('are pinned', () {
      expect(
        RecurrenceFrequency.values.map((frequency) => frequency.code),
        [0, 1, 2, 3, 4],
      );
    });

    test('round-trip through fromCode', () {
      for (final frequency in RecurrenceFrequency.values) {
        expect(RecurrenceFrequency.fromCode(frequency.code), frequency);
      }
    });

    test('an unknown code is rejected', () {
      expect(
        () => RecurrenceFrequency.fromCode(5),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
