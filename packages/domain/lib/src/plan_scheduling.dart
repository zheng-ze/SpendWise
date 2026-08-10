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

  /// The k-th occurrence counting from [anchor], k == 0 being the anchor.
  DateTime stepFrom(DateTime anchor, int k) {
    return switch (this) {
      weekly => anchor.add(Duration(days: 7 * k)),
      biweekly => anchor.add(Duration(days: 14 * k)),
      monthly => _addMonths(anchor, k),
      quarterly => _addMonths(anchor, 3 * k),
      yearly => _addMonths(anchor, 12 * k),
    };
  }
}

DateTime _addMonths(DateTime anchor, int months) {
  final rawMonth = anchor.month - 1 + months;
  // Euclidean, not truncating: `~/` rounds toward zero, which would hold the
  // year fixed for every negative rawMonth while `%` still wrapped the month.
  final year =
      anchor.year + (rawMonth >= 0 ? rawMonth ~/ 12 : (rawMonth - 11) ~/ 12);
  final month = rawMonth % 12 + 1;

  // DateTime overflows a too-large day into the next month, so the day is
  // clamped to the target month's length instead.
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

/// The UTC midnight of the calendar day [date] names.
///
/// Components are read as given rather than converted, so a local midnight
/// keeps its own calendar day instead of sliding onto the previous one east of
/// Greenwich. Occurrence ids hash the day and window filters compare against
/// UTC bounds, so a local-midnight date would otherwise land in the wrong month
/// at a boundary and regenerate under a new id after a timezone move.
DateTime startOfDayUtc(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
