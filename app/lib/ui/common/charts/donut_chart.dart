import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _semiBoldWeight = FontWeight.w600;

// MARK: - DonutSegment
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

// MARK: - DonutChart
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    this.centerLabel,
    this.centerValue,
    this.selectedIndex,
    this.onSelect,
    this.size = _defaultSize,
  });

  static const _defaultSize = 132.0;

  static const _radiusFactor = 0.17;

  static const _centerSpaceFactor = 0.34;

  static const _diameterFactor = 2.0;

  static const _sectionsSpace = 1.5;

  static const _transparent = Color(0x00000000);

  static const _noBorder = BorderSide(width: 0, color: _transparent);

  final List<DonutSegment> segments;

  final String? centerLabel;

  final String? centerValue;

  final int? selectedIndex;

  final ValueChanged<int>? onSelect;

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sections = [
      for (var i = 0; i < segments.length; i++)
        PieChartSectionData(
          value: segments[i].value,
          color: i == selectedIndex ? colors.selectedMark : segments[i].color,
          radius: size * _radiusFactor,
          showTitle: false,
          borderSide: _noBorder,
        ),
    ];
    final chart = PieChart(
      PieChartData(
        centerSpaceRadius: size * _centerSpaceFactor,
        sectionsSpace: _sectionsSpace,
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
    );
    final center = _DonutCenter(
      centerLabel: centerLabel,
      centerValue: centerValue,
      innerDiameter: size * _centerSpaceFactor * _diameterFactor,
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [chart, center]),
    );
  }
}

// MARK: - DonutCenter
class _DonutCenter extends StatelessWidget {
  const _DonutCenter({
    required this.centerLabel,
    required this.centerValue,
    required this.innerDiameter,
  });

  static const _valueFontSize = 14.0;

  static const _labelFontSize = 10.0;

  static const _horizontalPadding = 6.0;

  final String? centerLabel;

  final String? centerValue;

  final double innerDiameter;

  @override
  Widget build(BuildContext context) {
    final centerValue = this.centerValue;
    final centerLabel = this.centerLabel;
    final valueText = centerValue == null
        ? null
        : Text(
            centerValue,
            style: const TextStyle(
              fontSize: _valueFontSize,
              fontWeight: _semiBoldWeight,
            ),
          );
    final labelText = centerLabel == null
        ? null
        : Text(
            centerLabel,
            style: TextStyle(
              fontSize: _labelFontSize,
              color: context.colors.subtext,
            ),
          );
    final entries = [
      if (valueText != null) FittedBox(fit: BoxFit.scaleDown, child: valueText),
      if (labelText != null) FittedBox(fit: BoxFit.scaleDown, child: labelText),
    ];
    final column = Column(mainAxisSize: MainAxisSize.min, children: entries);
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: column,
    );
    return Center(
      child: SizedBox(width: innerDiameter, child: padded),
    );
  }
}
