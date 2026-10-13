import 'package:flutter/material.dart';

import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/format/color_hex.dart';

// MARK: - Constants
const budgetFormOverallSentinel = '__overall__';

const _rootCategoryIconSize = 24.0;
const _childCategoryIconSize = 20.0;
const _childRowIndent = 32.0;
const _rootNameWeight = FontWeight.w600;

// MARK: - Category Picker Sheet
Future<String?> showBudgetCategoryPickerSheet({
  required BuildContext context,
  required BudgetFormViewState formState,
}) {
  final groups = formState.groupedCategories;
  final budgeted = formState.budgetedCategoryIDs;

  final overallTile = ListTile(
    title: const Text('Overall'),
    onTap: () => Navigator.of(context).pop(budgetFormOverallSentinel),
  );
  final categoryRows = [
    for (final (root, children) in groups) ...[
      ListTile(
        leading: CategoryIcon(
          symbolName: root.symbol,
          color: parseColorHex(root.colorHex),
          size: _rootCategoryIconSize,
        ),
        title: Text(
          root.name,
          style: const TextStyle(fontWeight: _rootNameWeight),
        ),
        enabled: !budgeted.contains(root.id),
        onTap: () => Navigator.of(context).pop(root.id),
      ),
      for (final child in children)
        Padding(
          padding: const EdgeInsets.only(left: _childRowIndent),
          child: ListTile(
            leading: CategoryIcon(
              symbolName: child.symbol,
              color: parseColorHex(child.colorHex),
              size: _childCategoryIconSize,
            ),
            title: Text(
              child.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            onTap: () => Navigator.of(context).pop(child.id),
          ),
        ),
    ],
  ];

  return showModalBottomSheet<String?>(
    context: context,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [overallTile, ...categoryRows],
      ),
    ),
  );
}
