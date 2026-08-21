import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/stats/analysis_scan.dart';
import 'package:spendwise/ui/stats/category_scope.dart';
import 'package:spendwise/ui/stats/category_trend_card.dart';
import 'package:spendwise/ui/stats/stats_window.dart';
import 'package:spendwise/ui/stats/subcategory_table.dart';
import 'package:spendwise/ui/stats/trend.dart';
import 'package:spendwise/ui/transactions/day_sectioned_entry_list.dart';

class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({
    super.key,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final cache = ref.watch(analysisCacheProvider);
    if (ledger == null) return const SizedBox.shrink();

    cache.refresh(ledger.state);

    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) => ListenableBuilder(
        listenable: cache,
        builder: (context, _) => _CategoryDetailBody(
          mainID: mainID,
          kind: kind,
          isYearRange: isYearRange,
          initialDate: initialDate,
          ledger: ledger,
          cache: cache,
        ),
      ),
    );
  }
}

class _CategoryDetailBody extends StatefulWidget {
  const _CategoryDetailBody({
    required this.mainID,
    required this.kind,
    required this.isYearRange,
    required this.initialDate,
    required this.ledger,
    required this.cache,
  });

  final String mainID;
  final CategoryKind kind;
  final bool isYearRange;
  final DateTime initialDate;
  final Ledger ledger;
  final AnalysisCache cache;

  @override
  State<_CategoryDetailBody> createState() => _CategoryDetailBodyState();
}

class _CategoryDetailBodyState extends State<_CategoryDetailBody> {
  late DateTime _detailDate = widget.isYearRange
      ? DateTime.utc(widget.initialDate.year)
      : DateTime.utc(widget.initialDate.year, widget.initialDate.month);

  CategoryScope _scope = const AllScope();

  final AnalysisScan _scan = AnalysisScan();

  void _setDate(DateTime value) => setState(() => _detailDate = value);

  void _setScope(CategoryScope scope) => setState(() => _scope = scope);

  @override
  Widget build(BuildContext context) {
    final state = widget.ledger.state;
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    final mainCategory = state.categories[widget.mainID];
    final title = mainCategory?.name ?? '';

    final window = widget.isYearRange
        ? yearWindow(_detailDate)
        : monthWindow(_detailDate);

    final children = [
      for (final category in state.categories.values)
        if (category.parentID == widget.mainID) category,
    ];

    final wholeCategoryBuckets = {
      widget.mainID,
      for (final category in children) category.id,
    };

    final scanned = _scan.scan(
      items: widget.cache.items,
      itemsRevision: widget.cache.itemsRevision,
      kind: widget.kind,
      buckets: wholeCategoryBuckets,
    );

    final scopedBuckets = matchingCategoryIDs(widget.mainID, _scope, state);

    final totals = _CategoryTotals.compute(
      scanned: scanned,
      children: children,
      window: window,
      scopedBuckets: scopedBuckets,
    );

    final trendItems = scanned
        .where((item) => scopedBuckets.contains(item.bucketID))
        .toList();
    final trendMonthsList = trendMonths(
      _detailDate,
      isYearRange: widget.isYearRange,
    );
    final trendAmounts = [
      for (final month in trendMonthsList) monthTotal(trendItems, month),
    ];

    final step = widget.isYearRange ? MonthYearStep.year : MonthYearStep.month;

    final scopeColor = widget.kind == CategoryKind.income
        ? colors.gain
        : colors.loss;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          MonthYearSelector(
            value: _detailDate,
            step: step,
            onChanged: _setDate,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AmountHeader(
                caption: _scopeCaption(title, _scope, state),
                amount: totals.scopeTotal,
                amountColor: scopeColor,
              ),
            ),
            if (children.isNotEmpty)
              SubcategoryTable(
                mainCategory: mainCategory,
                mainTotal: totals.mainTotal,
                children: children,
                childTotals: totals.childTotals,
                directTotal: totals.directTotal,
                scope: _scope,
                onSelectScope: _setScope,
              ),
            TrendCard(
              scope: _scope,
              mainCategory: mainCategory,
              state: state,
              detailDate: _detailDate,
              isYearRange: widget.isYearRange,
              months: trendMonthsList,
              amounts: trendAmounts,
              color: scopeColor,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'ENTRIES',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            DaySectionedEntryList(
              ledger: widget.ledger,
              state: state,
              window: window,
              matching: () => state.entries.values.where(
                (entry) =>
                    !entry.isTransfer &&
                    scopedBuckets.contains(entry.categoryID) &&
                    Accounting.includedInAnalysis(entry, state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTotals {
  const _CategoryTotals({
    required this.mainTotal,
    required this.childTotals,
    required this.directTotal,
    required this.scopeTotal,
  });

  final Decimal mainTotal;
  final Map<String, Decimal> childTotals;
  final Decimal directTotal;
  final Decimal scopeTotal;

  factory _CategoryTotals.compute({
    required Iterable<AnalysisItem> scanned,
    required List<TransactionCategory> children,
    required DateRange window,
    required Set<String?> scopedBuckets,
  }) {
    final windowed = scanned.where((item) => window.contains(item.date));

    final mainTotal = windowed.fold(
      Decimal.zero,
      (sum, item) => sum + item.amount,
    );
    final childTotals = {
      for (final category in children)
        category.id: _sumBucket(windowed, category.id),
    };
    final childSum = childTotals.values.fold(
      Decimal.zero,
      (sum, amount) => sum + amount,
    );
    // The category's own total combines everything logged on it and its
    // children, so direct spend is what's left after the children's share.
    final directTotal = mainTotal - childSum;

    final scopeTotal = windowed
        .where((item) => scopedBuckets.contains(item.bucketID))
        .fold(Decimal.zero, (sum, item) => sum + item.amount);

    return _CategoryTotals(
      mainTotal: mainTotal,
      childTotals: childTotals,
      directTotal: directTotal,
      scopeTotal: scopeTotal,
    );
  }
}

Decimal _sumBucket(Iterable<AnalysisItem> items, String bucketID) {
  return items
      .where((item) => item.bucketID == bucketID)
      .fold(Decimal.zero, (sum, item) => sum + item.amount);
}

String _scopeCaption(String mainName, CategoryScope scope, LedgerState state) {
  switch (scope) {
    case AllScope():
      return mainName;
    case DirectScope():
      return '$mainName › Direct';
    case SubScope(:final subID):
      final subName = resolvedSubName(subID, state) ?? 'Uncategorized';
      return '$mainName › $subName';
  }
}
