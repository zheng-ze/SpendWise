import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/completeness.dart';

enum ComparedWithUsualState { available, notEnoughData }

@immutable
class ComparedWithUsual {
  const ComparedWithUsual({
    required this.selectedMonth,
    required this.kind,
    required this.firstRecordMonth,
    required this.observedWindow,
    required this.elapsedDayCount,
    required this.observedTotal,
    required this.state,
    required this.baselineWindows,
    required this.baselineTotal,
    required this.usualMean,
  });

  final DateTime selectedMonth;

  final CategoryKind kind;

  final DateTime? firstRecordMonth;

  final DateRange observedWindow;

  final int elapsedDayCount;

  final Decimal observedTotal;

  final ComparedWithUsualState state;

  final List<DateRange> baselineWindows;

  final Decimal? baselineTotal;

  final Decimal? usualMean;

  @override
  bool operator ==(Object other) {
    return other is ComparedWithUsual &&
        other.selectedMonth == selectedMonth &&
        other.kind == kind &&
        other.firstRecordMonth == firstRecordMonth &&
        other.observedWindow == observedWindow &&
        other.elapsedDayCount == elapsedDayCount &&
        other.observedTotal == observedTotal &&
        other.state == state &&
        listEquals(other.baselineWindows, baselineWindows) &&
        other.baselineTotal == baselineTotal &&
        other.usualMean == usualMean;
  }

  @override
  int get hashCode => Object.hash(
    selectedMonth,
    kind,
    firstRecordMonth,
    observedWindow,
    elapsedDayCount,
    observedTotal,
    state,
    Object.hashAll(baselineWindows),
    baselineTotal,
    usualMean,
  );
}

List<DateRange>? previousCompleteMonthWindows({
  required DateTime selectedMonth,
  required int elapsedDayCount,
  required DateTime? firstRecordMonth,
  required DateTime today,
}) {
  final selected = monthWindow(selectedMonth).start;
  final selectedLength = _monthLength(selected);
  if (elapsedDayCount < 1 || elapsedDayCount > selectedLength) {
    throw ArgumentError.value(
      elapsedDayCount,
      'elapsedDayCount',
      'Must be within the selected month.',
    );
  }
  final first = firstRecordMonth == null
      ? null
      : DateTime.utc(firstRecordMonth.year, firstRecordMonth.month, 1);
  final day = startOfDayUtc(today);
  final windows = <DateRange>[];
  for (var back = 3; back >= 1; back--) {
    final baseline = DateTime.utc(selected.year, selected.month - back, 1);
    if (classifyPeriod(
          window: monthWindow(baseline),
          firstRecordMonth: first,
          today: day,
        ) !=
        PeriodCompleteness.complete) {
      return null;
    }
    final elapsed = elapsedDayCount.clamp(1, _monthLength(baseline));
    windows.add(DateRange(baseline, baseline.add(Duration(days: elapsed))));
  }
  return List.unmodifiable(windows);
}

ComparedWithUsual comparedWithUsual({
  required Iterable<AnalysisItem> items,
  required DateTime selectedMonth,
  required CategoryKind kind,
  required DateTime? firstRecordMonth,
  required DateTime today,
}) {
  final selected = monthWindow(selectedMonth).start;
  final day = startOfDayUtc(today);
  final currentMonth = monthWindow(day).start;
  final first = firstRecordMonth == null
      ? null
      : DateTime.utc(firstRecordMonth.year, firstRecordMonth.month, 1);
  final DateRange observedWindow;
  final int elapsedDayCount;
  if (selected == currentMonth) {
    observedWindow = DateRange(selected, day.add(const Duration(days: 1)));
    elapsedDayCount = day.day;
  } else {
    observedWindow = monthWindow(selected);
    elapsedDayCount = _monthLength(selected);
  }
  final ofKind = items.where((item) => item.kind == kind).toList();
  var observedTotal = Decimal.zero;
  for (final item in ofKind) {
    if (!observedWindow.contains(item.date)) continue;
    observedTotal += item.amount;
  }
  final baselines = previousCompleteMonthWindows(
    selectedMonth: selected,
    elapsedDayCount: elapsedDayCount,
    firstRecordMonth: first,
    today: day,
  );
  if (baselines == null) {
    return ComparedWithUsual(
      selectedMonth: selected,
      kind: kind,
      firstRecordMonth: first,
      observedWindow: observedWindow,
      elapsedDayCount: elapsedDayCount,
      observedTotal: observedTotal,
      state: ComparedWithUsualState.notEnoughData,
      baselineWindows: const [],
      baselineTotal: null,
      usualMean: null,
    );
  }
  var baselineTotal = Decimal.zero;
  for (final item in ofKind) {
    for (final window in baselines) {
      if (!window.contains(item.date)) continue;
      baselineTotal += item.amount;
      break;
    }
  }
  return ComparedWithUsual(
    selectedMonth: selected,
    kind: kind,
    firstRecordMonth: first,
    observedWindow: observedWindow,
    elapsedDayCount: elapsedDayCount,
    observedTotal: observedTotal,
    state: ComparedWithUsualState.available,
    baselineWindows: baselines,
    baselineTotal: baselineTotal,
    usualMean: (baselineTotal / Decimal.fromInt(3)).toDecimal(
      scaleOnInfinitePrecision: 12,
    ),
  );
}

int _monthLength(DateTime monthStart) {
  return DateTime.utc(
    monthStart.year,
    monthStart.month + 1,
    1,
  ).difference(monthStart).inDays;
}
