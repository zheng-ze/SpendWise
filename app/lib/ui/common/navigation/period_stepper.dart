import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/edge_border.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _defaultPreviousLabel = 'Previous';
const _defaultNextLabel = 'Next';

// MARK: - PeriodStepper
class PeriodStepper extends StatelessWidget {
  const PeriodStepper({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.previousEnabled = true,
    this.nextEnabled = true,
    this.previousLabel = _defaultPreviousLabel,
    this.nextLabel = _defaultNextLabel,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool previousEnabled;
  final bool nextEnabled;
  final String previousLabel;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: context.text.body.copyWith(fontWeight: SpendWiseText.semibold),
    );
    final previous = _StepperArrow(
      icon: Icons.chevron_left,
      label: previousLabel,
      enabled: previousEnabled,
      onPressed: onPrevious,
    );
    final next = _StepperArrow(
      icon: Icons.chevron_right,
      label: nextLabel,
      enabled: nextEnabled,
      onPressed: onNext,
    );
    return Row(
      children: [
        previous,
        Expanded(child: text),
        next,
      ],
    );
  }
}

// MARK: - StepperArrow
class _StepperArrow extends StatelessWidget {
  const _StepperArrow({
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
                width: edgeThickness,
              ),
              child: Center(child: glyph),
            ),
          );
    final tile = InkWell(
      borderRadius: BorderRadius.circular(_radius),
      onTap: enabled ? onPressed : null,
      child: SizedBox(width: _size, height: _size, child: face),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Tooltip(message: label, excludeFromSemantics: true, child: tile),
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
