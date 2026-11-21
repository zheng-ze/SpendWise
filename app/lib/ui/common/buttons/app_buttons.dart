import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _actionMinHeight = 48.0;

final appActionLabelStyle = SpendWiseText.standard.body.copyWith(
  fontWeight: SpendWiseText.medium,
);

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

TextStyle _labelStyle(BuildContext context) {
  final body = context.text.body;
  final base = Theme.of(context).textTheme.labelLarge?.merge(body);
  return (base ?? body).copyWith(fontWeight: SpendWiseText.semibold);
}

// MARK: - PrimaryButton
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

// MARK: - SecondaryButton
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.destructive = false,
  });

  final String label;

  final VoidCallback? onPressed;

  final bool outlined;

  final bool destructive;

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
    if (destructive) {
      final style = TextButton.styleFrom(
        foregroundColor: colors.error,
        minimumSize: const Size.fromHeight(_actionMinHeight),
        textStyle: appActionLabelStyle,
      );
      return TextButton(style: style, onPressed: onPressed, child: Text(label));
    }
    final style = TextButton.styleFrom(
      shape: _shape,
      padding: _padding,
      textStyle: textStyle,
    );
    return TextButton(style: style, onPressed: onPressed, child: Text(label));
  }
}
