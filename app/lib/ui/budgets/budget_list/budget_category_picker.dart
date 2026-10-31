import 'package:flutter/material.dart';

import 'package:spendwise/ui/budgets/budget_list/budget_scope_options.dart';
import 'package:spendwise/ui/budgets/budget_sheet_presentation.dart';
import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/color_hex.dart';

// MARK: - Constants
const _pickerTitle = 'Choose category';
const _budgetedSubtitle = 'Has a budget';

const _rootCategoryIconSize = 24.0;
const _childCategoryIconSize = 20.0;
const _childRowIndent = 32.0;
const _rootNameWeight = FontWeight.w600;
const _checkIcon = Icons.check;

// MARK: - Category Picker Sheet
Future<BudgetScopeChoice?> showBudgetCategoryPickerSheet({
  required BuildContext context,
  required List<BudgetScopeOption> options,
  required BudgetScopeChoice? selected,
}) {
  return showAppSheet<BudgetScopeChoice>(
    context,
    presentation: budgetSheetPresentation(context),
    presentationResolver: budgetSheetPresentation,
    builder: (_) => _BudgetCategoryPicker(options: options, selected: selected),
  );
}

// MARK: - BudgetCategoryPicker
class _BudgetCategoryPicker extends StatelessWidget {
  const _BudgetCategoryPicker({required this.options, required this.selected});

  final List<BudgetScopeOption> options;
  final BudgetScopeChoice? selected;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final option in options)
        _ScopeRow(option: option, selected: option.choice == selected),
    ];
    return AppPickerSheet(
      title: _pickerTitle,
      body: Column(children: rows),
    );
  }
}

// MARK: - ScopeRow
class _ScopeRow extends StatelessWidget {
  const _ScopeRow({required this.option, required this.selected});

  final BudgetScopeOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final category = option.category;
    final isChild = option.isChild;
    final leading = category == null
        ? null
        : CategoryIcon(
            symbolName: category.symbol,
            color: parseColorHex(category.colorHex),
            size: isChild ? _childCategoryIconSize : _rootCategoryIconSize,
          );
    final title = Text(
      option.label,
      style: isChild
          ? Theme.of(context).textTheme.bodyMedium
          : const TextStyle(fontWeight: _rootNameWeight),
    );
    final tile = ListTile(
      leading: leading,
      title: title,
      subtitle: option.disabled ? const Text(_budgetedSubtitle) : null,
      trailing: selected ? const Icon(_checkIcon) : null,
      enabled: !option.disabled,
      onTap: () => Navigator.of(context).pop(option.choice),
    );
    if (!isChild) return tile;
    return Padding(
      padding: const EdgeInsets.only(left: _childRowIndent),
      child: tile,
    );
  }
}
