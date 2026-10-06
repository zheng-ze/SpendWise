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

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: top,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          barTouchData: BarTouchData(
            enabled: onSelect != null,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0x00000000),
              getTooltipItem: (_, _, _, _) => null,
            ),
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions) return;
              final index = response?.spot?.touchedBarGroupIndex;
              if (index != null) onSelect!(index);
            },
          ),
          barGroups: groups,
        ),
      ),
    );
  }

  double get _dataTop {
    var top = 1.0;
    for (final slot in slots) {
      if (slot.status == MonthBarStatus.value ||
          slot.status == MonthBarStatus.incomplete) {
        if (slot.value > top) top = slot.value;
      }
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
    if (selected) {
      final value = slot.status == MonthBarStatus.blank ? 0.0 : slot.value;
      return BarChartRodData(
        toY: value == 0 ? top * 0.09 : value,
        width: 16,
        color: colors.selectedMark,
        borderRadius: radius,
        borderSide: noStroke,
      );
    }
    return switch (slot.status) {
      MonthBarStatus.value => BarChartRodData(
        toY: slot.value,
        width: 16,
        color: colors.action,
        borderRadius: radius,
      ),
      MonthBarStatus.incomplete => BarChartRodData(
        toY: slot.value,
        width: 16,
        color: colors.incomplete,
        borderRadius: radius,
        borderSide: BorderSide(color: colors.action, width: 1),
      ),
      MonthBarStatus.gap => BarChartRodData(
        toY: top * 0.09,
        width: 16,
        color: const Color(0x00000000),
        borderRadius: radius,
        borderSide: BorderSide(color: colors.gap, width: 1),
      ),
      MonthBarStatus.blank => BarChartRodData(toY: 0, width: 16),
    };
  }
}
