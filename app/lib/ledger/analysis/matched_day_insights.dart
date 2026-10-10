import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/compared_with_usual.dart';
import 'package:spendwise/ledger/analysis/completeness.dart';
import 'package:spendwise/ledger/analysis/insight_rules.dart';

@immutable
class CategoryChange {
  CategoryChange({
    required this.bucketID,
    required this.observedTotal,
    required this.observedExpenseCount,
    required List<BaselineEvidence> baselineEvidence,
    required this.baselineTotal,
    required this.baselineExpenseCount,
    required this.usualMean,
    required this.difference,
    required this.relativeChangePercent,
  }) : baselineEvidence = List.unmodifiable(baselineEvidence);

  final String? bucketID;

  final Decimal observedTotal;

  final int observedExpenseCount;

  final List<BaselineEvidence> baselineEvidence;

  final Decimal baselineTotal;

  final int baselineExpenseCount;

  final Decimal usualMean;

  final Decimal difference;

  final Decimal? relativeChangePercent;

  @override
  bool operator ==(Object other) {
    return other is CategoryChange &&
        other.bucketID == bucketID &&
        other.observedTotal == observedTotal &&
        other.observedExpenseCount == observedExpenseCount &&
        listEquals(other.baselineEvidence, baselineEvidence) &&
        other.baselineTotal == baselineTotal &&
        other.baselineExpenseCount == baselineExpenseCount &&
        other.usualMean == usualMean &&
        other.difference == difference &&
        other.relativeChangePercent == relativeChangePercent;
  }

  @override
  int get hashCode => Object.hash(
    bucketID,
    observedTotal,
    observedExpenseCount,
    Object.hashAll(baselineEvidence),
    baselineTotal,
    baselineExpenseCount,
    usualMean,
    difference,
    relativeChangePercent,
  );
}

@immutable
class MatchedDayInsights {
  MatchedDayInsights({
    required this.today,
    required this.selectedMonth,
    required this.firstRecordMonth,
    required this.observedWindow,
    required this.elapsedDayCount,
    required this.state,
    required List<DateRange> baselineWindows,
    required List<CategoryChange> changes,
  }) : baselineWindows = List.unmodifiable(baselineWindows),
       changes = List.unmodifiable(changes);

  final DateTime today;

  final DateTime selectedMonth;

  final DateTime? firstRecordMonth;

  final DateRange observedWindow;

  final int elapsedDayCount;

  final InsightState state;

  final List<DateRange> baselineWindows;

  final List<CategoryChange> changes;

  @override
  bool operator ==(Object other) {
    return other is MatchedDayInsights &&
        other.today == today &&
        other.selectedMonth == selectedMonth &&
        other.firstRecordMonth == firstRecordMonth &&
        other.observedWindow == observedWindow &&
        other.elapsedDayCount == elapsedDayCount &&
        other.state == state &&
        listEquals(other.baselineWindows, baselineWindows) &&
        listEquals(other.changes, changes);
  }

  @override
  int get hashCode => Object.hash(
    today,
    selectedMonth,
    firstRecordMonth,
    observedWindow,
    elapsedDayCount,
    state,
    Object.hashAll(baselineWindows),
    Object.hashAll(changes),
  );
}

typedef _BucketTotal = ({Decimal total, int count});

MatchedDayInsights matchedDayInsights({
  required Iterable<AnalysisItem> items,
  required LedgerState state,
  required DateTime? firstRecordMonth,
  required DateTime today,
  required InsightRules rules,
}) {
  final day = startOfDayUtc(today);
  final month = monthWindow(day).start;
  final observedWindow = DateRange(month, day.add(const Duration(days: 1)));
  MatchedDayInsights result(
    InsightState resultState, [
    List<DateRange> baselines = const [],
    List<CategoryChange> changes = const [],
  ]) => MatchedDayInsights(
    today: day,
    selectedMonth: month,
    firstRecordMonth: firstRecordMonth,
    observedWindow: observedWindow,
    elapsedDayCount: day.day,
    state: resultState,
    baselineWindows: baselines,
    changes: changes,
  );
  final baselines = previousCompleteMonthWindows(
    selectedMonth: month,
    elapsedDayCount: day.day,
    firstRecordMonth: firstRecordMonth,
    today: day,
  );
  if (baselines == null) return result(InsightState.historyNeeded);

  final expenses = items
      .where((item) => item.kind == CategoryKind.expense)
      .toList();
  _BucketTotals bucketTotals(DateRange window) {
    final inWindow = expenses
        .where((item) => window.contains(item.date))
        .toList();
    final counts = <String?, int>{};
    for (final item in inWindow) {
      final bucketID = Accounting.mainBucketID(item.bucketID, state);
      counts[bucketID] = (counts[bucketID] ?? 0) + 1;
    }
    return {
      for (final entry in Accounting.rollUp(inWindow, state).entries)
        entry.key: (total: entry.value, count: counts[entry.key] ?? 0),
    };
  }

  final observed = bucketTotals(observedWindow);
  final baselineTotals = [for (final window in baselines) bucketTotals(window)];
  final bucketIDs = {
    ...observed.keys,
    for (final totals in baselineTotals) ...totals.keys,
  };
  final changes = <CategoryChange>[];
  for (final bucketID in bucketIDs) {
    final evidence = <BaselineEvidence>[
      for (var i = 0; i < baselines.length; i++)
        (
          window: baselines[i],
          total: baselineTotals[i][bucketID]?.total ?? Decimal.zero,
          expenseItemCount: baselineTotals[i][bucketID]?.count ?? 0,
        ),
    ];
    final baselineTotal = evidence.fold(
      Decimal.zero,
      (sum, record) => sum + record.total,
    );
    final baselineCount = evidence.fold(
      0,
      (sum, record) => sum + record.expenseItemCount,
    );
    final observedTotal = observed[bucketID]?.total ?? Decimal.zero;
    if (!rules.qualifies(observedTotal, baselineTotal, baselineCount)) {
      continue;
    }
    final comparison = compareToBaseline(observedTotal, baselineTotal);
    changes.add(
      CategoryChange(
        bucketID: bucketID,
        observedTotal: observedTotal,
        observedExpenseCount: observed[bucketID]?.count ?? 0,
        baselineEvidence: evidence,
        baselineTotal: baselineTotal,
        baselineExpenseCount: baselineCount,
        usualMean: comparison.usualMean,
        difference: comparison.difference,
        relativeChangePercent: comparison.relativeChangePercent,
      ),
    );
  }
  changes.sort((a, b) {
    final byChange = _absoluteChange(b).compareTo(_absoluteChange(a));
    if (byChange != 0) return byChange;
    final aID = a.bucketID;
    final bID = b.bucketID;
    if (aID == null || bID == null) return aID == null ? 1 : -1;
    return aID.compareTo(bID);
  });
  return result(
    InsightState.available,
    baselines,
    changes.take(rules.maximumCategoryChanges).toList(),
  );
}

typedef _BucketTotals = Map<String?, _BucketTotal>;

Decimal _absoluteChange(CategoryChange change) =>
    scaledChange(change.observedTotal, change.baselineTotal).abs();
