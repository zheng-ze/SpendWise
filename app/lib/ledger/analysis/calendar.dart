import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/entry_record.dart';
import 'package:spendwise/ledger/analysis/upcoming.dart';

@immutable
class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.entries,
    required this.plans,
  });

  final DateTime date;
  final List<EntryRecord> entries;
  final List<PlanOccurrence> plans;

  @override
  bool operator ==(Object other) {
    return other is CalendarDay &&
        other.date == date &&
        other.entries == entries &&
        other.plans == plans;
  }

  @override
  int get hashCode => Object.hash(date, entries, plans);
}

List<CalendarDay> calendarDays({
  required LedgerState ledger,
  required DateTime today,
  required DateRange window,
  Set<String>? sourceIDs,
}) {
  final day = startOfDayUtc(today);
  final range = normalizedWindow(window);
  final scope = normalizedScope(sourceIDs);
  final recorded = <DateTime, List<Entry>>{};
  for (final entry in ledger.entries.values) {
    if (!entry.lifecycle.isActive) continue;
    if (!inScope(entry, scope)) continue;
    if (!range.contains(entry.date)) continue;
    final entryDay = startOfDayUtc(entry.date);
    (recorded[entryDay] ??= []).add(entry);
  }
  final planned = <DateTime, List<PlanOccurrence>>{};
  for (final occurrence in upcomingPlanOccurrences(
    ledger: ledger,
    today: day,
    window: range,
    sourceIDs: scope,
  )) {
    (planned[occurrence.date] ??= []).add(occurrence);
  }
  final dates = {...recorded.keys, ...planned.keys}.toList()
    ..sort((a, b) => a.compareTo(b));
  return List.unmodifiable([
    for (final date in dates)
      CalendarDay(
        date: date,
        entries: List.unmodifiable([
          for (final entry in recorded[date]?.reversed ?? const <Entry>[])
            entryRecord(ledger, entry),
        ]),
        plans: List.unmodifiable(
          <PlanOccurrence>[...?planned[date]]
            ..sort((a, b) => a.planID.compareTo(b.planID)),
        ),
      ),
  ]);
}
