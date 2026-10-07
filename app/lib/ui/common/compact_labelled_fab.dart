import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

class CompactLabelledFab extends StatelessWidget {
  const CompactLabelledFab({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;

  final IconData icon;

  final VoidCallback onPressed;

  static const _cornerRadius = 14.0;

  static const _labelFontSize = 12.0;

  static const _iconSize = 16.0;

  static const _iconLabelGap = 6.0;

  static const _leftPadding = 11.0;

  static const _verticalPadding = 10.0;

  static const _rightPadding = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(_cornerRadius);
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: _labelFontSize,
      fontWeight: FontWeight.w600,
      color: colors.onAction,
    );
    final glyph = ExcludeSemantics(
      child: Icon(icon, size: _iconSize, color: colors.onAction),
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        const SizedBox(width: _iconLabelGap),
        ExcludeSemantics(child: Text(label)),
      ],
    );
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(
        _leftPadding,
        _verticalPadding,
        _rightPadding,
        _verticalPadding,
      ),
      child: row,
    );
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: colors.action,
        textStyle: labelStyle ?? TextStyle(color: colors.onAction),
        borderRadius: radius,
        child: InkWell(borderRadius: radius, onTap: onPressed, child: body),
      ),
    );
  }
}

class FabReserveSpace extends StatelessWidget {
  const FabReserveSpace({super.key});

  static const _reserveHeight = 58.0;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: _reserveHeight);
  }
}
