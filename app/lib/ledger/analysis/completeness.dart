import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

enum PeriodCompleteness { preRecord, complete, incomplete }

@immutable
class PeriodCompletenessResult {
  const PeriodCompletenessResult({
    required this.window,
    required this.firstRecordMonth,
    required this.today,
    required this.state,
  });

  final DateRange window;

  final DateTime? firstRecordMonth;

  final DateTime today;

  final PeriodCompleteness state;

  @override
  bool operator ==(Object other) {
    return other is PeriodCompletenessResult &&
        other.window == window &&
        other.firstRecordMonth == firstRecordMonth &&
        other.today == today &&
        other.state == state;
  }

  @override
  int get hashCode => Object.hash(window, firstRecordMonth, today, state);
}

DateTime? firstRecordMonth(LedgerState ledger) {
  DateTime? earliest;
  for (final entry in ledger.entries.values) {
    if (!entry.lifecycle.isActive) continue;
    if (earliest == null || entry.date.isBefore(earliest)) {
      earliest = entry.date;
    }
  }
  if (earliest == null) return null;
  return DateTime.utc(earliest.year, earliest.month, 1);
}

PeriodCompleteness classifyPeriod({
  required DateRange window,
  required DateTime? firstRecordMonth,
  required DateTime today,
}) {
  final start = startOfDayUtc(window.start);
  final end = startOfDayUtc(window.end);
  final day = startOfDayUtc(today);
  if (firstRecordMonth == null || start.isBefore(firstRecordMonth)) {
    return PeriodCompleteness.preRecord;
  }
  if (!end.isAfter(day)) return PeriodCompleteness.complete;
  return PeriodCompleteness.incomplete;
}

DateRange monthWindow(DateTime month) {
  final day = startOfDayUtc(month);
  final start = DateTime.utc(day.year, day.month, 1);
  return DateRange(start, DateTime.utc(day.year, day.month + 1, 1));
}

DateRange weekWindow(DateTime containingDay) {
  final day = startOfDayUtc(containingDay);
  final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
  return DateRange(monday, monday.add(const Duration(days: 7)));
}
