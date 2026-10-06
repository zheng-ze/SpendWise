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
        : Container(
            key: const ValueKey('weekStripGapStub'),
            height: 8,
            decoration: BoxDecoration(
              border: Border.all(color: colors.gap, width: 1.5),
              borderRadius: BorderRadius.circular(2),
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
