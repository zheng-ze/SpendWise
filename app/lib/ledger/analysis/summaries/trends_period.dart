import 'package:domain/domain.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart';
import 'package:spendwise/ledger/analysis/insights/completeness.dart';
import 'package:spendwise/ledger/analysis/summaries/month_spread.dart';

@immutable
class CategoryPeriodAverage {
  const CategoryPeriodAverage({
    required this.bucketID,
    required this.mainBucketID,
    required this.isDirect,
    required this.numerator,
    required this.mean,
  });

  final String? bucketID;
  final String? mainBucketID;
  final bool isDirect;
  final Decimal numerator;
  final Decimal? mean;
}

@immutable
class CategoryPeriodAverages {
  const CategoryPeriodAverages({
    required this.completePeriodCount,
    required this.rows,
  });

  final int completePeriodCount;
  final List<CategoryPeriodAverage> rows;
  bool get available => completePeriodCount > 0;
}

sealed class TrendsPeriod {
  const TrendsPeriod({
    required this.today,
    required this.firstRecordMonth,
    required this.breakdown,
    required this.averages,
  });

  final DateTime today;
  final DateTime? firstRecordMonth;
  final PeriodBreakdown breakdown;
  final CategoryPeriodAverages averages;

  BreakdownRow? get largestRow =>
      breakdown.rows.isEmpty ? null : breakdown.rows.first;
}

final class MonthTrendsPeriod extends TrendsPeriod {
  const MonthTrendsPeriod({
    required super.today,
    required super.firstRecordMonth,
    required super.breakdown,
    required super.averages,
    required this.spread,
    required this.highestMonth,
  });

  final MonthSpread spread;
  final MonthSlot? highestMonth;
}

MonthTrendsPeriod trendsPeriod({
  required Iterable<AnalysisItem> items,
  required LedgerState state,
  required DateTime endMonth,
  required CategoryKind kind,
  required BreakdownLevel level,
  required DateTime today,
}) {
  final day = startOfDayUtc(today);
  final first = firstRecordMonth(state);
  final spread = monthSpread(
    items: items,
    endMonth: monthWindow(endMonth).start,
    kind: kind,
    firstRecordMonth: first,
    today: day,
  );
  final wholeWindow = DateRange(
    spread.slots.first.window.start,
    spread.slots.last.window.end,
  );
  final breakdown = categoryBreakdown(
    items: items,
    state: state,
    window: wholeWindow,
    kind: kind,
    level: level,
  );
  final averages = _categoryPeriodAverages(
    items: items,
    state: state,
    wholePeriod: breakdown,
    windows: spread.slots.map((slot) => slot.window).toList(),
    firstRecordMonth: first,
    today: day,
  );
  final highest = _highestCompleteMonth(
    spread.slots,
    firstRecordMonth: first,
    today: day,
  );
  return MonthTrendsPeriod(
    today: day,
    firstRecordMonth: first,
    breakdown: breakdown,
    averages: averages,
    spread: spread,
    highestMonth: highest,
  );
}

CategoryPeriodAverages _categoryPeriodAverages({
  required Iterable<AnalysisItem> items,
  required LedgerState state,
  required PeriodBreakdown wholePeriod,
  required List<DateRange> windows,
  required DateTime? firstRecordMonth,
  required DateTime today,
}) {
  final completeWindows = windows
      .where(
        (window) =>
            classifyPeriod(
              window: window,
              firstRecordMonth: firstRecordMonth,
              today: today,
            ) ==
            PeriodCompleteness.complete,
      )
      .toList();
  final count = completeWindows.length;
  if (count == 0) {
    return CategoryPeriodAverages(
      completePeriodCount: count,
      rows: List.unmodifiable([
        for (final row in wholePeriod.rows)
          CategoryPeriodAverage(
            bucketID: row.bucketID,
            mainBucketID: row.mainBucketID,
            isDirect: row.isDirect,
            numerator: Decimal.zero,
            mean: null,
          ),
      ]),
    );
  }
  final numeratorBreakdown = categoryBreakdown(
    items: items,
    state: state,
    window: DateRange(completeWindows.first.start, completeWindows.last.end),
    kind: wholePeriod.kind,
    level: wholePeriod.level,
  );
  final numerators = {
    for (final row in numeratorBreakdown.rows)
      (row.bucketID, row.isDirect): row.amount,
  };
  final divisor = Decimal.fromInt(count);
  return CategoryPeriodAverages(
    completePeriodCount: count,
    rows: List.unmodifiable([
      for (final row in wholePeriod.rows) _averageRow(row, numerators, divisor),
    ]),
  );
}

CategoryPeriodAverage _averageRow(
  BreakdownRow row,
  Map<(String?, bool), Decimal> numerators,
  Decimal divisor,
) {
  final numerator = numerators[(row.bucketID, row.isDirect)] ?? Decimal.zero;
  final mean = (numerator / divisor).toDecimal(scaleOnInfinitePrecision: 12);
  return CategoryPeriodAverage(
    bucketID: row.bucketID,
    mainBucketID: row.mainBucketID,
    isDirect: row.isDirect,
    numerator: numerator,
    mean: mean,
  );
}

MonthSlot? _highestCompleteMonth(
  List<MonthSlot> slots, {
  required DateTime? firstRecordMonth,
  required DateTime today,
}) {
  final complete = slots.where(
    (slot) =>
        classifyPeriod(
          window: slot.window,
          firstRecordMonth: firstRecordMonth,
          today: today,
        ) ==
        PeriodCompleteness.complete,
  );
  MonthSlot? highest;
  for (final slot in complete) {
    if (slot.total <= Decimal.zero) continue;
    if (highest == null || slot.total > highest.total) highest = slot;
  }
  return highest;
}
