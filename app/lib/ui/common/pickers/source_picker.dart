import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Source Picker
Future<PickerOutcome?> showSourcePickerSheet({
  required BuildContext context,
  required String title,
  required LedgerState state,
  String? selectedId,
  bool useRootNavigator = false,
  AppSheetPresentation? sheetPresentation,
}) {
  final groups = [
    for (final account in state.activeAccounts)
      PickerOption(
        id: account.id,
        label: account.name,
        children: [
          for (final pocket in state.activePockets(account))
            PickerOption(id: pocket.id, label: pocket.name),
        ],
      ),
  ];

  return showTwoColumnPickerSheet(
    context: context,
    title: title,
    groups: groups,
    selectedId: selectedId,
    useRootNavigator: useRootNavigator,
    sheetPresentation: sheetPresentation,
  );
}
