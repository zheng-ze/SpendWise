import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _regularWeight = FontWeight.w400;

const _semiBoldWeight = FontWeight.w600;

// MARK: - SegmentedOption
@immutable
class SegmentedOption<T> {
  const SegmentedOption({required this.value, required this.label});

  final T value;

  final String label;
}

// MARK: - SegmentedControl
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.small = false,
    this.segmentGap = 0.0,
    this.labelHorizontalPadding = 0.0,
    this.labelVerticalPadding,
  });

  final List<SegmentedOption<T>> options;

  final T value;

  final ValueChanged<T> onChanged;

  final bool small;

  final double segmentGap;

  final double labelHorizontalPadding;

  final double? labelVerticalPadding;

  static const _trackRadius = 10.0;

  static const _trackPadding = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final light = Theme.of(context).brightness == Brightness.light;
    final decoration = BoxDecoration(
      color: light ? colors.surface : colors.tint,
      border: Border.all(color: light ? colors.edge : colors.control),
      borderRadius: BorderRadius.circular(_trackRadius),
    );
    final segments = [
      for (final option in options)
        Expanded(
          child: _Segment(
            label: option.label,
            selected: option.value == value,
            small: small,
            horizontalPadding: labelHorizontalPadding,
            verticalPadding: labelVerticalPadding,
            onTap: () => onChanged(option.value),
          ),
        ),
    ];
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(_trackPadding),
      child: Row(spacing: segmentGap, children: segments),
    );
  }
}

// MARK: - Segment
class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.small,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.onTap,
  });

  final String label;

  final bool selected;

  final bool small;

  final double horizontalPadding;

  final double? verticalPadding;

  final VoidCallback onTap;

  static const _segmentRadius = 8.0;

  static const _selectedUnderlineWidth = 2.0;

  static const _regularFontSize = 12.0;

  static const _smallFontSize = 10.0;

  static const _regularVerticalPadding = 6.0;

  static const _smallVerticalPadding = 5.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectedColor = Theme.of(context).brightness == Brightness.light
        ? colors.action
        : colors.text;
    final fill = selected
        ? BoxDecoration(
            color: colors.raised,
            borderRadius: BorderRadius.circular(_segmentRadius),
          )
        : null;
    final underline = selected
        ? Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _selectedUnderlineWidth,
            child: ColoredBox(color: colors.action),
          )
        : null;
    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: small ? _smallFontSize : _regularFontSize,
        color: selected ? selectedColor : colors.subtext,
        fontWeight: selected ? _semiBoldWeight : _regularWeight,
      ),
    );
    final padding = EdgeInsets.symmetric(
      vertical:
          verticalPadding ??
          (small ? _smallVerticalPadding : _regularVerticalPadding),
      horizontal: horizontalPadding,
    );
    final content = Container(
      alignment: Alignment.center,
      decoration: fill,
      padding: padding,
      child: labelText,
    );
    final layers = Stack(children: [content, ?underline]);
    return InkWell(
      borderRadius: BorderRadius.circular(_segmentRadius),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_segmentRadius),
        child: layers,
      ),
    );
  }
}
