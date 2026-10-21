import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _expenseLabel = 'Expense';
const _incomeLabel = 'Income';
const _monthLabel = 'Month by month';
const _yearLabel = 'Year by year';
const _previousLabel = 'Previous';
const _nextLabel = 'Next';
const _controlGap = 10.0;

// MARK: - KindControl
class TrendsKindControl extends StatelessWidget {
  const TrendsKindControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TrendsKind value;
  final ValueChanged<TrendsKind> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      SegmentedOption(value: TrendsKind.expense, label: _expenseLabel),
      SegmentedOption(value: TrendsKind.income, label: _incomeLabel),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: _controlGap),
      child: SegmentedControl<TrendsKind>(
        options: options,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

// MARK: - ModeControl
class TrendsModeControl extends StatelessWidget {
  const TrendsModeControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TrendsMode value;
  final ValueChanged<TrendsMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      SegmentedOption(value: TrendsMode.month, label: _monthLabel),
      SegmentedOption(value: TrendsMode.year, label: _yearLabel),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: _controlGap),
      child: SegmentedControl<TrendsMode>(
        options: options,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

// MARK: - PeriodRow
class TrendsPeriodRowView extends StatelessWidget {
  const TrendsPeriodRowView({
    super.key,
    required this.period,
    required this.onPrevious,
    required this.onNext,
  });

  final TrendsPeriodRow period;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  static const _verticalMargin = EdgeInsets.only(top: 2, bottom: 4);
  static const _labelFontSize = 12.0;
  static const _semiBold = FontWeight.w600;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      period.rangeLabel,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: _labelFontSize, fontWeight: _semiBold),
    );
    final previous = _PeriodArrow(
      icon: Icons.chevron_left,
      label: _previousLabel,
      enabled: period.previousEnabled,
      onPressed: onPrevious,
    );
    final next = _PeriodArrow(
      icon: Icons.chevron_right,
      label: _nextLabel,
      enabled: period.nextEnabled,
      onPressed: onNext,
    );
    return Padding(
      padding: _verticalMargin,
      child: Row(
        children: [
          previous,
          Expanded(child: label),
          next,
        ],
      ),
    );
  }
}

// MARK: - PeriodArrow
class _PeriodArrow extends StatelessWidget {
  const _PeriodArrow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  static const _size = 28.0;
  static const _radius = 8.0;
  static const _iconSize = 16.0;
  static const _disabledOpacity = 0.6;
  static const _dashLength = 3.0;
  static const _dashGap = 3.0;
  static const _borderWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glyph = Icon(
      icon,
      size: _iconSize,
      color: enabled ? colors.action : colors.subtext,
    );
    final face = enabled
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(_radius),
            ),
            child: Center(child: glyph),
          )
        : Opacity(
            opacity: _disabledOpacity,
            child: CustomPaint(
              painter: _DashedOutline(
                color: colors.edge,
                radius: _radius,
                dash: _dashLength,
                gap: _dashGap,
                width: _borderWidth,
              ),
              child: Center(child: glyph),
            ),
          );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: enabled ? onPressed : null,
        child: SizedBox(width: _size, height: _size, child: face),
      ),
    );
  }
}

// MARK: - DashedOutline
class _DashedOutline extends CustomPainter {
  const _DashedOutline({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.width,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final outline = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(outline);
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += dash + gap) {
        canvas.drawPath(metric.extractPath(at, at + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap ||
      old.width != width;
}
