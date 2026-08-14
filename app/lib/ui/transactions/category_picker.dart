import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/two_column_picker_sheet.dart';
import 'package:spendwise/ui/format/color_hex.dart';

/// Transfers have no category, so this sheet is never shown for a transfer
/// entry: the caller gates it, not this function.
Future<PickerOutcome?> showCategoryPickerSheet({
  required BuildContext context,
  required LedgerState state,
  required CategoryKind kind,
  String? selectedId,
}) {
  final ofKind = state.categories.values.where(
    (category) => category.kind == kind && category.lifecycle.isActive,
  );
  final roots = ofKind.where((category) => category.parentID == null).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final byParent = <String, List<TransactionCategory>>{};
  for (final category in ofKind) {
    final parentID = category.parentID;
    if (parentID == null) continue;
    (byParent[parentID] ??= []).add(category);
  }
  for (final children in byParent.values) {
    children.sort((a, b) => a.name.compareTo(b.name));
  }

  final groups = [
    for (final root in roots)
      PickerOption(
        id: root.id,
        label: root.name,
        leading: CategoryIcon(
          symbolName: root.symbol,
          color: parseColorHex(root.colorHex),
          size: 28,
        ),
        children: [
          for (final child
              in byParent[root.id] ?? const <TransactionCategory>[])
            PickerOption(
              id: child.id,
              label: child.name,
              leading: CategoryIcon(
                symbolName: child.symbol,
                color: parseColorHex(child.colorHex),
                size: 24,
              ),
            ),
        ],
      ),
  ];

  return showTwoColumnPickerSheet(
    context: context,
    title: 'Category',
    groups: groups,
    selectedId: selectedId,
    allowsNone: true,
  );
}
