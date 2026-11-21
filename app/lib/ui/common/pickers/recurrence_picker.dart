import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/choice_tile.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants
const _titleLabel = 'Repeat';

const addNoRepeatLabel = 'Does not repeat';

const Map<RecurrenceFrequency, String> addFrequencyLabels = {
  RecurrenceFrequency.weekly: 'Every week',
  RecurrenceFrequency.biweekly: 'Every two weeks',
  RecurrenceFrequency.monthly: 'Every month',
  RecurrenceFrequency.quarterly: 'Every three months',
  RecurrenceFrequency.yearly: 'Every year',
};

// MARK: - Show

Future<RecurrenceFrequency?> showRecurrencePickerSheet({
  required BuildContext context,
  required AppSheetPresentation Function(BuildContext) sheetPresentation,
  RecurrenceFrequency? selected,
  bool includesNoRepeat = true,
  PickerRouteCallback? onRouteCreated,
}) {
  final outcome = showPickerAppSheet<_RecurrenceOutcome>(
    context,
    presentation: sheetPresentation,
    onRouteCreated: onRouteCreated,
    builder: (_) => AppPickerSheet(
      title: _titleLabel,
      body: Column(
        children: _recurrenceRows(selected, includesNoRepeat: includesNoRepeat),
      ),
    ),
  );
  return outcome.then((chosen) => chosen == null ? selected : chosen.frequency);
}

// MARK: - RecurrenceOutcome
@immutable
class _RecurrenceOutcome {
  const _RecurrenceOutcome(this.frequency);

  final RecurrenceFrequency? frequency;
}

// MARK: - Rows
List<Widget> _recurrenceRows(
  RecurrenceFrequency? selected, {
  required bool includesNoRepeat,
}) {
  return [
    if (includesNoRepeat)
      ChoiceTile<_RecurrenceOutcome>(
        label: addNoRepeatLabel,
        value: const _RecurrenceOutcome(null),
        selected: selected == null,
      ),
    for (final frequency in RecurrenceFrequency.values)
      ChoiceTile<_RecurrenceOutcome>(
        label: addFrequencyLabels[frequency]!,
        value: _RecurrenceOutcome(frequency),
        selected: selected == frequency,
      ),
  ];
}
