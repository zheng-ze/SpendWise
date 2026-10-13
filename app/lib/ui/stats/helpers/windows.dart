import 'package:domain/domain.dart';

// MARK: - Helpers
DateRange monthWindow(DateTime month) {
  final start = DateTime.utc(month.year, month.month);
  final end = shiftMonthThenClampDayUtc(start, 1, day: 1);
  return DateRange(start, end);
}

DateRange yearWindow(DateTime year) {
  final start = DateTime.utc(year.year);
  final end = DateTime.utc(year.year + 1);
  return DateRange(start, end);
}
