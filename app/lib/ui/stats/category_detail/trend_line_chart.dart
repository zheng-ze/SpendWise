import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/stats/helpers/chart_helpers.dart';

// MARK: - TrendLineChart
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
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
  static const _chartBaseline = 0.0;
  static const _dotStrokeWidth = 0.0;
  static const _touchSpotThreshold = double.infinity;
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
      touchSpotThreshold: _touchSpotThreshold,
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
                    strokeWidth: _dotStrokeWidth,
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
            strokeWidth: _dotStrokeWidth,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      ),
    ];

    return LineChart(
      LineChartData(
        minY: _chartBaseline,
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
