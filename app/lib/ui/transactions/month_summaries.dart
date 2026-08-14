import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

@immutable
class WeekSummary {
  const WeekSummary({
    required this.range,
    required this.income,
    required this.expenses,
    required this.isCurrentWeek,
  });

  final DateRange range;
  final Decimal income;
  final Decimal expenses;
  final bool isCurrentWeek;
}

@immutable
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.income,
    required this.expenses,
    required this.isCurrentMonth,
    required this.weeks,
  });

  final DateTime month;
  final Decimal income;
  final Decimal expenses;
  final bool isCurrentMonth;
  final List<WeekSummary> weeks;
}

/// [now] is a test seam; production call sites leave it as the wall clock.
List<MonthSummary> monthSummaries(
  LedgerState state,
  DateTime year, {
  DateTime? now,
}) {
  final today = startOfDayUtc(now ?? DateTime.now());
  final currentMonthStart = DateTime.utc(today.year, today.month);
  final currentWeekStart = _weekStart(today);

  final yearStart = DateTime.utc(year.year);
  final cutoff = shiftMonthThenClampDayUtc(currentMonthStart, 1, day: 1);
  final upperBound = cutoff.isBefore(DateTime.utc(year.year + 1))
      ? cutoff
      : DateTime.utc(year.year + 1);

  final entries = state.entries.values.toList();

  final months = <MonthSummary>[];
  var cursor = yearStart;
  while (cursor.isBefore(upperBound)) {
    final monthEnd = shiftMonthThenClampDayUtc(cursor, 1, day: 1);
    final monthRange = DateRange(cursor, monthEnd);

    final monthEntries = entries
        .where((entry) => monthRange.contains(entry.date))
        .toList();
    final monthTotals = sectionTotals(monthEntries);

    months.add(
      MonthSummary(
        month: cursor,
        income: monthTotals.income,
        expenses: monthTotals.expenses,
        isCurrentMonth: cursor == currentMonthStart,
        weeks: _weeks(
          entries: entries,
          monthRange: monthRange,
          currentWeekStart: currentWeekStart,
        ),
      ),
    );

    cursor = monthEnd;
  }

  return months.reversed.toList();
}

List<WeekSummary> _weeks({
  required List<Entry> entries,
  required DateRange monthRange,
  required DateTime currentWeekStart,
}) {
  final weeks = <WeekSummary>[];
  var cursor = _weekStart(monthRange.start);

  while (cursor.isBefore(monthRange.end)) {
    final weekEnd = cursor.add(const Duration(days: 7));
    final weekRange = DateRange(cursor, weekEnd);

    final weekEntries = entries
        .where((entry) => weekRange.contains(entry.date))
        .toList();
    final weekTotals = sectionTotals(weekEntries);

    weeks.add(
      WeekSummary(
        range: weekRange,
        income: weekTotals.income,
        expenses: weekTotals.expenses,
        isCurrentWeek: cursor == currentWeekStart,
      ),
    );

    cursor = weekEnd;
  }

  return weeks.reversed.toList();
}

/// Weeks run Monday to Sunday. Swift's original reads `Calendar.current`,
/// whose first weekday follows device locale; the port fixes it to the ISO
/// Monday start so a spillover week is deterministic across locales.
DateTime _weekStart(DateTime day) {
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Shared with day_sections.dart's identical section-totals rule: entry-level
/// `includeInAnalysis` only, never a category gate, transfers count toward
/// neither. Kept here as the month view's single call site so it stays a
/// one-line swap alongside that file's own copy if the domain ruling lands.
({Decimal income, Decimal expenses}) sectionTotals(List<Entry> entries) {
  var income = Decimal.zero;
  var expenses = Decimal.zero;

  for (final entry in entries) {
    if (entry.isTransfer || !entry.includeInAnalysis) continue;

    if (entry.amount < Decimal.zero) {
      expenses -= entry.amount;
    } else {
      income += entry.amount;
    }
  }

  return (income: income, expenses: expenses);
}
