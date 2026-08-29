DateTime startOfDayUtc(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

DateTime shiftMonthThenClampDayUtc(
  DateTime date,
  int months, {
  required int day,
}) {
  final shifted = DateTime.utc(date.year, date.month + months);
  return DateTime.utc(
    shifted.year,
    shifted.month,
    _clampDay(day, shifted.year, shifted.month),
  );
}

int _clampDay(int day, int year, int month) {
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return day < lastDay ? day : lastDay;
}
