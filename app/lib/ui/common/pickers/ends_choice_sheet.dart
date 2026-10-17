import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants
const _titleLabel = 'Ends';

const _neverLabel = 'Never';

const _chooseDateLabel = 'Choose date';

// MARK: - EndsChoice
enum EndsChoice { never, chooseDate }

// MARK: - Show
Future<EndsChoice?> showEndsChoiceSheet({
  required BuildContext context,
  required AppSheetPresentation Function(BuildContext) presentation,
  required bool hasEndDate,
}) {
  return showPickerAppSheet<EndsChoice>(
    context,
    presentation: presentation,
    builder: (_) => AppPickerSheet(
      title: _titleLabel,
      body: Column(
        children: [
          _EndsChoiceRow(
            label: _neverLabel,
            choice: EndsChoice.never,
            selected: !hasEndDate,
          ),
          _EndsChoiceRow(
            label: _chooseDateLabel,
            choice: EndsChoice.chooseDate,
            selected: hasEndDate,
          ),
        ],
      ),
    ),
  );
}

// MARK: - EndsChoiceRow
class _EndsChoiceRow extends StatelessWidget {
  const _EndsChoiceRow({
    required this.label,
    required this.choice,
    required this.selected,
  });

  final String label;
  final EndsChoice choice;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.of(context).pop(choice),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
    );
  }
}
