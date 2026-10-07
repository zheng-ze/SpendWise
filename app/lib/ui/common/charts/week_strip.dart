import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

const _barHeight = 40.0;

const _barRadius = 2.0;

@immutable
class WeekStripDay {
  const WeekStripDay({
    required this.label,
    required this.caption,
    this.fraction = 0,
    this.future = false,
  });

  final String label;

  final String caption;

  final double fraction;

  final bool future;
}

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.days});

  final List<WeekStripDay> days;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [for (final day in days) Expanded(child: _DayColumn(day: day))],
    );
  }
}

class GapStubPainter extends CustomPainter {
  const GapStubPainter({required this.color});

  static const _strokeWidth = 1.5;

  static const _dashLength = 4.0;

  static const _dashStep = 7.0;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = _outline(size);
    final dashed = _dashed(outline);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawPath(dashed, paint);
  }

  Path _outline(Size size) {
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(_barRadius),
      ),
    );
  }

  Path _dashed(Path outline) {
    final dashed = Path();
    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dashLength).clamp(0.0, metric.length);
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += _dashStep;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(covariant GapStubPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day});

  static const _barWidthFactor = 0.48;

  static const _captionFontSize = 10.0;

  final WeekStripDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bar = _DayBar(day: day);
    final barArea = SizedBox(
      height: _barHeight,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(widthFactor: _barWidthFactor, child: bar),
      ),
    );
    final title = Text(
      day.label,
      style: const TextStyle(
        fontSize: _captionFontSize,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final caption = Text(
      day.caption,
      style: TextStyle(fontSize: _captionFontSize, color: colors.subtext),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [barArea, title, caption],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.day});

  final WeekStripDay day;

  @override
  Widget build(BuildContext context) {
    final bar = switch (day) {
      WeekStripDay(future: true) => const SizedBox(height: _barHeight),
      WeekStripDay(fraction: <= 0) => const _GapStub(),
      _ => _ValueBar(fraction: day.fraction),
    };

    return bar;
  }
}

class _ValueBar extends StatelessWidget {
  const _ValueBar({required this.fraction});

  static const _minHeight = 3.0;

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: (_barHeight * fraction).clamp(_minHeight, _barHeight),
      decoration: BoxDecoration(
        color: context.colors.action,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_barRadius),
        ),
      ),
    );
  }
}

class _GapStub extends StatelessWidget {
  const _GapStub();

  static const _stubHeight = 8.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _stubHeight,
      width: double.infinity,
      child: CustomPaint(
        key: const ValueKey('weekStripGapStub'),
        painter: GapStubPainter(color: context.colors.gap),
      ),
    );
  }
}
