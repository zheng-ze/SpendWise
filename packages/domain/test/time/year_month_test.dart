import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('equalYearMonthsCompareEqual', () {
    expect(const YearMonth(2026, 3), const YearMonth(2026, 3));
    expect(
      const YearMonth(2026, 3).hashCode,
      const YearMonth(2026, 3).hashCode,
    );
  });

  test('sameYearOrdersByMonth', () {
    expect(
      const YearMonth(2026, 3).compareTo(const YearMonth(2026, 5)),
      lessThan(0),
    );
    expect(
      const YearMonth(2026, 5).compareTo(const YearMonth(2026, 3)),
      greaterThan(0),
    );
  });

  test('decemberToJanuaryOrdersAcrossTheYearBoundary', () {
    const december = YearMonth(2026, 12);
    const january = YearMonth(2027, 1);

    expect(december.compareTo(january), lessThan(0));
    expect(january.compareTo(december), greaterThan(0));
    expect(december < january, isTrue);
    expect(january > december, isTrue);
  });

  test('fromUtcTakesTheYearAndMonthOfTheDate', () {
    expect(
      YearMonth.fromUtc(DateTime.utc(2026, 7, 19)),
      const YearMonth(2026, 7),
    );
  });

  test('comparisonOperatorsIncludeEquality', () {
    const month = YearMonth(2026, 4);

    expect(month <= const YearMonth(2026, 4), isTrue);
    expect(month >= const YearMonth(2026, 4), isTrue);
  });
}
