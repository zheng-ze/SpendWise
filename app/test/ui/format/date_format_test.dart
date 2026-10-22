import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/date_format.dart';

void main() {
  DateTime day(int year, int month, int dayOfMonth) =>
      DateTime.utc(year, month, dayOfMonth);

  test('the day header splits the number from its weekday and month line', () {
    final header = formatDayHeader(day(2026, 7, 7));
    expect(header.dayNumber, '7');
    expect(header.caption, 'Jul 2026 Tue');
  });

  test('the month selector label is abbreviated month and year', () {
    expect(formatMonthLabel(day(2026, 7, 7)), 'Jul 2026');
  });

  test('the year selector label is the year alone', () {
    expect(formatYearLabel(day(2026, 7, 7)), '2026');
  });

  test('the plan next-occurrence label names the day', () {
    expect(formatNextOccurrence(day(2026, 7, 14)), 'Next: 14 Jul 2026');
  });

  group('formatWeekRange', () {
    test('displays the last included day, not the exclusive end', () {
      final window = DateRange(day(2026, 7, 6), day(2026, 7, 13));
      expect(formatWeekRange(window), '6 Jul - 12 Jul');
    });

    test('a window spanning a month boundary names both months', () {
      final window = DateRange(day(2026, 6, 29), day(2026, 7, 6));
      expect(formatWeekRange(window), '29 Jun - 5 Jul');
    });

    test('a single-day window shows that day at both ends', () {
      final window = DateRange(day(2026, 7, 6), day(2026, 7, 7));
      expect(formatWeekRange(window), '6 Jul - 6 Jul');
    });
  });
}
