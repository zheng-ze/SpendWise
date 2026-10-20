import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const trendsDetailActionLabel = 'See more detail';
const trendsDetailActionHitHeight = 48.0;
const _horizontalInset = 13.0;
const _chevronGap = 4.0;
const _chevronSize = 14.0;
const _labelFontSize = 12.0;
const _labelWeight = FontWeight.w500;
const _chevron = Icons.chevron_right;

// MARK: - TrendsDetailAction
class TrendsDetailAction extends StatelessWidget {
  const TrendsDetailAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.subtext;
    final label = Text(
      trendsDetailActionLabel,
      style: TextStyle(
        color: color,
        fontSize: _labelFontSize,
        fontWeight: _labelWeight,
      ),
    );

    final row = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        label,
        const SizedBox(width: _chevronGap),
        Icon(_chevron, size: _chevronSize, color: color),
      ],
    );
    final hitRegion = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: trendsDetailActionHitHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalInset),
        child: row,
      ),
    );

    return Semantics(
      button: true,
      label: trendsDetailActionLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: InkWell(onTap: onPressed, child: hitRegion),
    );
  }
}
