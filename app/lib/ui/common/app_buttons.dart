import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

ButtonStyle _geometry() {
  return FilledButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;

  final VoidCallback? onPressed;

  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = _geometry().copyWith(
      backgroundColor: destructive
          ? WidgetStatePropertyAll(colors.error)
          : null,
      foregroundColor: destructive
          ? WidgetStatePropertyAll(colors.onAction)
          : null,
    );
    return FilledButton(style: style, onPressed: onPressed, child: Text(label));
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;

  final VoidCallback? onPressed;

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (outlined) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.control),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return TextButton(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
