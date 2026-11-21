import 'package:domain/domain.dart';

// MARK: - Constants
const _monthRangeSpan = 6;
const _yearRangeSpan = 12;

// MARK: - Helpers
List<DateTime> trendMonths(DateTime detailDate, {required bool isYearRange}) {
  if (isYearRange) {
    final yearStart = DateTime.utc(detailDate.year);
    return [
      for (var offset = 0; offset < _yearRangeSpan; offset++)
        shiftMonthThenClampDayUtc(yearStart, offset, day: 1),
    ];
  }

  final selectedMonth = startOfMonthUtc(detailDate);
  return [
    for (var offset = _monthRangeSpan - 1; offset >= 0; offset--)
      shiftMonthThenClampDayUtc(selectedMonth, -offset, day: 1),
  ];
}

Decimal monthTotal(List<AnalysisItem> items, DateTime monthStart) {
  final interval = monthWindow(monthStart);
  return items
      .where((item) => interval.contains(item.date))
      .fold(Decimal.zero, (sum, item) => sum + item.amount);
}
