import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/stats/analysis/analysis_scan.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/category_detail/category_totals.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';
import 'package:spendwise/ui/stats/helpers/trend.dart';

// MARK: - CategoryDetailArgs
@immutable
class CategoryDetailArgs {
  const CategoryDetailArgs({
    required this.mainID,
    required this.kind,
    required this.isYearRange,
    required this.initialDate,
  });

  final String mainID;
  final CategoryKind kind;
  final bool isYearRange;
  final DateTime initialDate;

  @override
  bool operator ==(Object other) =>
      other is CategoryDetailArgs &&
      other.mainID == mainID &&
      other.kind == kind &&
      other.isYearRange == isYearRange &&
      other.initialDate == initialDate;

  @override
  int get hashCode => Object.hash(mainID, kind, isYearRange, initialDate);
}

// MARK: - CategoryDetailViewState
class CategoryDetailViewState {
  const CategoryDetailViewState({
    required this.detailDate,
    required this.scope,
    required this.kind,
    required this.mainCategory,
    required this.ledgerState,
    required this.children,
    required this.totals,
    required this.trendMonths,
    required this.trendAmounts,
    required this.isYearRange,
    required this.window,
    required this.scopedBuckets,
  });

  final DateTime detailDate;
  final CategoryScope scope;
  final CategoryKind kind;
  final TransactionCategory? mainCategory;
  final LedgerState ledgerState;
  final List<TransactionCategory> children;
  final CategoryTotals totals;
  final List<DateTime> trendMonths;
  final List<Decimal> trendAmounts;
  final bool isYearRange;
  final DateRange window;
  final Set<String?> scopedBuckets;
}

// MARK: - CategoryDetailViewModel
abstract class CategoryDetailViewModel {
  void setDate(DateTime date);
  void setScope(CategoryScope scope);
}

// MARK: - CategoryDetailNotifier
class CategoryDetailNotifier extends AsyncNotifier<CategoryDetailViewState>
    with LedgerBackedNotifier<CategoryDetailViewState>
    implements CategoryDetailViewModel {
  CategoryDetailNotifier(this._args);

  final CategoryDetailArgs _args;

  final AnalysisScan _scan = AnalysisScan();

  late DateTime _detailDate;
  late CategoryScope _scope;

  late Ledger _ledger;
  late AnalysisCache _cache;

  @override
  Future<CategoryDetailViewState> build() async {
    final currentLedger = ledger;
    final cache = analysisCache;
    _ledger = currentLedger;
    _cache = cache;
    currentLedger.addListener(_onChanged);
    cache.addListener(_onChanged);
    ref.onDispose(() => currentLedger.removeListener(_onChanged));
    ref.onDispose(() => cache.removeListener(_onChanged));

    _detailDate = _args.isYearRange
        ? DateTime.utc(_args.initialDate.year)
        : DateTime.utc(_args.initialDate.year, _args.initialDate.month);
    _scope = const AllScope();

    await cache.refresh(currentLedger.state);
    if (!_isCurrentSession(currentLedger, cache)) {
      throw StateError('Category detail session ended during build.');
    }

    return _buildState(detailDate: _detailDate, scope: _scope);
  }

  bool _isCurrentSession(Ledger builtLedger, AnalysisCache builtCache) =>
      ref.mounted &&
      identical(_ledger, builtLedger) &&
      identical(_cache, builtCache);

  void _onChanged() {
    if (!ref.mounted) return;
    unawaited(_cache.refresh(_ledger.state));
    state = AsyncData(_buildState(detailDate: _detailDate, scope: _scope));
  }

  CategoryDetailViewState _buildState({
    required DateTime detailDate,
    required CategoryScope scope,
  }) {
    final ledgerState = _ledger.state;
    final mainCategory = ledgerState.categories[_args.mainID];

    final children = [
      for (final category in ledgerState.categories.values)
        if (category.parentID == _args.mainID) category,
    ];

    final wholeCategoryBuckets = {
      _args.mainID,
      for (final category in children) category.id,
    };

    final scanned = _scan.scan(
      source: _cache,
      items: _cache.items,
      itemsRevision: _cache.itemsRevision,
      kind: _args.kind,
      buckets: wholeCategoryBuckets,
    );

    final scopedBuckets = matchingCategoryIDs(_args.mainID, scope, ledgerState);

    final window = _args.isYearRange
        ? yearWindow(detailDate)
        : monthWindow(detailDate);

    final totals = CategoryTotals.compute(
      scanned: scanned,
      children: children,
      window: window,
      scopedBuckets: scopedBuckets,
    );

    final trendItems = scanned
        .where((item) => scopedBuckets.contains(item.bucketID))
        .toList();
    final months = trendMonths(detailDate, isYearRange: _args.isYearRange);
    final amounts = [for (final month in months) monthTotal(trendItems, month)];

    return CategoryDetailViewState(
      detailDate: detailDate,
      scope: scope,
      kind: _args.kind,
      mainCategory: mainCategory,
      ledgerState: ledgerState,
      children: children,
      totals: totals,
      trendMonths: months,
      trendAmounts: amounts,
      isYearRange: _args.isYearRange,
      window: window,
      scopedBuckets: scopedBuckets,
    );
  }

  @override
  void setDate(DateTime date) {
    _detailDate = date;
    updateState((s) => _buildState(detailDate: date, scope: s.scope));
  }

  @override
  void setScope(CategoryScope scope) {
    _scope = scope;
    updateState((s) => _buildState(detailDate: s.detailDate, scope: scope));
  }
}

// MARK: - Constants
final categoryDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<
      CategoryDetailNotifier,
      CategoryDetailViewState,
      CategoryDetailArgs
    >(CategoryDetailNotifier.new);
