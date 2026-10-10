import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/completeness.dart';
import 'package:spendwise/ledger/analysis/insight_rules.dart';

@immutable
class WeekSoFar {
  WeekSoFar({
    required this.today,
    required this.weekStart,
    required this.firstRecordMonth,
    required this.observedWindow,
    required this.elapsedDayCount,
    required this.observedTotal,
    required this.observedExpenseCount,
    required this.state,
    required List<DateRange> baselineWindows,
    required List<BaselineEvidence> baselineEvidence,
    required this.baselineTotal,
    required this.baselineExpenseCount,
    required this.usualMean,
    required this.difference,
    required this.relativeChangePercent,
    required this.qualifies,
  }) : baselineWindows = List.unmodifiable(baselineWindows),
       baselineEvidence = List.unmodifiable(baselineEvidence);

  final DateTime today;

  final DateTime weekStart;

  final DateTime? firstRecordMonth;

  final DateRange observedWindow;

  final int elapsedDayCount;

  final Decimal observedTotal;

  final int observedExpenseCount;

  final InsightState state;

  final List<DateRange> baselineWindows;

  final List<BaselineEvidence> baselineEvidence;

  final Decimal? baselineTotal;

  final int? baselineExpenseCount;

  final Decimal? usualMean;

  final Decimal? difference;

  final Decimal? relativeChangePercent;

  final bool qualifies;

  @override
  bool operator ==(Object other) {
    return other is WeekSoFar &&
        other.today == today &&
        other.weekStart == weekStart &&
        other.firstRecordMonth == firstRecordMonth &&
        other.observedWindow == observedWindow &&
        other.elapsedDayCount == elapsedDayCount &&
        other.observedTotal == observedTotal &&
        other.observedExpenseCount == observedExpenseCount &&
        other.state == state &&
        listEquals(other.baselineWindows, baselineWindows) &&
        listEquals(other.baselineEvidence, baselineEvidence) &&
        other.baselineTotal == baselineTotal &&
        other.baselineExpenseCount == baselineExpenseCount &&
        other.usualMean == usualMean &&
        other.difference == difference &&
        other.relativeChangePercent == relativeChangePercent &&
        other.qualifies == qualifies;
  }

  @override
  int get hashCode => Object.hash(
    today,
    weekStart,
    firstRecordMonth,
    observedWindow,
    elapsedDayCount,
    observedTotal,
    observedExpenseCount,
    state,
    Object.hashAll(baselineWindows),
    Object.hashAll(baselineEvidence),
    baselineTotal,
    baselineExpenseCount,
    usualMean,
    difference,
    relativeChangePercent,
    qualifies,
  );
}

WeekSoFar weekSoFar({
  required Iterable<AnalysisItem> items,
  required DateTime? firstRecordMonth,
  required DateTime today,
  required InsightRules rules,
}) {
  final day = startOfDayUtc(today);
  final weekStart = weekWindow(day).start;
  final elapsedDayCount = day.weekday;
  final observedWindow = DateRange(weekStart, day.add(const Duration(days: 1)));
  final expenses = items
      .where((item) => item.kind == CategoryKind.expense)
      .toList();
  ({Decimal total, int count}) sumIn(DateRange window) {
    var total = Decimal.zero;
    var count = 0;
    for (final item in expenses) {
      if (!window.contains(item.date)) continue;
      total += item.amount;
      count++;
    }
    return (total: total, count: count);
  }

  final observed = sumIn(observedWindow);
  WeekSoFar result({
    required InsightState state,
    List<DateRange> windows = const [],
    List<BaselineEvidence> evidence = const [],
    Decimal? baselineTotal,
    int? baselineCount,
    BaselineComparison? comparison,
    bool qualifies = false,
  }) => WeekSoFar(
    today: day,
    weekStart: weekStart,
    firstRecordMonth: firstRecordMonth,
    observedWindow: observedWindow,
    elapsedDayCount: elapsedDayCount,
    observedTotal: observed.total,
    observedExpenseCount: observed.count,
    state: state,
    baselineWindows: windows,
    baselineEvidence: evidence,
    baselineTotal: baselineTotal,
    baselineExpenseCount: baselineCount,
    usualMean: comparison?.usualMean,
    difference: comparison?.difference,
    relativeChangePercent: comparison?.relativeChangePercent,
    qualifies: qualifies,
  );

  final windows = <DateRange>[];
  final evidence = <BaselineEvidence>[];
  for (var back = baselineWindowCount; back >= 1; back--) {
    final monday = weekStart.subtract(
      Duration(days: DateTime.daysPerWeek * back),
    );
    final complete = classifyPeriod(
      window: weekWindow(monday),
      firstRecordMonth: firstRecordMonth,
      today: day,
    );
    if (complete != PeriodCompleteness.complete) {
      return result(state: InsightState.historyNeeded);
    }
    final window = DateRange(
      monday,
      monday.add(Duration(days: elapsedDayCount)),
    );
    final sum = sumIn(window);
    windows.add(window);
    evidence.add((
      window: window,
      total: sum.total,
      expenseItemCount: sum.count,
    ));
  }
  final baselineTotal = evidence.fold(
    Decimal.zero,
    (sum, record) => sum + record.total,
  );
  final baselineCount = evidence.fold(
    0,
    (sum, record) => sum + record.expenseItemCount,
  );
  final enoughHistory = baselineCount >= rules.minimumExpenseCount;
  return result(
    state: enoughHistory ? InsightState.available : InsightState.historyNeeded,
    windows: windows,
    evidence: evidence,
    baselineTotal: baselineTotal,
    baselineCount: baselineCount,
    comparison: compareToBaseline(observed.total, baselineTotal),
    qualifies:
        enoughHistory &&
        rules.qualifies(observed.total, baselineTotal, baselineCount),
  );
}
