import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/date_format.dart';

enum MonthYearStep { month, year }

class MonthYearSelector extends StatelessWidget {
  const MonthYearSelector({
    super.key,
    required this.value,
    required this.step,
    required this.onChanged,
  });

  final DateTime value;
  final MonthYearStep step;
  final ValueChanged<DateTime> onChanged;

  DateTime _shifted(int direction) {
    final months = step == MonthYearStep.month ? direction : direction * 12;
    return shiftMonthThenClampDayUtc(value, months, day: 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = step == MonthYearStep.month
        ? formatMonthLabel(value)
        : formatYearLabel(value);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onChanged(_shifted(-1)),
          icon: const Icon(Icons.chevron_left),
          tooltip: step == MonthYearStep.month
              ? 'Previous month'
              : 'Previous year',
        ),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        IconButton(
          onPressed: () => onChanged(_shifted(1)),
          icon: const Icon(Icons.chevron_right),
          tooltip: step == MonthYearStep.month ? 'Next month' : 'Next year',
        ),
      ],
    );
  }
}
