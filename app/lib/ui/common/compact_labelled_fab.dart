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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(14);
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colors.onAction,
    );
    final glyph = ExcludeSemantics(
      child: Icon(icon, size: 16, color: colors.onAction),
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        const SizedBox(width: 6),
        ExcludeSemantics(child: Text(label)),
      ],
    );
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(11, 10, 14, 10),
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

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 58);
  }
}
