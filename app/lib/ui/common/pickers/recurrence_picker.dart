import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants
const _oneTimeLabel = 'One time';

const _titleLabel = 'Repeat';

const Map<RecurrenceFrequency, String> frequencyLabels = {
  RecurrenceFrequency.weekly: 'Weekly',
  RecurrenceFrequency.biweekly: 'Biweekly',
  RecurrenceFrequency.monthly: 'Monthly',
  RecurrenceFrequency.quarterly: 'Quarterly',
  RecurrenceFrequency.yearly: 'Yearly',
};

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
  RecurrenceFrequency? selected,
  bool useRootNavigator = false,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
}) {
  final outcome = sheetPresentation == null
      ? showModalBottomSheet<_RecurrenceOutcome>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          useRootNavigator: useRootNavigator,
          builder: (_) => _RecurrencePickerSheet(selected: selected),
        )
      : showPickerAppSheet<_RecurrenceOutcome>(
          context,
          presentation: sheetPresentation,
          builder: (_) => AppPickerSheet(
            title: _titleLabel,
            body: Column(
              children: _recurrenceRows(
                selected,
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
  String oneTimeLabel = _oneTimeLabel,
  Map<RecurrenceFrequency, String> labels = frequencyLabels,
}) {
  return [
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

// MARK: - RecurrencePickerSheet
class _RecurrencePickerSheet extends StatelessWidget {
  const _RecurrencePickerSheet({required this.selected});

  final RecurrenceFrequency? selected;

  static const _titlePadding = EdgeInsets.fromLTRB(16, 16, 16, 8);

  Widget _title(BuildContext context) {
    return Padding(
      padding: _titlePadding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _titleLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(context),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: _recurrenceRows(selected),
          ),
        ),
      ],
    );
  }
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
