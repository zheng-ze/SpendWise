import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

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

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)),
      );
    final dashed = Path();
    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 4).clamp(0.0, metric.length);
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += 7;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant GapStubPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day});

  final WeekStripDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bar = day.future
        ? const SizedBox(height: 40)
        : day.fraction > 0
        ? Container(
            height: (40 * day.fraction).clamp(3.0, 40.0),
            decoration: BoxDecoration(
              color: colors.action,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          )
        : SizedBox(
            height: 8,
            width: double.infinity,
            child: CustomPaint(
              key: const ValueKey('weekStripGapStub'),
              painter: GapStubPainter(color: colors.gap),
            ),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(widthFactor: 0.48, child: bar),
          ),
        ),
        Text(
          day.label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          day.caption,
          style: TextStyle(fontSize: 10, color: colors.subtext),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
