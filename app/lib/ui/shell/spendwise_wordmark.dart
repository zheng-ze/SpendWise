import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _wordmarkStart = 'Spend';
const _wordmarkEnd = 'Wise';

// MARK: - SpendWiseWordmark
class SpendWiseWordmark extends StatelessWidget {
  const SpendWiseWordmark({super.key, required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
