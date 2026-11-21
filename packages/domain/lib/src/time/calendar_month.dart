import 'package:domain/src/time/date_range.dart';

DateTime startOfMonthUtc(DateTime date) => DateTime.utc(date.year, date.month);

int daysInMonth(DateTime month) =>
    DateTime.utc(month.year, month.month + 1, 0).day;

DateRange monthWindow(DateTime month) => DateRange(
  startOfMonthUtc(month),
  DateTime.utc(month.year, month.month + 1),
);
