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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.tint,
        border: Border.all(color: colors.control),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _Segment(
                label: option.label,
                selected: option.value == value,
                small: small,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        decoration: selected
            ? BoxDecoration(
                color: colors.raised,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  bottom: BorderSide(color: colors.action, width: 2),
                ),
              )
            : null,
        padding: EdgeInsets.symmetric(vertical: small ? 5 : 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: small ? 10 : 12,
            color: selected ? colors.text : colors.subtext,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
