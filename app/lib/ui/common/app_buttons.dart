import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

final _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(_cornerRadius),
);

const _padding = EdgeInsets.symmetric(
  horizontal: _horizontalPadding,
  vertical: _verticalPadding,
);

const _cornerRadius = 10.0;

const _horizontalPadding = 12.0;

const _verticalPadding = 10.0;

const _labelFontSize = 12.0;

TextStyle _labelStyle(BuildContext context) {
  final base = Theme.of(context).textTheme.labelLarge
      ?.copyWith(fontSize: _labelFontSize, fontWeight: FontWeight.w600);
  return base ??
      const TextStyle(fontSize: _labelFontSize, fontWeight: FontWeight.w600);
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
    final style = FilledButton.styleFrom(
      shape: _shape,
      padding: _padding,
      textStyle: _labelStyle(context),
      backgroundColor: destructive ? colors.error : null,
      foregroundColor: destructive ? colors.onAction : null,
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
    final textStyle = _labelStyle(context);
    if (outlined) {
      final style = OutlinedButton.styleFrom(
        side: BorderSide(color: colors.control),
        shape: _shape,
        padding: _padding,
        textStyle: textStyle,
      );
      return OutlinedButton(
        style: style,
        onPressed: onPressed,
        child: Text(label),
      );
    }
    final style = TextButton.styleFrom(
      shape: _shape,
      padding: _padding,
      textStyle: textStyle,
    );
    return TextButton(style: style, onPressed: onPressed, child: Text(label));
  }
}
