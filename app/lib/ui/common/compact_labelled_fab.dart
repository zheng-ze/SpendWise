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
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: colors.action,
        textStyle: TextStyle(color: colors.onAction),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 14, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(icon, size: 16, color: colors.onAction),
                ),
                const SizedBox(width: 6),
                ExcludeSemantics(child: Text(label)),
              ],
            ),
          ),
        ),
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
