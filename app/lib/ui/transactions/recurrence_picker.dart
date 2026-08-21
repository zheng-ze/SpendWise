import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

const _oneTimeLabel = 'One time';

const Map<RecurrenceFrequency, String> frequencyLabels = {
  RecurrenceFrequency.weekly: 'Weekly',
  RecurrenceFrequency.biweekly: 'Biweekly',
  RecurrenceFrequency.monthly: 'Monthly',
  RecurrenceFrequency.quarterly: 'Quarterly',
  RecurrenceFrequency.yearly: 'Yearly',
};

/// Null means "one time", so the return value distinguishes a Cancel (the
/// dismissed sheet) from choosing "one time" (an explicit null answer).
Future<RecurrenceFrequency?> showRecurrencePickerSheet({
  required BuildContext context,
  RecurrenceFrequency? selected,
}) {
  return showModalBottomSheet<_RecurrenceOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RecurrencePickerSheet(selected: selected),
  ).then((outcome) => outcome == null ? selected : outcome.frequency);
}

@immutable
class _RecurrenceOutcome {
  const _RecurrenceOutcome(this.frequency);

  final RecurrenceFrequency? frequency;
}

class _RecurrencePickerSheet extends StatelessWidget {
  const _RecurrencePickerSheet({required this.selected});

  final RecurrenceFrequency? selected;

  Widget _title(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('Repeat', style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }

  List<Widget> _rows(BuildContext context) {
    return [
      _RecurrenceRow(
        label: _oneTimeLabel,
        selected: selected == null,
        onTap: () => Navigator.of(context).pop(const _RecurrenceOutcome(null)),
      ),
      for (final frequency in RecurrenceFrequency.values)
        _RecurrenceRow(
          label: frequencyLabels[frequency]!,
          selected: selected == frequency,
          onTap: () => Navigator.of(context).pop(_RecurrenceOutcome(frequency)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(context),
        Flexible(child: ListView(shrinkWrap: true, children: _rows(context))),
      ],
    );
  }
}

class _RecurrenceRow extends StatelessWidget {
  const _RecurrenceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
    );
  }
}
