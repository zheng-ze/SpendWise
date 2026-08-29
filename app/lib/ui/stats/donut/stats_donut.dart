import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/helpers/slices.dart';

const _outerRadiusFraction = 0.6;
const _innerRadiusFraction = 0.58;
const _sliceGapDegrees = 1.5;
const _elbowDistance = 14.0;
const _labelLegLength = 12.0;
const _labelFontSize = 10.0;

/// `fl_chart`'s `PieChartSectionData` has no way to draw a leader line with an
/// independently positioned elbow and two-tone label text, so this paints
/// directly rather than compromising on label placement.
class StatsDonut extends StatelessWidget {
  const StatsDonut({super.key, required this.slices});

  final List<Slice> slices;

  @override
  Widget build(BuildContext context) {
    final positive = slices.where((s) => s.amount.sign > 0).toList();
    final theme = Theme.of(context);

    return Semantics(
      label: _summaryLabel(positive),
      child: SizedBox(
        height: 260,
        child: ExcludeSemantics(
          child: CustomPaint(
            painter: _DonutPainter(
              slices: positive,
              labelColor: theme.colorScheme.onSurface,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// One line per slice so a screen reader gets the same name, amount and
/// share the canvas draws visually, since the canvas itself is excluded.
String _summaryLabel(List<Slice> slices) {
  return slices
      .map(
        (slice) =>
            '${slice.name}, ${formatCurrency(slice.amount)}, '
            '${formatPercent(slice.fraction.toDouble())}',
      )
      .join('. ');
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.labelColor});

  final List<Slice> slices;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final halfShortSide = math.min(size.width, size.height) / 2;
    final outerRadius = halfShortSide * _outerRadiusFraction;
    final innerRadius = outerRadius * _innerRadiusFraction;
    final gap = slices.length == 1 ? 0.0 : _sliceGapDegrees;

    var startDegrees = -90.0;
    final midAngles = <double>[];

    for (final slice in slices) {
      final sweep = slice.fraction.toDouble() * 360.0;
      final drawSweep = math.max(sweep - gap, 0.0);

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerRadius - innerRadius;

      final ringRadius = (outerRadius + innerRadius) / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        _toRadians(startDegrees),
        _toRadians(drawSweep),
        false,
        paint,
      );

      midAngles.add(startDegrees + drawSweep / 2);
      startDegrees += sweep;
    }

    for (var i = 0; i < slices.length; i++) {
      _paintLabel(canvas, size, center, outerRadius, midAngles[i], slices[i]);
    }
  }

  void _paintLabel(
    Canvas canvas,
    Size size,
    Offset center,
    double outerRadius,
    double midDegrees,
    Slice slice,
  ) {
    final angle = _toRadians(midDegrees);
    final direction = Offset(math.cos(angle), math.sin(angle));

    final ringPoint = center + direction * outerRadius;
    final elbow = center + direction * (outerRadius + _elbowDistance);
    final awayFromCenter = direction.dx >= 0 ? 1.0 : -1.0;
    final labelAnchor = elbow + Offset(awayFromCenter * _labelLegLength, 0);

    final linePaint = Paint()
      ..color = slice.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(ringPoint, elbow, linePaint);
    canvas.drawLine(elbow, labelAnchor, linePaint);

    final percent = formatPercent(slice.fraction.toDouble());
    final span = TextSpan(
      children: [
        TextSpan(
          text: '${slice.name} ',
          style: TextStyle(
            color: labelColor,
            fontSize: _labelFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: percent,
          style: TextStyle(
            color: slice.color,
            fontSize: _labelFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();

    var labelX = awayFromCenter >= 0
        ? labelAnchor.dx
        : labelAnchor.dx - painter.width;
    var labelY = labelAnchor.dy - painter.height / 2;

    labelX = labelX.clamp(0.0, math.max(size.width - painter.width, 0.0));
    labelY = labelY.clamp(0.0, math.max(size.height - painter.height, 0.0));

    painter.paint(canvas, Offset(labelX, labelY));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.labelColor != labelColor;
  }
}

double _toRadians(double degrees) => degrees * math.pi / 180;
