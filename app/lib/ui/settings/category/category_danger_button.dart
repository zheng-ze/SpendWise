import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _cornerRadius = 10.0;
const _verticalPadding = 8.0;
const _horizontalPadding = 0.0;
const _minHeight = 48.0;
const _fontSize = 12.0;
const _fontWeight = FontWeight.w600;
const _fullWidth = double.infinity;

// MARK: - CategoryDangerButton

class CategoryDangerButton extends StatelessWidget {
  const CategoryDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: context.colors.error,
      minimumSize: const Size(_fullWidth, _minHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cornerRadius),
      ),
      textStyle: const TextStyle(fontSize: _fontSize, fontWeight: _fontWeight),
    );
    return TextButton(style: style, onPressed: onPressed, child: Text(label));
  }
}
