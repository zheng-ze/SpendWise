import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/date_format.dart';

// MARK: - Constants
const _tickTopPadding = 4.0;
const _monthLabelCharacterCount = 3;

// MARK: - Helpers
Widget monthAxisTick(TextStyle? style, List<DateTime> months, double value) {
  final index = value.round();
  if (index < 0 || index >= months.length) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: _tickTopPadding),
    child: Text(
      formatMonthLabel(months[index]).substring(0, _monthLabelCharacterCount),
      style: style,
    ),
  );
}
