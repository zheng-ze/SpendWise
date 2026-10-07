import 'package:domain/domain.dart';

const _monthRangeSpan = 6;
const _yearRangeSpan = 12;
const _firstDayOfMonth = 1;
const _monthIntervalSpanMonths = 1;

List<DateTime> trendMonths(DateTime detailDate, {required bool isYearRange}) {
  if (isYearRange) {
    final yearStart = DateTime.utc(detailDate.year);
    return [
      for (var offset = 0; offset < _yearRangeSpan; offset++)
        shiftMonthThenClampDayUtc(yearStart, offset, day: _firstDayOfMonth),
    ];
  }

  final selectedMonth = DateTime.utc(detailDate.year, detailDate.month);
  return [
    for (var offset = _monthRangeSpan - 1; offset >= 0; offset--)
      shiftMonthThenClampDayUtc(selectedMonth, -offset, day: _firstDayOfMonth),
  ];
}

Decimal monthTotal(List<AnalysisItem> items, DateTime monthStart) {
  final interval = _monthInterval(monthStart);
  return items
      .where((item) => interval.contains(item.date))
      .fold(Decimal.zero, (sum, item) => sum + item.amount);
}

DateRange _monthInterval(DateTime monthStart) {
  final end = shiftMonthThenClampDayUtc(
    monthStart,
    _monthIntervalSpanMonths,
    day: _firstDayOfMonth,
  );
  return DateRange(monthStart, end);
}
