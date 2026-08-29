import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final may = DateRange(DateTime.utc(2026, 5, 1), DateTime.utc(2026, 6, 1));

  group('DateRange.contains', () {
    test('a date before the start is excluded', () {
      expect(may.contains(DateTime.utc(2026, 4, 30)), isFalse);
    });

    test('a date months before the start is excluded', () {
      expect(may.contains(DateTime.utc(2026, 1, 15)), isFalse);
    });

    test('the start is included and the end is not', () {
      expect(may.contains(may.start), isTrue);
      expect(may.contains(may.end), isFalse);
    });
  });

  group('DateRange value equality', () {
    test('ranges with the same bounds are equal', () {
      final other = DateRange(
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 6, 1),
      );

      expect(other, may);
      expect(other.hashCode, may.hashCode);
    });

    test('ranges differing in start are not equal', () {
      final earlierStart = DateRange(DateTime.utc(2026, 4, 1), may.end);

      expect(earlierStart, isNot(may));
      expect(earlierStart.hashCode, isNot(may.hashCode));
    });

    test('ranges differing in end are not equal', () {
      final laterEnd = DateRange(may.start, DateTime.utc(2026, 7, 1));

      expect(laterEnd, isNot(may));
      expect(laterEnd.hashCode, isNot(may.hashCode));
    });

    test('a range keys a map by value', () {
      final byWindow = {
        may: 'may',
        DateRange(may.end, DateTime.utc(2026, 7, 1)): 'june',
      };

      expect(
        byWindow[DateRange(DateTime.utc(2026, 5, 1), DateTime.utc(2026, 6, 1))],
        'may',
      );
      expect(byWindow.length, 2);
    });
  });
}
