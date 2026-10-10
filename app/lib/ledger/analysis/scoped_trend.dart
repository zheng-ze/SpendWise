import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/analysis_period_mode.dart';
import 'package:spendwise/ledger/analysis/completeness.dart';
import 'package:spendwise/ledger/analysis/month_spread.dart';

const scopedTrendSlotCount = 12;

const scopedTrendDecemberMonth = 12;

@immutable
class ScopedTrend {
  const ScopedTrend({
    required this.mode,
    required this.endMonth,
    required this.kind,
    required this.mainBucketID,
    required this.scope,
    required this.slots,
  });

  final AnalysisPeriodMode mode;

  final DateTime endMonth;

  final CategoryKind kind;

  final String? mainBucketID;

  final AnalysisCategoryScope scope;

  final List<MonthSlot> slots;

  @override
  bool operator ==(Object other) {
    return other is ScopedTrend &&
        other.mode == mode &&
        other.endMonth == endMonth &&
        other.kind == kind &&
        other.mainBucketID == mainBucketID &&
        other.scope == scope &&
        listEquals(other.slots, slots);
  }

  @override
  int get hashCode => Object.hash(
    mode,
    endMonth,
    kind,
    mainBucketID,
    scope,
    Object.hashAll(slots),
  );
}

ScopedTrend scopedTrend({
  required String? mainBucketID,
  required AnalysisCategoryScope scope,
  required CategoryKind kind,
  required DateTime period,
  required AnalysisPeriodMode mode,
  required DateTime today,
  required LedgerState state,
  required Iterable<AnalysisItem> items,
}) {
  final main = normalizedOptionalID(mainBucketID);
  final day = startOfDayUtc(period);
  final todayDay = startOfDayUtc(today);
  final anchor = switch (mode) {
    AnalysisPeriodMode.month => monthWindow(day).start,
    AnalysisPeriodMode.year => DateTime.utc(
      day.year,
      scopedTrendDecemberMonth,
      1,
    ),
  };
  switch (mode) {
    case AnalysisPeriodMode.month:
      if (anchor.isAfter(monthWindow(todayDay).start)) {
        throw ArgumentError.value(period, 'period', 'Month is in the future.');
      }
    case AnalysisPeriodMode.year:
      if (day.year > todayDay.year) {
        throw ArgumentError.value(period, 'period', 'Year is in the future.');
      }
  }
  final selected = _scopedItems(items, state, main, scope);
  final masked = mode == AnalysisPeriodMode.year && day.year == todayDay.year
      ? selected
            .where(
              (item) => item.date.isBefore(
                DateTime.utc(todayDay.year, todayDay.month + 1, 1),
              ),
            )
            .toList()
      : selected;
  final spread = monthSpread(
    items: masked,
    endMonth: anchor,
    kind: kind,
    firstRecordMonth: firstRecordMonth(state),
    today: todayDay,
  );
  return ScopedTrend(
    mode: mode,
    endMonth: anchor,
    kind: kind,
    mainBucketID: main,
    scope: scope,
    slots: spread.slots,
  );
}

List<AnalysisItem> _scopedItems(
  Iterable<AnalysisItem> items,
  LedgerState state,
  String? main,
  AnalysisCategoryScope scope,
) {
  return switch (scope) {
    AllCategoryScope() => [
      for (final item in items)
        if (Accounting.mainBucketID(item.bucketID, state) == main) item,
    ],
    DirectCategoryScope() => [
      for (final item in items)
        if (normalizedOptionalID(item.bucketID) == main) item,
    ],
    SubCategoryScope(:final subID) => _subscopedItems(
      items,
      state,
      main,
      subID,
    ),
  };
}

List<AnalysisItem> _subscopedItems(
  Iterable<AnalysisItem> items,
  LedgerState state,
  String? main,
  String subID,
) {
  final child = state.categories[subID];
  if (main == null || child == null || child.parentID != main) {
    throw ArgumentError.value(
      subID,
      'scope',
      'Not a subcategory of the main bucket.',
    );
  }
  return [
    for (final item in items)
      if (normalizedOptionalID(item.bucketID) == subID) item,
  ];
}
