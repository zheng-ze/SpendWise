import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/insights/usual_baseline.dart';

DateTime _month(int year, int month) => DateTime.utc(year, month, 1);

List<DateTime> _monthsFrom(int year, int month, int count) {
  return [for (var i = 0; i < count; i++) _month(year, month + i)];
}

Decimal _cents(String numerator, int denominator) {
  return roundedCents(Decimal.parse(numerator), denominator);
}

void main() {
  final today = DateTime.utc(2026, 10, 3);

  test('requires three complete months for a usual baseline', () {
    expect(usualMinimumCompleteMonths, 3);
  });

  group('usualBaselineMonths', () {
    test('keeps only complete months from the first record month', () {
      final months = usualBaselineMonths(
        firstRecordMonth: _month(2026, 7),
        today: today,
      );

      expect(months, _monthsFrom(2026, 7, 3));
    });

    test('excludes months before the first record month', () {
      final months = usualBaselineMonths(
        firstRecordMonth: _month(2026, 8),
        today: today,
      );

      expect(months, [_month(2026, 8), _month(2026, 9)]);
    });

    test('never includes the current month', () {
      final months = usualBaselineMonths(
        firstRecordMonth: _month(2026, 10),
        today: today,
      );

      expect(months, isEmpty);
    });

    test('caps the window at the 11 months before the current month', () {
      final months = usualBaselineMonths(
        firstRecordMonth: _month(2025, 1),
        today: today,
      );

      expect(months, _monthsFrom(2025, 11, 11));
    });

    test('is empty without a first record month', () {
      final months = usualBaselineMonths(firstRecordMonth: null, today: today);

      expect(months, isEmpty);
    });

    test('crosses the year boundary in chronological order', () {
      final months = usualBaselineMonths(
        firstRecordMonth: _month(2025, 1),
        today: DateTime.utc(2027, 1, 3),
      );

      expect(months, _monthsFrom(2026, 2, 11));
    });

    test('normalizes a mid-month first record day to its month start', () {
      final months = usualBaselineMonths(
        firstRecordMonth: DateTime.utc(2026, 8, 17),
        today: today,
      );

      expect(months, [_month(2026, 8), _month(2026, 9)]);
    });

    test('normalizes a today carrying a time of day', () {
      final months = usualBaselineMonths(
        firstRecordMonth: _month(2026, 7),
        today: DateTime.utc(2026, 10, 3, 18, 45),
      );

      expect(months, _monthsFrom(2026, 7, 3));
    });

    test('keeps the previous month incomplete on the last day of a month', () {
      final months = usualBaselineMonths(
        firstRecordMonth: _month(2026, 7),
        today: DateTime.utc(2026, 10, 31),
      );

      expect(months, _monthsFrom(2026, 7, 3));
    });

    test('completes the ending month on the first day of the next month', () {
      final months = usualBaselineMonths(
        firstRecordMonth: _month(2026, 7),
        today: DateTime.utc(2026, 11, 1),
      );

      expect(months, _monthsFrom(2026, 7, 4));
    });
  });

  group('roundedCents', () {
    test('returns an exact quotient unchanged', () {
      expect(_cents('8413.20', 10), Decimal.parse('841.32'));
    });

    test('rounds a quotient above half a cent up', () {
      expect(_cents('25239.60', 310), Decimal.parse('81.42'));
    });

    test('rounds a quotient below half a cent down', () {
      expect(_cents('0.01', 3), Decimal.zero);
    });

    test('rounds exactly half a cent up', () {
      expect(_cents('2.675', 1), Decimal.parse('2.68'));
    });

    test('rounds exactly half a cent away from zero for negatives', () {
      expect(_cents('-0.01', 2), Decimal.parse('-0.01'));
    });

    test('returns zero for a zero numerator', () {
      expect(_cents('0', 7), Decimal.zero);
    });

    test('divides by a large denominator without truncating', () {
      expect(_cents('5', 1000), Decimal.parse('0.01'));
      expect(_cents('1000000', 3), Decimal.parse('333333.33'));
    });
  });
}
