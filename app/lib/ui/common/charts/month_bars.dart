import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/stats/helpers/chart_helpers.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _emptyValue = 0.0;

// MARK: - MonthBarStatus
enum MonthBarStatus { value, incomplete, gap, blank }

// MARK: - MonthBarSlot
@immutable
class MonthBarSlot {
  const MonthBarSlot({
    this.value = _emptyValue,
    this.status = MonthBarStatus.value,
  });

  final double value;

  final MonthBarStatus status;
}

// MARK: - MonthBars
class MonthBars extends StatelessWidget {
  const MonthBars({
    super.key,
    required this.slots,
    this.selectedIndex,
    this.onSelect,
    this.maxValue,
    this.height = _defaultHeight,
    this.limit,
    this.barColor,
    this.months,
    this.touchFullHeight = false,
  });

  static const _defaultHeight = 92.0;

  static const _minTop = 1.0;

  static const _topRadius = 3.0;

  static const _barWidth = 16.0;

  static const _outlineWidth = 1.0;

  static const _transparent = Color(0x00000000);

  static const _noStroke = BorderSide(width: 0, color: _transparent);

  static const _unselectedBarAlpha = 0.5;

  static const _titleInterval = 1.0;

  static const _limitLineWidth = 2.0;

  static const _limitDashLength = 6;

  static const _limitDashGap = 4;

  static const _limitDashPattern = [_limitDashLength, _limitDashGap];

  static const _barRadius = BorderRadius.vertical(
    top: Radius.circular(_topRadius),
  );

  static const _tooltipTransparent = Color(0x00000000);

  final List<MonthBarSlot> slots;

  final int? selectedIndex;

  final ValueChanged<int>? onSelect;

  final double? maxValue;

  final double height;

  final double? limit;

  final Color? barColor;

  final List<DateTime>? months;

  final bool touchFullHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = maxValue ?? _dataTop;
    final groups = [
      for (var i = 0; i < slots.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [_rod(colors, slots[i], i == selectedIndex, top)],
        ),
    ];
    final touchData = BarTouchData(
      enabled: onSelect != null,
      allowTouchBarBackDraw: touchFullHeight,
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => _tooltipTransparent,
        getTooltipItem: (_, _, _, _) => null,
      ),
      touchCallback: (event, response) {
        if (event is! FlTapUpEvent) return;
        final index = response?.spot?.touchedBarGroupIndex;
        if (index != null) onSelect!(index);
      },
    );
    final limitLine = limit;
    final axisMonths = months;
    final lineColor = Theme.of(context).colorScheme.onSurface;
    final tickStyle = Theme.of(context).textTheme.labelSmall;
    final titlesData = axisMonths == null
        ? const FlTitlesData(show: false)
        : FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _titleInterval,
                getTitlesWidget: (value, _) =>
                    monthAxisTick(tickStyle, axisMonths, value),
              ),
            ),
          );
    final extraLines = ExtraLinesData(
      horizontalLines: [
        if (limitLine != null)
          HorizontalLine(
            y: limitLine,
            color: lineColor,
            strokeWidth: _limitLineWidth,
            dashArray: _limitDashPattern,
          ),
      ],
    );
    final chartData = BarChartData(
      minY: _emptyValue,
      maxY: top,
      alignment: BarChartAlignment.spaceAround,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: titlesData,
      extraLinesData: extraLines,
      barTouchData: touchData,
      barGroups: groups,
    );

    return SizedBox(height: height, child: BarChart(chartData));
  }

  double get _dataTop {
    var top = _minTop;
    for (final slot in slots) {
      final contributes = switch (slot.status) {
        MonthBarStatus.value || MonthBarStatus.incomplete => true,
        MonthBarStatus.gap || MonthBarStatus.blank => false,
      };
      if (!contributes) continue;
      if (slot.value > top) top = slot.value;
    }
    return top;
  }

  BarChartRodData _rod(
    SpendWiseColors colors,
    MonthBarSlot slot,
    bool selected,
    double top,
  ) {
    const radius = _barRadius;
    const barWidth = _barWidth;
    final drawsBar = switch (slot.status) {
      MonthBarStatus.value || MonthBarStatus.incomplete => true,
      MonthBarStatus.gap || MonthBarStatus.blank => false,
    };
    final touchArea = BackgroundBarChartRodData(
      show: true,
      toY: top,
      color: _transparent,
    );
    if (!drawsBar) {
      return BarChartRodData(
        toY: _emptyValue,
        width: barWidth,
        backDrawRodData: touchArea,
      );
    }
    if (selected) {
      return BarChartRodData(
        toY: slot.value,
        width: barWidth,
        color: colors.selectedMark,
        borderRadius: radius,
        borderSide: _noStroke,
        backDrawRodData: touchArea,
      );
    }
    if (slot.status == MonthBarStatus.incomplete) {
      return BarChartRodData(
        toY: slot.value,
        width: barWidth,
        color: colors.incomplete,
        borderRadius: radius,
        borderSide: BorderSide(color: colors.action, width: _outlineWidth),
        backDrawRodData: touchArea,
      );
    }
    final custom = barColor;
    final fill = custom == null
        ? colors.action
        : custom.withValues(alpha: _unselectedBarAlpha);
    return BarChartRodData(
      toY: slot.value,
      width: barWidth,
      color: fill,
      borderRadius: radius,
      backDrawRodData: touchArea,
    );
  }
}
