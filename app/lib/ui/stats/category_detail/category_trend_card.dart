import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/helpers/chart_helpers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

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
      return resolvedSubName(subID, state) ?? 'Uncategorized';
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
    required this.months,
    required this.amounts,
    required this.color,
  });

  final CategoryScope scope;
  final TransactionCategory? mainCategory;
  final LedgerState state;
  final DateTime detailDate;
  final bool isYearRange;
  final List<DateTime> months;
  final List<Decimal> amounts;
  final Color color;

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  int? _selectedIndex;

  static const _chartHeight = 160.0;
  static const _cardPadding = EdgeInsets.fromLTRB(16, 16, 16, 0);
  static const _cardInnerPadding = EdgeInsets.all(16);
  static const _chartGap = 12.0;
  static const _emptyChartMaxY = 1.0;

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
    final months = widget.months;
    final amounts = widget.amounts;

    final mainName = widget.mainCategory?.name ?? '';
    final titleName = _scopeShortName(mainName, widget.scope, widget.state);

    final maxAmount = amounts.fold(
      Decimal.zero,
      (max, amount) => amount > max ? amount : max,
    );
    final maxY = maxAmount > Decimal.one
        ? maxAmount.toDouble()
        : _emptyChartMaxY;

    final selected = _selectedIndex;
    final hint = widget.isYearRange ? 'this year' : 'last 6 months';
    final headerRight = selected == null
        ? hint
        : '${formatMonthLabel(months[selected])} · ${formatMoney(amounts[selected])}';
    final header = Row(
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
    );
    final chart = SizedBox(
      key: const ValueKey('categoryDetailTrendChart'),
      height: _chartHeight,
      child: _TrendLineChart(
        months: months,
        amounts: amounts,
        maxY: maxY,
        lineColor: widget.color,
        selectedMark: context.colors.selectedMark,
        selected: selected,
        onTouch: _onTrendTouch,
      ),
    );

    return Padding(
      padding: _cardPadding,
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: _cardInnerPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: _chartGap),
              chart,
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
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({
    required this.months,
    required this.amounts,
    required this.maxY,
    required this.lineColor,
    required this.selectedMark,
    required this.selected,
    required this.onTouch,
  });

  final List<DateTime> months;
  final List<Decimal> amounts;
  final double maxY;
  final Color lineColor;
  final Color selectedMark;
  final int? selected;
  final void Function(FlTouchEvent, LineTouchResponse?) onTouch;

  static const _axisTickInterval = 1.0;
  static const _transparent = Color(0x00000000);
  static const _lineWidth = 2.0;
  static const _selectedDotRadius = 5.0;
  static const _dotRadius = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomTitles = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: _axisTickInterval,
        getTitlesWidget: (value, meta) =>
            monthAxisTick(theme.textTheme.labelSmall, months, value),
      ),
    );

    final lineTouchData = LineTouchData(
      touchSpotThreshold: double.infinity,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => _transparent,
        getTooltipItems: (spots) => [for (final _ in spots) null],
      ),
      getTouchedSpotIndicator: (bar, indicators) => [
        for (final _ in indicators)
          TouchedSpotIndicatorData(
            FlLine(color: _transparent),
            FlDotData(
              getDotPainter: (spot, percent, touchedBar, touchedIndex) =>
                  FlDotCirclePainter(
                    radius: _selectedDotRadius,
                    color: selectedMark,
                    strokeWidth: 0,
                  ),
            ),
          ),
      ],
      touchCallback: onTouch,
    );

    final lineBarsData = [
      LineChartBarData(
        spots: [
          for (var i = 0; i < amounts.length; i++)
            FlSpot(i.toDouble(), amounts[i].toDouble()),
        ],
        isCurved: true,
        preventCurveOverShooting: true,
        color: lineColor,
        barWidth: _lineWidth,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: index == selected ? _selectedDotRadius : _dotRadius,
            color: index == selected ? selectedMark : lineColor,
            strokeWidth: 0,
          ),
        ),
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
