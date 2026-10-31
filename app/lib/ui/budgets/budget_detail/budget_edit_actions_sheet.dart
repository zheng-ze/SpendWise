import 'package:flutter/material.dart';

import 'package:spendwise/ui/budgets/budget_sheet_presentation.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
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
  return showAppSheet<BudgetEditAction>(
    context,
    presentation: budgetSheetPresentation(context),
    presentationResolver: budgetSheetPresentation,
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
        _ActionRow(
          icon: _changeLimitIcon,
          label: _changeLimitLabel,
          action: BudgetEditAction.changeLimit,
        ),
        _ActionRow(
          icon: _deleteIcon,
          label: _deleteLabel,
          action: BudgetEditAction.delete,
        ),
      ],
    );
    return const AppPickerSheet(title: _sheetTitle, body: rows);
  }
}

// MARK: - ActionRow
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.action,
  });

  final IconData icon;
  final String label;
  final BudgetEditAction action;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
