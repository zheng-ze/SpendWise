import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

enum MonthBarStatus { value, incomplete, gap, blank }

@immutable
class MonthBarSlot {
  const MonthBarSlot({this.value = 0, this.status = MonthBarStatus.value});

  final double value;

  final MonthBarStatus status;
}

class MonthBars extends StatelessWidget {
  const MonthBars({
    super.key,
    required this.slots,
    this.selectedIndex,
    this.onSelect,
    this.maxValue,
    this.height = 92,
  });

  final List<MonthBarSlot> slots;

  final int? selectedIndex;

  final ValueChanged<int>? onSelect;

  final double? maxValue;

  final double height;

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
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => const Color(0x00000000),
        getTooltipItem: (_, _, _, _) => null,
      ),
      touchCallback: (event, response) {
        if (event is! FlTapUpEvent) return;
        final index = response?.spot?.touchedBarGroupIndex;
        if (index != null) onSelect!(index);
      },
    );
    final chartData = BarChartData(
      minY: 0,
      maxY: top,
      alignment: BarChartAlignment.spaceAround,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      barTouchData: touchData,
      barGroups: groups,
    );

    return SizedBox(height: height, child: BarChart(chartData));
  }

  double get _dataTop {
    var top = 1.0;
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
    const radius = BorderRadius.vertical(top: Radius.circular(3));
    const noStroke = BorderSide(width: 0, color: Color(0x00000000));
    const barWidth = 16.0;
    final stubHeight = top * 0.09;
    if (selected) {
      final selectedHeight = switch (slot.status) {
        MonthBarStatus.blank => 0.0,
        MonthBarStatus.gap => stubHeight,
        MonthBarStatus.value || MonthBarStatus.incomplete => slot.value,
      };
      return BarChartRodData(
        toY: selectedHeight,
        width: barWidth,
        color: colors.selectedMark,
        borderRadius: radius,
        borderSide: noStroke,
      );
    }
    return switch (slot.status) {
      MonthBarStatus.value => BarChartRodData(
        toY: slot.value,
        width: barWidth,
        color: colors.action,
        borderRadius: radius,
      ),
      MonthBarStatus.incomplete => BarChartRodData(
        toY: slot.value,
        width: barWidth,
        color: colors.incomplete,
        borderRadius: radius,
        borderSide: BorderSide(color: colors.action, width: 1),
      ),
      MonthBarStatus.gap => BarChartRodData(
        toY: stubHeight,
        width: barWidth,
        color: const Color(0x00000000),
        borderRadius: radius,
        borderSide: BorderSide(color: colors.gap, width: 1),
        borderDashArray: const [4, 3],
      ),
      MonthBarStatus.blank => BarChartRodData(toY: 0, width: barWidth),
    };
  }
}
