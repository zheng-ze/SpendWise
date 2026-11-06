import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - LabelledBackButton
class LabelledBackButton extends StatelessWidget {
  const LabelledBackButton({
    super.key,
    required this.onPressed,
    this.label,
    this.showLabel = false,
  });

  final VoidCallback onPressed;
  final String? label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    if (label == null) return BackButton(onPressed: onPressed);
    if (showLabel) return _VisibleBackLabel(label: label, onPressed: onPressed);
    return Semantics(
      label: label,
      button: true,
      onTap: onPressed,
      excludeSemantics: true,
      child: BackButton(onPressed: onPressed),
    );
  }
}

class _VisibleBackLabel extends StatelessWidget {
  const _VisibleBackLabel({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const _chevronSize = 28.0;
  static const _minHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chevron = Icon(
      Icons.chevron_left,
      size: _chevronSize,
      color: colors.action,
    );
    final text = Text(
      label,
      style: context.text.row.copyWith(color: colors.action),
    );
    final row = Row(mainAxisSize: MainAxisSize.min, children: [chevron, text]);
    return InkWell(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: row,
      ),
    );
  }
}
