import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/stats/helpers/chart_helpers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _chartBaseline = 0.0;
const _selectedBorderWidth = 0.0;

// MARK: - Chart

class BudgetDetailChart extends StatelessWidget {
  const BudgetDetailChart({
    super.key,
    required this.months,
    required this.spend,
    required this.limit,
    required this.maxY,
    required this.selectedMonth,
    required this.onSelectMonth,
    required this.barColor,
  });

  final List<DateTime> months;
  final List<Decimal> spend;
  final Decimal limit;
  final double maxY;
  final DateTime selectedMonth;
  final void Function(DateTime month) onSelectMonth;
  final Color barColor;

  static const _chartPadding = EdgeInsets.fromLTRB(16, 0, 16, 0);

  @override
  Widget build(BuildContext context) {
    final spendBars = BudgetDetailSpendBars(
      months: months,
      spend: spend,
      maxY: maxY,
      selectedMonth: selectedMonth,
      barColor: barColor,
    );
    final limitLine = BudgetDetailLimitLine(
      months: months,
      limit: limit,
      maxY: maxY,
    );
    final tapOverlay = BudgetDetailTapOverlay(
      months: months,
      onSelectMonth: onSelectMonth,
    );

    return Padding(
      padding: _chartPadding,
      child: Stack(children: [spendBars, limitLine, tapOverlay]),
    );
  }
}

// MARK: - Spend Bars

class BudgetDetailSpendBars extends StatelessWidget {
  const BudgetDetailSpendBars({
    super.key,
    required this.months,
    required this.spend,
    required this.maxY,
    required this.selectedMonth,
    required this.barColor,
  });

  final List<DateTime> months;
  final List<Decimal> spend;
  final double maxY;
  final DateTime selectedMonth;
  final Color barColor;

  static const _titleInterval = 1.0;
  static const _unselectedBarAlpha = 0.5;
  static const _barWidth = 18.0;
  static const _barCornerRadius = 4.0;
  static const _selectedBorderColor = Color(0x00000000);

  @override
  Widget build(BuildContext context) {
    final selectedMark = context.colors.selectedMark;
    final selectedIndex = months.indexWhere(
      (month) =>
          month.year == selectedMonth.year &&
          month.month == selectedMonth.month,
    );

    final titlesData = FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: _titleInterval,
          getTitlesWidget: (value, meta) => monthAxisTick(
            Theme.of(context).textTheme.labelSmall,
            months,
            value,
          ),
        ),
      ),
    );

    final barGroups = [
      for (var i = 0; i < months.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: spend[i].toDouble(),
              color: i == selectedIndex
                  ? selectedMark
                  : barColor.withValues(alpha: _unselectedBarAlpha),
              width: _barWidth,
              borderRadius: BorderRadius.circular(_barCornerRadius),
              borderSide: i == selectedIndex
                  ? const BorderSide(
                      width: _selectedBorderWidth,
                      color: _selectedBorderColor,
                    )
                  : BorderSide.none,
            ),
          ],
        ),
    ];
    final data = BarChartData(
      minY: _chartBaseline,
      maxY: maxY,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: titlesData,
      barTouchData: BarTouchData(enabled: false),
      barGroups: barGroups,
    );

    return BarChart(data);
  }
}

// MARK: - Limit Line

class BudgetDetailLimitLine extends StatelessWidget {
  const BudgetDetailLimitLine({
    super.key,
    required this.months,
    required this.limit,
    required this.maxY,
  });

  final List<DateTime> months;
  final Decimal limit;
  final double maxY;

  static const _lineWidth = 2.0;
  static const _edgeInset = 0.5;
  static const _dashLength = 6;
  static const _dashGap = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limitValue = limit.toDouble();

    final lineBarsData = [
      LineChartBarData(
        spots: [
          FlSpot(-_edgeInset, limitValue),
          FlSpot(months.length - _edgeInset, limitValue),
        ],
        isCurved: false,
        color: theme.colorScheme.onSurface,
        barWidth: _lineWidth,
        dashArray: const [_dashLength, _dashGap],
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ),
    ];

    return IgnorePointer(
      child: LineChart(
        LineChartData(
          minX: -_edgeInset,
          maxX: months.length - _edgeInset,
          minY: _chartBaseline,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: lineBarsData,
        ),
      ),
    );
  }
}

// MARK: - Tap Overlay

class BudgetDetailTapOverlay extends StatelessWidget {
  const BudgetDetailTapOverlay({
    super.key,
    required this.months,
    required this.onSelectMonth,
  });

  final List<DateTime> months;
  final void Function(DateTime month) onSelectMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < months.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => onSelectMonth(months[i]),
            ),
          ),
      ],
    );
  }
}
