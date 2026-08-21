import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/category_scope.dart';
import 'package:spendwise/ui/stats/chart_helpers.dart';
import 'package:spendwise/ui/stats/trend.dart';

String? _resolvedSubName(String? subID, LedgerState state) {
  if (subID == null) return null;
  return state.categories[subID]?.name;
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
      return _resolvedSubName(subID, state) ?? 'Uncategorized';
  }
}

class TrendCard extends StatefulWidget {
  const TrendCard({
    super.key,
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
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant TrendCard oldWidget) {
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
                child: _buildTrendLineChart(theme, months, amounts, maxY),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTrendTouch(FlTouchEvent event, LineTouchResponse? response) {
    final spots = response?.lineBarSpots;
    if (!event.isInterestedForInteractions || spots == null || spots.isEmpty) {
      if (event is FlPointerExitEvent) setState(() => _selectedIndex = null);
      return;
    }
    setState(() => _selectedIndex = spots.first.x.round());
  }

  LineChart _buildTrendLineChart(
    ThemeData theme,
    List<DateTime> months,
    List<Decimal> amounts,
    double maxY,
  ) {
    final bottomTitles = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 1,
        getTitlesWidget: (value, meta) =>
            monthAxisTick(theme.textTheme.labelSmall, months, value),
      ),
    );

    final lineTouchData = LineTouchData(
      // Selection is nearest-month by horizontal position, not proximity
      // to the line itself, so the threshold has to clear the chart's
      // full height.
      touchSpotThreshold: double.infinity,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => Colors.transparent,
        getTooltipItems: (spots) => [for (final _ in spots) null],
      ),
      touchCallback: _onTrendTouch,
    );

    final lineBarsData = [
      LineChartBarData(
        spots: [
          for (var i = 0; i < amounts.length; i++)
            FlSpot(i.toDouble(), amounts[i].toDouble()),
        ],
        isCurved: true,
        preventCurveOverShooting: true,
        color: widget.color,
        barWidth: 2,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      ),
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: bottomTitles,
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: lineTouchData,
        lineBarsData: lineBarsData,
      ),
    );
  }
}
