import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

@immutable
class SegmentedOption<T> {
  const SegmentedOption({required this.value, required this.label});

  final T value;

  final String label;
}

class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.small = false,
  });

  final List<SegmentedOption<T>> options;

  final T value;

  final ValueChanged<T> onChanged;

  final bool small;

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
            onTap: () => onChanged(option.value),
          ),
        ),
    ];
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(_trackPadding),
      child: Row(children: segments),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.small,
    required this.onTap,
  });

  final String label;

  final bool selected;

  final bool small;

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
    BoxDecoration? decoration;
    if (selected) {
      decoration = BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(_segmentRadius),
        border: Border(
          bottom: BorderSide(
            color: colors.action,
            width: _selectedUnderlineWidth,
          ),
        ),
      );
    }
    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: small ? _smallFontSize : _regularFontSize,
        color: selected ? selectedColor : colors.subtext,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(_segmentRadius),
      onTap: onTap,
      child: Container(
        decoration: decoration,
        padding: EdgeInsets.symmetric(
          vertical: small ? _smallVerticalPadding : _regularVerticalPadding,
        ),
        child: labelText,
      ),
    );
  }
}
