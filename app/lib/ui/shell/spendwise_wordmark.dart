import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _wordmarkStart = 'Spend';
const _wordmarkEnd = 'Wise';
const _wordmarkLetterSpacing = -0.8;
const _wordmarkWeight = FontWeight.w600;

// MARK: - SpendWiseWordmark
class SpendWiseWordmark extends StatelessWidget {
  const SpendWiseWordmark({super.key, required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: _wordmarkWeight,
      letterSpacing: _wordmarkLetterSpacing,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _wordmarkStart,
            style: style.copyWith(color: colors.text),
          ),
          TextSpan(
            text: _wordmarkEnd,
            style: style.copyWith(color: colors.action),
          ),
        ],
      ),
    );
  }
}
