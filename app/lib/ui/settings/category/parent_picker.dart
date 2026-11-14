import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants
const _titleLabel = 'Inside which category?';

const topLevelLabel = 'Top level';

// MARK: - ParentChoice
class ParentChoice {
  const ParentChoice(this.parentID);

  final String? parentID;
}

// MARK: - Show
Future<ParentChoice?> showParentPickerSheet({
  required BuildContext context,
  required AppSheetPresentation Function(BuildContext) presentation,
  required List<TransactionCategory> parents,
  required String? currentParentID,
  PickerRouteCallback? onRouteCreated,
}) {
  final topLevel = _ParentRow(
    label: topLevelLabel,
    choice: const ParentChoice(null),
    selected: currentParentID == null,
  );
  final rows = [
    topLevel,
    for (final parent in parents)
      _ParentRow(
        label: parent.name,
        choice: ParentChoice(parent.id),
        selected: parent.id == currentParentID,
      ),
  ];
  final sheet = AppPickerSheet(
    title: _titleLabel,
    body: SingleChildScrollView(child: Column(children: rows)),
  );
  return showPickerAppSheet<ParentChoice>(
    context,
    presentation: presentation,
    onRouteCreated: onRouteCreated,
    builder: (_) => sheet,
  );
}

// MARK: - ParentRow
class _ParentRow extends StatelessWidget {
  const _ParentRow({
    required this.label,
    required this.choice,
    required this.selected,
  });

  final String label;
  final ParentChoice choice;
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
