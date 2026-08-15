import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/stats/trend.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  group('trendMonths month range', () {
    test('six months ending with and including the selected month', () {
      final months = trendMonths(DateTime.utc(2026, 7, 15), isYearRange: false);

      expect(months, [
        DateTime.utc(2026, 2),
        DateTime.utc(2026, 3),
        DateTime.utc(2026, 4),
        DateTime.utc(2026, 5),
        DateTime.utc(2026, 6),
        DateTime.utc(2026, 7),
      ]);
    });

    test('a January anchor rolls back into the previous year', () {
      final months = trendMonths(DateTime.utc(2026, 1, 10), isYearRange: false);

      expect(months, [
        DateTime.utc(2025, 8),
        DateTime.utc(2025, 9),
        DateTime.utc(2025, 10),
        DateTime.utc(2025, 11),
        DateTime.utc(2025, 12),
        DateTime.utc(2026, 1),
      ]);
    });
  });

  test('trendMonths year range returns all twelve months ascending', () {
    final months = trendMonths(DateTime.utc(2026, 5, 1), isYearRange: true);

    expect(months, [
      for (var month = 1; month <= 12; month++) DateTime.utc(2026, month),
    ]);
  });

  group('monthTotal', () {
    final month = DateTime.utc(2026, 7);

    test('sums items dated within the month', () {
      final items = [
        AnalysisItem(
          bucketID: null,
          amount: dec('10'),
          date: DateTime.utc(2026, 7, 1),
          kind: CategoryKind.expense,
        ),
        AnalysisItem(
          bucketID: null,
          amount: dec('5'),
          date: DateTime.utc(2026, 7, 31),
          kind: CategoryKind.expense,
        ),
      ];

      expect(monthTotal(items, month), dec('15'));
    });

    test('excludes items dated in the next month', () {
      final items = [
        AnalysisItem(
          bucketID: null,
          amount: dec('10'),
          date: DateTime.utc(2026, 8, 1),
          kind: CategoryKind.expense,
        ),
      ];

      expect(monthTotal(items, month), Decimal.zero);
    });

    test('excludes items dated before the month', () {
      final items = [
        AnalysisItem(
          bucketID: null,
          amount: dec('10'),
          date: DateTime.utc(2026, 6, 30),
          kind: CategoryKind.expense,
        ),
      ];

      expect(monthTotal(items, month), Decimal.zero);
    });
  });
}
