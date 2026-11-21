import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _wordmarkStart = 'Spend';
const _wordmarkEnd = 'Wise';

// MARK: - SpendWiseWordmark
class SpendWiseWordmark extends StatelessWidget {
  const SpendWiseWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.title.copyWith(
      fontWeight: SpendWiseText.semibold,
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
