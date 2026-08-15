import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/analysis_scan.dart';
import 'package:spendwise/ui/stats/category_scope.dart';
import 'package:spendwise/ui/stats/trend.dart';
import 'package:spendwise/ui/transactions/day_header.dart';
import 'package:spendwise/ui/transactions/day_sections.dart';
import 'package:spendwise/ui/transactions/delete_confirmation.dart';
import 'package:spendwise/ui/transactions/entry_form.dart';
import 'package:spendwise/ui/transactions/transaction_cell.dart';
import 'package:spendwise/ui/transactions/transaction_row.dart';

const _directSymbol = 'radio_button_checked';

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

DateRange _monthWindow(DateTime month) {
  final start = DateTime.utc(month.year, month.month);
  final end = shiftMonthThenClampDayUtc(start, 1, day: 1);
  return DateRange(start, end);
}

DateRange _yearWindow(DateTime year) {
  final start = DateTime.utc(year.year);
  final end = DateTime.utc(year.year + 1);
  return DateRange(start, end);
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
        ? _yearWindow(_detailDate)
        : _monthWindow(_detailDate);

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

    final windowed = scanned.where((item) => window.contains(item.date));

    // The category's own total combines everything logged on it and its
    // children, so "direct" spend is what's left after the children's share.
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
    final directTotal = mainTotal - childSum;

    final scopedBuckets = matchingCategoryIDs(widget.mainID, _scope, state);
    final scopeTotal = windowed
        .where((item) => scopedBuckets.contains(item.bucketID))
        .fold(Decimal.zero, (sum, item) => sum + item.amount);

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _scopeCaption(title, _scope, state),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatCurrency(scopeTotal),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: scopeColor,
                    ),
                  ),
                ],
              ),
            ),
            if (children.isNotEmpty)
              _SubcategoryTable(
                mainCategory: mainCategory,
                mainTotal: mainTotal,
                children: children,
                childTotals: childTotals,
                directTotal: directTotal,
                scope: _scope,
                onSelectScope: _setScope,
              ),
            _TrendCard(
              scope: _scope,
              mainCategory: mainCategory,
              state: state,
              detailDate: _detailDate,
              isYearRange: widget.isYearRange,
              scopedBuckets: scopedBuckets,
              scanForTrend: (buckets) => _scan.scan(
                items: widget.cache.items,
                itemsRevision: widget.cache.itemsRevision,
                kind: widget.kind,
                buckets: buckets,
              ),
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
            _ScopedEntryList(
              ledger: widget.ledger,
              state: state,
              window: window,
              scopedBuckets: scopedBuckets,
            ),
          ],
        ),
      ),
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
      final subName = subID == null
          ? 'Uncategorized'
          : (state.categories[subID]?.name ?? 'Uncategorized');
      return '$mainName › $subName';
  }
}

String _scopeShortName(
  String mainName,
  CategoryScope scope,
  LedgerState state,
) {
  switch (scope) {
    case AllScope():
    case DirectScope():
      return mainName;
    case SubScope(:final subID):
      return subID == null
          ? 'Uncategorized'
          : (state.categories[subID]?.name ?? 'Uncategorized');
  }
}

class _SubcategoryRowData {
  const _SubcategoryRowData({
    required this.scope,
    required this.name,
    required this.symbolName,
    required this.color,
    required this.amount,
  });

  final CategoryScope scope;
  final String name;
  final String symbolName;
  final Color color;
  final Decimal amount;
}

class _SubcategoryTable extends StatelessWidget {
  const _SubcategoryTable({
    required this.mainCategory,
    required this.mainTotal,
    required this.children,
    required this.childTotals,
    required this.directTotal,
    required this.scope,
    required this.onSelectScope,
  });

  final TransactionCategory? mainCategory;
  final Decimal mainTotal;
  final List<TransactionCategory> children;
  final Map<String, Decimal> childTotals;
  final Decimal directTotal;
  final CategoryScope scope;
  final void Function(CategoryScope scope) onSelectScope;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final category in children)
        _SubcategoryRowData(
          scope: SubScope(category.id),
          name: category.name,
          symbolName: category.symbol,
          color: parseColorHex(category.colorHex),
          amount: childTotals[category.id] ?? Decimal.zero,
        ),
      if (directTotal > Decimal.zero)
        _SubcategoryRowData(
          scope: const DirectScope(),
          name: 'Direct',
          symbolName: _directSymbol,
          color: mainCategory == null
              ? colorHexFallback
              : parseColorHex(mainCategory!.colorHex),
          amount: directTotal,
        ),
    ];
    rows.sort((a, b) => b.amount.compareTo(a.amount));

    return Column(
      children: [
        const Divider(height: 1),
        _SubcategoryRow(
          name: 'All ${mainCategory?.name ?? ''}',
          symbolName: mainCategory?.symbol ?? 'help_outline',
          color: mainCategory == null
              ? colorHexFallback
              : parseColorHex(mainCategory!.colorHex),
          amount: mainTotal,
          fraction: Decimal.one,
          selected: scope is AllScope,
          onTap: () => onSelectScope(const AllScope()),
        ),
        for (final row in rows)
          _SubcategoryRow(
            name: row.name,
            symbolName: row.symbolName,
            color: row.color,
            amount: row.amount,
            fraction: mainTotal == Decimal.zero
                ? Decimal.zero
                : (row.amount / mainTotal).toDecimal(
                    scaleOnInfinitePrecision: 4,
                  ),
            selected: row.scope == scope,
            onTap: () => onSelectScope(row.scope),
          ),
      ],
    );
  }
}

class _SubcategoryRow extends StatelessWidget {
  const _SubcategoryRow({
    required this.name,
    required this.symbolName,
    required this.color,
    required this.amount,
    required this.fraction,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String symbolName;
  final Color color;
  final Decimal amount;
  final Decimal fraction;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              CategoryIcon(symbolName: symbolName, color: color, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Text(
                formatPercent(fraction.toDouble()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatCurrency(amount),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendCard extends StatefulWidget {
  const _TrendCard({
    required this.scope,
    required this.mainCategory,
    required this.state,
    required this.detailDate,
    required this.isYearRange,
    required this.scopedBuckets,
    required this.scanForTrend,
    required this.color,
  });

  final CategoryScope scope;
  final TransactionCategory? mainCategory;
  final LedgerState state;
  final DateTime detailDate;
  final bool isYearRange;
  final Set<String?> scopedBuckets;
  final List<AnalysisItem> Function(Set<String?> buckets) scanForTrend;
  final Color color;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _TrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope ||
        oldWidget.detailDate != widget.detailDate ||
        oldWidget.isYearRange != widget.isYearRange) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = trendMonths(
      widget.detailDate,
      isYearRange: widget.isYearRange,
    );
    final items = widget.scanForTrend(widget.scopedBuckets);
    final amounts = [for (final month in months) monthTotal(items, month)];

    final mainName = widget.mainCategory?.name ?? '';
    final titleName = _scopeShortName(mainName, widget.scope, widget.state);

    final maxAmount = amounts.fold(
      Decimal.zero,
      (max, amount) => amount > max ? amount : max,
    );
    final maxY = maxAmount > Decimal.one ? maxAmount.toDouble() : 1.0;

    final selected = _selectedIndex;
    final hint = widget.isYearRange ? 'this year' : 'last 6 months';
    final headerRight = selected == null
        ? hint
        : '${formatMonthLabel(months[selected])} · ${formatCurrency(amounts[selected])}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$titleName trend', style: theme.textTheme.titleSmall),
                  Text(
                    headerRight,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                key: const ValueKey('categoryDetailTrendChart'),
                height: 160,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.round();
                            if (index < 0 || index >= months.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                formatMonthLabel(months[index]).substring(0, 3),
                                style: theme.textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      // Selection is nearest-month by horizontal position, not
                      // proximity to the line itself, so the threshold has to
                      // clear the chart's full height.
                      touchSpotThreshold: double.infinity,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => Colors.transparent,
                        getTooltipItems: (spots) => [
                          for (final _ in spots) null,
                        ],
                      ),
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.lineBarSpots == null ||
                            response.lineBarSpots!.isEmpty) {
                          if (event is FlPointerExitEvent) {
                            setState(() => _selectedIndex = null);
                          }
                          return;
                        }
                        setState(() {
                          _selectedIndex = response.lineBarSpots!.first.x
                              .round();
                        });
                      },
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < amounts.length; i++)
                            FlSpot(i.toDouble(), amounts[i].toDouble()),
                        ],
                        isCurved: true,
                        color: widget.color,
                        barWidth: 2,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopedEntryList extends StatelessWidget {
  const _ScopedEntryList({
    required this.ledger,
    required this.state,
    required this.window,
    required this.scopedBuckets,
  });

  final Ledger ledger;
  final LedgerState state;
  final DateRange window;
  final Set<String?> scopedBuckets;

  @override
  Widget build(BuildContext context) {
    final matching = state.entries.values.where(
      (entry) => !entry.isTransfer && scopedBuckets.contains(entry.categoryID),
    );

    final sections = daySections(matching, state, interval: window);

    if (sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No entries in this period')),
      );
    }

    return Column(
      children: [
        for (final section in sections) ...[
          DayHeader(day: section.date, net: section.income - section.expenses),
          for (final row in section.rows)
            _EntryRow(row: row, ledger: ledger, state: state),
        ],
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.row,
    required this.ledger,
    required this.state,
  });

  final TransactionRow row;
  final Ledger ledger;
  final LedgerState state;

  @override
  Widget build(BuildContext context) {
    final entry = state.entries[row.id];
    if (entry == null) return const SizedBox.shrink();

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) =>
          showDeleteConfirmation(context, note: row.note, title: row.title),
      onDismissed: (_) => ledger.deleteEntry(entry.id),
      child: TransactionCell(
        row: row,
        onTap: () =>
            showEntryFormSheet(context: context, ledger: ledger, entry: entry),
      ),
    );
  }
}
