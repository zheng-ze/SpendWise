import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:spendwise/ledger/analysis/breakdowns/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/insights/completeness.dart';

DateRange categoryDetailWindow(DateTime period, AnalysisPeriodMode mode) {
  return switch (mode) {
    AnalysisPeriodMode.month => monthWindow(period),
    AnalysisPeriodMode.year => DateRange(
      DateTime.utc(period.year),
      DateTime.utc(period.year + 1),
    ),
  };
}

@immutable
class CategoryDetailScope {
  factory CategoryDetailScope({
    required LedgerState state,
    required String mainID,
    required AnalysisCategoryScope scope,
  }) {
    final main = normalizedID(mainID);
    final children = state.categories.values
        .where((child) => child.parentID == main)
        .toList();
    final effectiveScope = switch (scope) {
      SubCategoryScope(:final subID)
          when !children.any((child) => child.id == subID) =>
        const AllCategoryScope(),
      _ => scope,
    };
    final buckets = switch (effectiveScope) {
      AllCategoryScope() => {main, ...children.map((child) => child.id)},
      DirectCategoryScope() => {main},
      SubCategoryScope(:final subID) => {subID},
    };
    return CategoryDetailScope._(main, children, effectiveScope, buckets);
  }

  CategoryDetailScope._(
    this.mainID,
    Iterable<TransactionCategory> children,
    this.scope,
    Set<String> buckets,
  ) : children = List.unmodifiable(children),
      buckets = Set.unmodifiable(buckets);

  final String mainID;
  final List<TransactionCategory> children;
  final AnalysisCategoryScope scope;
  final Set<String> buckets;

  String get identity => switch (scope) {
    AllCategoryScope() => '$mainID|all',
    DirectCategoryScope() => '$mainID|direct',
    SubCategoryScope(:final subID) => '$mainID|sub:$subID',
  };

  List<AnalysisItem> filter(Iterable<AnalysisItem> items, CategoryKind kind) {
    return items.where((item) => matches(item, kind)).toList();
  }

  bool matches(AnalysisItem item, CategoryKind kind) {
    return item.kind == kind && buckets.contains(item.bucketID);
  }

  List<String> entryIDs(
    LedgerState state,
    CategoryKind kind,
    DateRange window,
  ) {
    final sources = state.moneySources.keys.toSet();
    final entries = state.entries.values.toList().reversed;
    final eligible = entries.where((entry) {
      if (entry.kind == EntryKind.transfer || !window.contains(entry.date)) {
        return false;
      }
      return Accounting.classify(
        entry,
        sources,
        state,
      ).any((item) => matches(item, kind));
    }).toList();
    final indexed = eligible.indexed.toList();
    indexed.sort((a, b) {
      final byDate = b.$2.date.compareTo(a.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
    return List.unmodifiable(indexed.map((item) => item.$2.id));
  }
}
