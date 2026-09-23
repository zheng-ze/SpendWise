import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/date_format.dart';

Widget monthAxisTick(TextStyle? style, List<DateTime> months, double value) {
  final index = value.round();
  if (index < 0 || index >= months.length) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(formatMonthLabel(months[index]).substring(0, 3), style: style),
  );
}
