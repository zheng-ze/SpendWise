import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/helpers/slices.dart';

// MARK: - Constants
const _outerRadiusFraction = 0.6;
const _innerRadiusFraction = 0.58;
const _sliceGapDegrees = 1.5;
const _elbowDistance = 14.0;
const _labelLegLength = 12.0;
const _labelFontSize = 10.0;
const _donutHeight = 260.0;
const _startAngleDegrees = -90.0;
const _fullCircleDegrees = 360.0;
const _degreesInHalfCircle = 180;
const _rightSideSign = 1.0;
const _leftSideSign = -1.0;
const _connectorLineWidth = 1.0;
const _halfFactor = 0.5;
const _zeroSweep = 0.0;
const _labelOrigin = 0.0;

// MARK: - StatsDonut
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
        height: _donutHeight,
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

// MARK: - Summary Label

String _summaryLabel(List<Slice> slices) {
  return slices
      .map(
        (slice) =>
            '${slice.name}, ${formatMoney(slice.amount)}, '
            '${formatPercent(slice.fraction.toDouble())}',
      )
      .join('. ');
}

// MARK: - DonutPainter
class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.labelColor});

  final List<Slice> slices;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;

    final center = Offset(size.width * _halfFactor, size.height * _halfFactor);
    final halfShortSide = math.min(size.width, size.height) * _halfFactor;
    final outerRadius = halfShortSide * _outerRadiusFraction;
    final innerRadius = outerRadius * _innerRadiusFraction;
    final gap = slices.length == 1 ? _zeroSweep : _sliceGapDegrees;

    var startDegrees = _startAngleDegrees;
    final midAngles = <double>[];

    for (final slice in slices) {
      final sweep = slice.fraction.toDouble() * _fullCircleDegrees;
      final drawSweep = math.max(sweep - gap, _zeroSweep);

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerRadius - innerRadius;

      final ringRadius = (outerRadius + innerRadius) * _halfFactor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        _toRadians(startDegrees),
        _toRadians(drawSweep),
        false,
        paint,
      );

      midAngles.add(startDegrees + drawSweep * _halfFactor);
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
    final awayFromCenter = direction.dx >= _labelOrigin
        ? _rightSideSign
        : _leftSideSign;
    final labelAnchor =
        elbow + Offset(awayFromCenter * _labelLegLength, _labelOrigin);

    final linePaint = Paint()
      ..color = slice.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _connectorLineWidth;
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

    var labelX = awayFromCenter >= _labelOrigin
        ? labelAnchor.dx
        : labelAnchor.dx - painter.width;
    var labelY = labelAnchor.dy - painter.height * _halfFactor;

    labelX = labelX.clamp(
      _labelOrigin,
      math.max(size.width - painter.width, _labelOrigin),
    );
    labelY = labelY.clamp(
      _labelOrigin,
      math.max(size.height - painter.height, _labelOrigin),
    );

    painter.paint(canvas, Offset(labelX, labelY));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.labelColor != labelColor;
  }
}

// MARK: - Angle Conversion

double _toRadians(double degrees) => degrees * math.pi / _degreesInHalfCircle;
