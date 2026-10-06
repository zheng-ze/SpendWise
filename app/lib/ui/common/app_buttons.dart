import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

final _shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

const _padding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

TextStyle _labelStyle(BuildContext context) {
  final base = Theme.of(context).textTheme.labelLarge
      ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600);
  return base ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
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
    return FilledButton(
      style: FilledButton.styleFrom(
        shape: _shape,
        padding: _padding,
        textStyle: _labelStyle(context),
        backgroundColor: destructive ? colors.error : null,
        foregroundColor: destructive ? colors.onAction : null,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
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
          shape: _shape,
          padding: _padding,
          textStyle: _labelStyle(context),
        ),
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return TextButton(
      style: TextButton.styleFrom(
        shape: _shape,
        padding: _padding,
        textStyle: _labelStyle(context),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
