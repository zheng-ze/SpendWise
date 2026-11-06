import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
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
        children: _recurrenceRows(
          selected,
          includesNoRepeat: includesNoRepeat,
          oneTimeLabel: addNoRepeatLabel,
          labels: addFrequencyLabels,
        ),
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
  required String oneTimeLabel,
  required Map<RecurrenceFrequency, String> labels,
}) {
  return [
    if (includesNoRepeat)
      _RecurrenceRow(
        label: oneTimeLabel,
        selected: selected == null,
        outcome: const _RecurrenceOutcome(null),
      ),
    for (final frequency in RecurrenceFrequency.values)
      _RecurrenceRow(
        label: labels[frequency]!,
        selected: selected == frequency,
        outcome: _RecurrenceOutcome(frequency),
      ),
  ];
}

// MARK: - RecurrenceRow
class _RecurrenceRow extends StatelessWidget {
  const _RecurrenceRow({
    required this.label,
    required this.selected,
    required this.outcome,
  });

  final String label;
  final bool selected;
  final _RecurrenceOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.of(context).pop(outcome),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
    );
  }
}
