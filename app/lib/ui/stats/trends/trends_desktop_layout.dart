import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';

const trendsMinimumTwoColumnContentWidth = 640.0;
const _trendsDesktopColumnGap = 16.0;
const _trendsDesktopColumnTopGap = 12.0;

class TrendsDesktopLayout extends StatelessWidget {
  const TrendsDesktopLayout({
    super.key,
    required this.layoutMode,
    required this.periodCard,
    required this.breakdown,
  });

  final ShellLayoutMode layoutMode;
  final Widget periodCard;
  final Widget breakdown;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final canUseColumns =
          layoutMode == ShellLayoutMode.desktop &&
          constraints.hasBoundedWidth &&
          constraints.maxWidth >= trendsMinimumTwoColumnContentWidth;
      if (!canUseColumns) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [periodCard, breakdown],
        );
      }
      final alignedPeriodCard = Padding(
        padding: const EdgeInsets.only(top: _trendsDesktopColumnTopGap),
        child: periodCard,
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: alignedPeriodCard),
          const SizedBox(width: _trendsDesktopColumnGap),
          Expanded(child: breakdown),
        ],
      );
    },
  );
}
