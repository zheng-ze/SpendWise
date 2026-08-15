import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

final DateFormat _dayCaption = DateFormat('MMM yyyy EEE');
final DateFormat _monthLabel = DateFormat('MMM yyyy');
final DateFormat _yearLabel = DateFormat('yyyy');
final DateFormat _fullDay = DateFormat('d MMM yyyy');
final DateFormat _rangeDay = DateFormat('d MMM');

@immutable
class DayHeaderLabel {
  const DayHeaderLabel({required this.dayNumber, required this.caption});

  final String dayNumber;
  final String caption;
}

DayHeaderLabel formatDayHeader(DateTime day) {
  return DayHeaderLabel(
    dayNumber: '${day.day}',
    caption: _dayCaption.format(day),
  );
}

String formatMonthLabel(DateTime month) => _monthLabel.format(month);

String formatYearLabel(DateTime year) => _yearLabel.format(year);

String formatNextOccurrence(DateTime day) => 'Next: ${_fullDay.format(day)}';

String formatEntryDate(DateTime day) => _fullDay.format(day);

/// The window is half-open, so its end is the day after the last one shown.
String formatWeekRange(DateRange window) {
  final lastIncluded = window.end.subtract(const Duration(days: 1));
  return '${_rangeDay.format(window.start)} - ${_rangeDay.format(lastIncluded)}';
}
