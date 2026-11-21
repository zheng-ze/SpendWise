import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/choice_tile.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants
const _sheetTitle = 'Edit budget';
const _changeLimitLabel = 'Change limit';
const _deleteLabel = 'Delete budget';

const _changeLimitIcon = Icons.edit_outlined;
const _deleteIcon = Icons.delete_outline;

// MARK: - Actions
enum BudgetEditAction { changeLimit, delete }

// MARK: - Edit Actions Sheet
Future<BudgetEditAction?> showBudgetEditActionsSheet({
  required BuildContext context,
  required void Function(AppSheetRoute<BudgetEditAction>) onRouteCreated,
}) {
  return showPickerAppSheet<BudgetEditAction>(
    context,
    presentation: shellSheetPresentation,
    onRouteCreated: onRouteCreated,
    builder: (_) => const _BudgetEditActions(),
  );
}

// MARK: - BudgetEditActions
class _BudgetEditActions extends StatelessWidget {
  const _BudgetEditActions();

  @override
  Widget build(BuildContext context) {
    const rows = Column(
      children: [
        ChoiceTile<BudgetEditAction>(
          leading: _changeLimitIcon,
          label: _changeLimitLabel,
          value: BudgetEditAction.changeLimit,
        ),
        ChoiceTile<BudgetEditAction>(
          leading: _deleteIcon,
          label: _deleteLabel,
          value: BudgetEditAction.delete,
        ),
      ],
    );
    return const AppPickerSheet(title: _sheetTitle, body: rows);
  }
}
