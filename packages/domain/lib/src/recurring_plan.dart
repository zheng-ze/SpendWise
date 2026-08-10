import 'package:domain/src/calendar_day.dart';
import 'package:domain/src/entry_template.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/plan_scheduling.dart';
import 'package:meta/meta.dart';

@immutable
class RecurringPlan {
  RecurringPlan({
    String? id,
    required this.template,
    required this.frequency,
    required DateTime anchor,
    DateTime? endDate,
    required DateTime lastResolvedDate,
  }) : id = normalizedOrNewID(id),
       anchor = startOfDayUtc(anchor),
       endDate = endDate == null ? null : startOfDayUtc(endDate),
       lastResolvedDate = startOfDayUtc(lastResolvedDate);

  final String id;
  final EntryTemplate template;
  final RecurrenceFrequency frequency;
  final DateTime anchor;
  final DateTime? endDate;
  final DateTime lastResolvedDate;

  RecurringPlan resolvedAt(DateTime date) => RecurringPlan(
    id: id,
    template: template,
    frequency: frequency,
    anchor: anchor,
    endDate: endDate,
    lastResolvedDate: date,
  );

  DateTime? nextOccurrence({required DateTime onOrAfter}) {
    final end = endDate;
    for (var stepCount = 0; ; stepCount++) {
      final date = frequency.stepFrom(anchor, stepCount);
      if (end != null && date.isAfter(end)) return null;
      if (!date.isBefore(onOrAfter)) return date;
    }
  }

  /// A finite plan whose last occurrence is already resolved can never emit
  /// again, so it is retired rather than carried as live config forever.
  bool isExhausted({required DateTime asOf}) {
    final end = endDate;
    if (end == null) return false;

    return !end.isAfter(asOf) && !lastResolvedDate.isBefore(end);
  }

  /// Exclusive of [after] and inclusive of the ceiling, so an occurrence is
  /// resolved exactly once as the cursor advances across it.
  List<DateTime> occurrences({
    required DateTime after,
    required DateTime upTo,
  }) {
    final end = endDate;
    final ceiling = end == null || upTo.isBefore(end) ? upTo : end;
    if (ceiling.isBefore(anchor)) return [];

    final dates = <DateTime>[];
    for (var stepCount = 0; ; stepCount++) {
      final date = frequency.stepFrom(anchor, stepCount);
      if (date.isAfter(ceiling)) return dates;
      if (date.isAfter(after)) dates.add(date);
    }
  }

  @override
  bool operator ==(Object other) {
    return other is RecurringPlan &&
        other.id == id &&
        other.template == template &&
        other.frequency == frequency &&
        other.anchor == anchor &&
        other.endDate == endDate &&
        other.lastResolvedDate == lastResolvedDate;
  }

  @override
  int get hashCode =>
      Object.hash(id, template, frequency, anchor, endDate, lastResolvedDate);
}
