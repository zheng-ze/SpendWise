import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/charts/month_bars.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Column
@immutable
class MonthBarColumn {
  const MonthBarColumn({
    required this.slot,
    required this.label,
    required this.semanticLabel,
  });

  final MonthBarSlot slot;
  final String label;
  final String semanticLabel;
}

// MARK: - Chart
class MonthBarChart extends StatelessWidget {
  const MonthBarChart({
    super.key,
    required this.columns,
    required this.selectedIndex,
    required this.onSelect,
    this.limit,
    this.maxValue,
    this.barsHeight = _defaultBarsHeight,
  });

  final List<MonthBarColumn> columns;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final double? limit;
  final double? maxValue;
  final double barsHeight;

  static const _defaultBarsHeight = 92.0;
  static const _topMargin = 10.0;
  static const _baselineWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final slots = [for (final column in columns) column.slot];
    final chart = MonthBars(
      slots: slots,
      selectedIndex: selectedIndex,
      onSelect: onSelect,
      limit: limit,
      maxValue: maxValue,
      height: barsHeight,
    );
    final baseline = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.control, width: _baselineWidth),
        ),
      ),
      child: chart,
    );
    final axis = _MonthAxis(
      columns: columns,
      selectedIndex: selectedIndex,
      onSelect: onSelect,
    );
    return Padding(
      padding: const EdgeInsets.only(top: _topMargin),
      child: Column(children: [baseline, axis]),
    );
  }
}

// MARK: - Axis
class _MonthAxis extends StatelessWidget {
  const _MonthAxis({
    required this.columns,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<MonthBarColumn> columns;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cells = [
      for (var i = 0; i < columns.length; i++)
        _AxisCell(
          column: columns[i],
          index: i,
          selected: i == selectedIndex,
          onSelect: onSelect,
        ),
    ];
    return Row(children: cells);
  }
}

// MARK: - AxisCell
class _AxisCell extends StatelessWidget {
  const _AxisCell({
    required this.column,
    required this.index,
    required this.selected,
    required this.onSelect,
  });

  final MonthBarColumn column;
  final int index;
  final bool selected;
  final ValueChanged<int> onSelect;

  static const _height = 28.0;
  static const _labelTopPadding = 4.0;
  static const _monthFontSize = 10.0;
  static const _yearFontSize = 12.0;
  static const _yearLabelLength = 4;
  static const _bold = FontWeight.w700;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final light = Theme.of(context).brightness == Brightness.light;
    final selectedColor = light ? colors.action : colors.text;
    final isYear = column.label.length == _yearLabelLength;
    final label = Text(
      column.label,
      style: TextStyle(
        fontSize: isYear ? _yearFontSize : _monthFontSize,
        color: selected ? selectedColor : colors.subtext,
        fontWeight: selected ? _bold : null,
      ),
    );
    final aligned = Padding(
      padding: const EdgeInsets.only(top: _labelTopPadding),
      child: Align(alignment: Alignment.topCenter, child: label),
    );
    final surface = InkWell(
      onTap: () => onSelect(index),
      child: SizedBox(height: _height, child: aligned),
    );
    final cell = Semantics(
      button: true,
      selected: selected,
      label: column.semanticLabel,
      excludeSemantics: true,
      onTap: () => onSelect(index),
      child: surface,
    );
    return Expanded(child: cell);
  }
}
