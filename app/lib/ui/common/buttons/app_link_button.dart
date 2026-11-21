import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';

// MARK: - Constants

const _chevronGap = 4.0;

const _chevronSize = 14.0;

const _chevron = Icons.chevron_right;

const _minWidth = 48.0;

const _minHeight = 48.0;

const _padding = EdgeInsets.zero;

// MARK: - AppLinkButton
class AppLinkButton extends StatelessWidget {
  const AppLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  final String label;

  final VoidCallback onPressed;

  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(_minWidth, _minHeight),
      padding: _padding,
      textStyle: appActionLabelStyle,
    );
    return TextButton(
      style: style,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: _chevronGap),
          const Icon(_chevron, size: _chevronSize),
        ],
      ),
    );
  }
}
