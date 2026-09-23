enum RecurrenceFrequency {
  weekly(0),
  biweekly(1),
  monthly(2),
  quarterly(3),
  yearly(4);

  const RecurrenceFrequency(this.code);

  final int code;

  static RecurrenceFrequency fromCode(int code) {
    return switch (code) {
      0 => weekly,
      1 => biweekly,
      2 => monthly,
      3 => quarterly,
      4 => yearly,
      _ => throw ArgumentError.value(
        code,
        'code',
        'Unknown RecurrenceFrequency',
      ),
    };
  }

  DateTime stepFrom(DateTime anchor, int stepCount) {
    return switch (this) {
      weekly => anchor.add(Duration(days: 7 * stepCount)),
      biweekly => anchor.add(Duration(days: 14 * stepCount)),
      monthly => _addMonths(anchor, stepCount),
      quarterly => _addMonths(anchor, 3 * stepCount),
      yearly => _addMonths(anchor, 12 * stepCount),
    };
  }
}

DateTime _addMonths(DateTime anchor, int months) {
  final rawMonth = anchor.month - 1 + months;
  // Euclidean division; ~/ rounds toward zero.
  final year =
      anchor.year + (rawMonth >= 0 ? rawMonth ~/ 12 : (rawMonth - 11) ~/ 12);
  final month = rawMonth % 12 + 1;

  // DateTime overflows into the next month; clamp the day.
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  final day = anchor.day < lastDay ? anchor.day : lastDay;

  return anchor.isUtc
      ? DateTime.utc(
          year,
          month,
          day,
          anchor.hour,
          anchor.minute,
          anchor.second,
          anchor.millisecond,
          anchor.microsecond,
        )
      : DateTime(
          year,
          month,
          day,
          anchor.hour,
          anchor.minute,
          anchor.second,
          anchor.millisecond,
          anchor.microsecond,
        );
}
