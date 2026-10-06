import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

@immutable
class DonutSegment {
  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;

  final double value;

  final Color color;
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    this.centerLabel,
    this.centerValue,
    this.selectedIndex,
    this.onSelect,
    this.size = 132,
  });

  final List<DonutSegment> segments;

  final String? centerLabel;

  final String? centerValue;

  final int? selectedIndex;

  final ValueChanged<int>? onSelect;

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final centerLabel = this.centerLabel;
    final centerValue = this.centerValue;
    final sections = [
      for (var i = 0; i < segments.length; i++)
        PieChartSectionData(
          value: segments[i].value,
          color: i == selectedIndex ? colors.selectedMark : segments[i].color,
          radius: size * 0.17,
          showTitle: false,
          borderSide: const BorderSide(width: 0, color: Color(0x00000000)),
        ),
    ];

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              centerSpaceRadius: size * 0.34,
              sectionsSpace: 1.5,
              sections: sections,
              pieTouchData: PieTouchData(
                enabled: onSelect != null,
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final index = response?.touchedSection?.touchedSectionIndex;
                  if (index != null && index >= 0) onSelect!(index);
                },
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (centerValue != null)
                  Text(
                    centerValue,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (centerLabel != null)
                  Text(
                    centerLabel,
                    style: TextStyle(fontSize: 10, color: colors.subtext),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
