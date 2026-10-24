import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:spendwise/ledger/analysis/breakdowns/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/category_detail/category_detail_scope.dart';
import 'package:spendwise/ledger/analysis/category_detail/category_totals.dart';
import 'package:spendwise/ledger/analysis/summaries/month_spread.dart';
import 'package:spendwise/ledger/analysis/summaries/year_spread.dart';

@immutable
class CategoryDetailPeriod {
  CategoryDetailPeriod({
    required this.mainID,
    required this.mainCategory,
    required this.kind,
    required this.mode,
    required this.scope,
    required this.window,
    required Iterable<TransactionCategory> children,
    required this.totals,
    required Iterable<String> entryIDs,
    required this.firstRecord,
  }) : children = List.unmodifiable(children),
       entryIDs = List.unmodifiable(entryIDs);

  final String mainID;
  final TransactionCategory? mainCategory;
  final CategoryKind kind;
  final AnalysisPeriodMode mode;
  final AnalysisCategoryScope scope;
  final DateRange window;
  final List<TransactionCategory> children;
  final CategoryTotals totals;
  final List<String> entryIDs;
  final DateTime? firstRecord;
}

@immutable
class CategoryDetailSlot {
  const CategoryDetailSlot({
    required this.period,
    required this.window,
    required this.total,
    required this.itemCount,
  });

  final DateTime period;
  final DateRange window;
  final Decimal total;
  final int itemCount;
}

@immutable
class CategoryDetailSelection {
  CategoryDetailSelection({
    required this.window,
    required this.total,
    required Iterable<String> entryIDs,
  }) : entryIDs = List.unmodifiable(entryIDs);

  final DateRange window;
  final Decimal total;
  final List<String> entryIDs;
}

@immutable
class CategoryDetailSpread {
  CategoryDetailSpread({
    required this.mainID,
    required this.kind,
    required this.mode,
    required this.scope,
    required this.endPeriod,
    required this.today,
    required Iterable<CategoryDetailSlot> slots,
    required this.selection,
  }) : slots = List.unmodifiable(slots);

  final String mainID;
  final CategoryKind kind;
  final AnalysisPeriodMode mode;
  final AnalysisCategoryScope scope;
  final DateTime endPeriod;
  final DateTime today;
  final List<CategoryDetailSlot> slots;
  final CategoryDetailSelection? selection;
}

CategoryDetailPeriod categoryDetailPeriod({
  required LedgerState state,
  required Iterable<AnalysisItem> items,
  required String mainID,
  required CategoryKind kind,
  required AnalysisCategoryScope scope,
  required DateTime period,
  required AnalysisPeriodMode mode,
}) {
  final resolved = CategoryDetailScope(
    state: state,
    mainID: mainID,
    scope: scope,
  );
  final all = CategoryDetailScope(
    state: state,
    mainID: resolved.mainID,
    scope: const AllCategoryScope(),
  );
  final scanned = all.filter(items, kind);
  final scoped = resolved.filter(scanned, kind);
  final window = categoryDetailWindow(period, mode);
  final totals = CategoryTotals.compute(
    scanned: scanned,
    children: resolved.children,
    window: window,
    scopedBuckets: resolved.buckets,
  );
  return CategoryDetailPeriod(
    mainID: resolved.mainID,
    mainCategory: state.categories[resolved.mainID],
    kind: kind,
    mode: mode,
    scope: resolved.scope,
    window: window,
    children: resolved.children,
    totals: totals,
    entryIDs: resolved.entryIDs(state, kind, window),
    firstRecord: _firstRecord(scoped),
  );
}

CategoryDetailSpread categoryDetailSpread({
  required LedgerState state,
  required Iterable<AnalysisItem> items,
  required String mainID,
  required CategoryKind kind,
  required AnalysisCategoryScope scope,
  required DateTime endPeriod,
  required AnalysisPeriodMode mode,
  required DateTime? selectedPeriod,
  required DateTime today,
}) {
  final resolved = CategoryDetailScope(
    state: state,
    mainID: mainID,
    scope: scope,
  );
  final anchor = categoryDetailWindow(endPeriod, mode).start;
  final day = startOfDayUtc(today);
  final current = categoryDetailWindow(day, mode).start;
  if (mode == AnalysisPeriodMode.year && anchor.isAfter(current)) {
    throw ArgumentError.value(
      endPeriod,
      'endPeriod',
      'Period is in the future.',
    );
  }
  final scoped = resolved.filter(items, kind);
  final first = _firstRecord(scoped);
  final slots = _slots(scoped, anchor, mode, kind, first, day);
  final selectedWindow = selectedPeriod == null
      ? null
      : categoryDetailWindow(selectedPeriod, mode);
  final selection = selectedWindow == null
      ? null
      : CategoryDetailSelection(
          window: selectedWindow,
          total: _total(scoped, selectedWindow),
          entryIDs: resolved.entryIDs(state, kind, selectedWindow),
        );
  return CategoryDetailSpread(
    mainID: resolved.mainID,
    kind: kind,
    mode: mode,
    scope: resolved.scope,
    endPeriod: anchor,
    today: day,
    slots: slots,
    selection: selection,
  );
}

List<CategoryDetailSlot> _slots(
  List<AnalysisItem> items,
  DateTime anchor,
  AnalysisPeriodMode mode,
  CategoryKind kind,
  DateTime? first,
  DateTime today,
) {
  if (mode == AnalysisPeriodMode.month) {
    final spread = monthSpread(
      items: items,
      endMonth: anchor,
      kind: kind,
      firstRecordMonth: first,
      today: today,
    );
    return spread.slots.map((slot) {
      return CategoryDetailSlot(
        period: slot.month,
        window: slot.window,
        total: slot.total,
        itemCount: slot.itemCount,
      );
    }).toList();
  }
  final spread = yearSpread(
    items: items,
    endYear: anchor.year,
    kind: kind,
    firstRecordMonth: first,
    today: today,
  );
  return spread.slots.map((slot) {
    return CategoryDetailSlot(
      period: DateTime.utc(slot.year),
      window: slot.window,
      total: slot.total,
      itemCount: slot.itemCount,
    );
  }).toList();
}

DateTime? _firstRecord(Iterable<AnalysisItem> items) {
  DateTime? first;
  for (final item in items) {
    if (first == null || item.date.isBefore(first)) first = item.date;
  }
  return first;
}

Decimal _total(Iterable<AnalysisItem> items, DateRange window) {
  return items
      .where((item) => window.contains(item.date))
      .fold(Decimal.zero, (sum, item) => sum + item.amount);
}
