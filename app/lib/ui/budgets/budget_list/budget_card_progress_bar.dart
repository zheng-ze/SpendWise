import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';

// MARK: - Constants

const _barHeight = 22.0;
const _barRadius = _barHeight / 2;
const _emptyProgress = 0.0;
const _fullProgress = 1.0;
const _clipOrigin = 0.0;
const _labelWeight = FontWeight.w700;

// MARK: - Progress Bar

class BudgetCardProgressBar extends StatelessWidget {
  const BudgetCardProgressBar({
    super.key,
    required this.percentOfLimit,
    required this.color,
  });

  final double percentOfLimit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = percentOfLimit.clamp(_emptyProgress, _fullProgress);
    final trackLabel = _ProgressLabel(
      percentOfLimit: percentOfLimit,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final fillLabel = _ProgressLabel(
      percentOfLimit: percentOfLimit,
      color: foregroundOn(color),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(_barRadius),
      child: Stack(
        children: [
          Container(
            height: _barHeight,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          FractionallySizedBox(
            widthFactor: fraction,
            child: Container(height: _barHeight, color: color),
          ),
          Positioned.fill(child: trackLabel),
          Positioned.fill(
            child: ClipRect(
              clipper: _LeadingFractionClipper(fraction),
              child: fillLabel,
            ),
          ),
        ],
      ),
    );
  }
}

// MARK: - Leading Fraction Clipper
class _LeadingFractionClipper extends CustomClipper<Rect> {
  const _LeadingFractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    _clipOrigin,
    _clipOrigin,
    size.width * fraction,
    size.height,
  );

  @override
  bool shouldReclip(_LeadingFractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

// MARK: - Progress Label
class _ProgressLabel extends StatelessWidget {
  const _ProgressLabel({required this.percentOfLimit, required this.color});

  final double percentOfLimit;
  final Color color;

  static const _labelRightPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: _labelRightPadding),
        child: Text(
          formatPercent(percentOfLimit),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: _labelWeight,
            color: color,
          ),
        ),
      ),
    );
  }
}
