import 'package:domain/src/time/calendar_month.dart';

DateTime startOfDayUtc(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

DateTime shiftMonthThenClampDayUtc(
  DateTime date,
  int months, {
  required int day,
}) {
  final shifted = DateTime.utc(date.year, date.month + months);
  final lastDay = daysInMonth(shifted);
  return DateTime.utc(
    shifted.year,
    shifted.month,
    day < lastDay ? day : lastDay,
  );
}
