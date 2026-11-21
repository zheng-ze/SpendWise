import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_spend.dart';
import 'package:spendwise/ledger/analysis/insights/usual_baseline.dart';

// MARK: - Results

@immutable
class DaySpend {
  const DaySpend({required this.day, required this.cumulative});

  final DateTime day;

  final Decimal cumulative;

  @override
  bool operator ==(Object other) {
    return other is DaySpend &&
        other.day == day &&
        other.cumulative == cumulative;
  }

  @override
  int get hashCode => Object.hash(day, cumulative);
}

@immutable
class UsualPace {
  const UsualPace({
    required this.usualMonth,
    required this.usualByToday,
    required this.gap,
  });

  final Decimal usualMonth;

  final Decimal usualByToday;

  final Decimal gap;

  Decimal get usualByMonthEnd => usualMonth;

  @override
  bool operator ==(Object other) {
    return other is UsualPace &&
        other.usualMonth == usualMonth &&
        other.usualByToday == usualByToday &&
        other.gap == gap;
  }

  @override
  int get hashCode => Object.hash(usualMonth, usualByToday, gap);
}

@immutable
class MonthPace {
  const MonthPace({
    required this.month,
    required this.today,
    required this.daysInMonth,
    required this.daysAfterToday,
    required this.cumulativeSpend,
    required this.spentSoFar,
    required this.completeMonthCount,
    required this.usual,
  });

  final DateTime month;

  final DateTime today;

  final int daysInMonth;

  final int daysAfterToday;

  final List<DaySpend> cumulativeSpend;

  final Decimal spentSoFar;

  final int completeMonthCount;

  final UsualPace? usual;

  @override
  bool operator ==(Object other) {
    return other is MonthPace &&
        other.month == month &&
        other.today == today &&
        other.daysInMonth == daysInMonth &&
        other.daysAfterToday == daysAfterToday &&
        listEquals(other.cumulativeSpend, cumulativeSpend) &&
        other.spentSoFar == spentSoFar &&
        other.completeMonthCount == completeMonthCount &&
        other.usual == usual;
  }

  @override
  int get hashCode => Object.hash(
    month,
    today,
    daysInMonth,
    daysAfterToday,
    Object.hashAll(cumulativeSpend),
    spentSoFar,
    completeMonthCount,
    usual,
  );
}

// MARK: - Query

MonthPace monthPace({
  required Iterable<AnalysisItem> items,
  required DateTime? firstRecordMonth,
  required DateTime today,
}) {
  final day = startOfDayUtc(today);
  final month = monthWindow(day).start;
  final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;
  final baselineMonths = usualBaselineMonths(
    firstRecordMonth: firstRecordMonth,
    today: day,
  );
  final elapsedWindow = DateRange(month, day.add(const Duration(days: 1)));
  final elapsedItems = items
      .where((i) => elapsedWindow.contains(i.date))
      .toList();
  final spentSoFar = monthExpenseSpend(YearMonth.fromUtc(month), elapsedItems);
  final baselineTotal = _baselineTotal(baselineMonths, items);
  final usual = _usualPace(
    baselineTotal: baselineTotal,
    monthCount: baselineMonths.length,
    daysInMonth: daysInMonth,
    dayOfMonth: day.day,
    spentSoFar: spentSoFar,
  );

  return MonthPace(
    month: month,
    today: day,
    daysInMonth: daysInMonth,
    daysAfterToday: daysInMonth - day.day,
    cumulativeSpend: _cumulativeSpend(month, day.day, elapsedItems),
    spentSoFar: spentSoFar,
    completeMonthCount: baselineMonths.length,
    usual: usual,
  );
}

// MARK: - Helpers

Decimal _baselineTotal(List<DateTime> months, Iterable<AnalysisItem> items) {
  if (months.isEmpty) return Decimal.zero;
  final span = DateRange(months.first, monthWindow(months.last).end);
  final inSpan = items.where((i) => span.contains(i.date)).toList();
  return months.fold(
    Decimal.zero,
    (sum, m) => sum + monthExpenseSpend(YearMonth.fromUtc(m), inSpan),
  );
}

UsualPace? _usualPace({
  required Decimal baselineTotal,
  required int monthCount,
  required int daysInMonth,
  required int dayOfMonth,
  required Decimal spentSoFar,
}) {
  if (monthCount < usualMinimumCompleteMonths) return null;
  final usualMonth = roundedCents(baselineTotal, monthCount);
  final usualByToday = roundedCents(
    baselineTotal * Decimal.fromInt(dayOfMonth),
    monthCount * daysInMonth,
  );
  return UsualPace(
    usualMonth: usualMonth,
    usualByToday: usualByToday,
    gap: spentSoFar - usualByToday,
  );
}

List<DaySpend> _cumulativeSpend(
  DateTime month,
  int elapsedDays,
  List<AnalysisItem> elapsedItems,
) {
  final daily = List.filled(elapsedDays, Decimal.zero);
  for (final item in elapsedItems) {
    if (item.kind != CategoryKind.expense) continue;
    daily[item.date.day - 1] += item.amount;
  }
  var running = Decimal.zero;
  final series = <DaySpend>[];
  for (var i = 0; i < elapsedDays; i++) {
    running += daily[i];
    series.add(
      DaySpend(
        day: DateTime.utc(month.year, month.month, i + 1),
        cumulative: running,
      ),
    );
  }
  return List.unmodifiable(series);
}
