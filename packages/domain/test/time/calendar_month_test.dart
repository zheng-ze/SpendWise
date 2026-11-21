import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('startOfMonthUtc', () {
    test('mapsAMidMonthInstantWithTimeOfDayToUtcMidnightOnTheFirst', () {
      expect(
        startOfMonthUtc(DateTime.utc(2026, 3, 14, 23, 59, 58)),
        DateTime.utc(2026, 3),
      );
    });

    test('keepsTheFieldMonthOfALocalDateTime', () {
      expect(
        startOfMonthUtc(DateTime(2026, 7, 31, 23, 30)),
        DateTime.utc(2026, 7),
      );
    });

    test('leavesAMonthStartUnchanged', () {
      final monthStart = DateTime.utc(2026, 5);

      expect(startOfMonthUtc(monthStart), monthStart);
    });
  });

  group('daysInMonth', () {
    test('returns31ForALongMonth', () {
      expect(daysInMonth(DateTime.utc(2026, 1, 10)), 31);
    });

    test('returns30ForAShortMonth', () {
      expect(daysInMonth(DateTime.utc(2026, 4, 10)), 30);
    });

    test('returns28ForFebruaryInACommonYear', () {
      expect(daysInMonth(DateTime.utc(2026, 2, 10)), 28);
    });

    test('returns29ForFebruaryInALeapYear', () {
      expect(daysInMonth(DateTime.utc(2028, 2, 10)), 29);
    });

    test('returns28ForFebruaryInACenturyYearThatIsNotALeapYear', () {
      expect(daysInMonth(DateTime.utc(2100, 2, 10)), 28);
    });

    test('rollsDecemberOverIntoJanuary', () {
      expect(daysInMonth(DateTime.utc(2026, 12, 5)), 31);
    });

    test('ignoresTheDayAndTimeOfTheInput', () {
      final firstMorning = DateTime.utc(2026, 4, 1);
      final lastNight = DateTime.utc(2026, 4, 30, 23, 59, 59);

      expect(daysInMonth(firstMorning), daysInMonth(lastNight));
    });
  });

  group('monthWindow', () {
    test('spansTheFirstToTheNextFirstForAMidMonthInstant', () {
      expect(
        monthWindow(DateTime.utc(2026, 3, 14, 9, 30)),
        DateRange(DateTime.utc(2026, 3), DateTime.utc(2026, 4)),
      );
    });

    test('endsInJanuaryOfTheNextYearForDecember', () {
      expect(
        monthWindow(DateTime.utc(2026, 12, 20)),
        DateRange(DateTime.utc(2026, 12), DateTime.utc(2027)),
      );
    });

    test('usesTheFieldMonthOfALocalDateTime', () {
      expect(
        monthWindow(DateTime(2026, 7, 31, 23, 30)),
        DateRange(DateTime.utc(2026, 7), DateTime.utc(2026, 8)),
      );
    });

    test('includesTheStartAndExcludesTheEnd', () {
      final window = monthWindow(DateTime.utc(2026, 6, 15));

      expect(window.contains(DateTime.utc(2026, 6)), isTrue);
      expect(window.contains(DateTime.utc(2026, 6, 30, 23, 59, 59)), isTrue);
      expect(window.contains(DateTime.utc(2026, 7)), isFalse);
    });

    test('hasALengthInDaysEqualToDaysInMonth', () {
      final month = DateTime.utc(2028, 2, 10);
      final window = monthWindow(month);

      expect(window.end.difference(window.start).inDays, daysInMonth(month));
    });
  });
}
