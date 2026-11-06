import 'package:flutter/widgets.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

AppSheetPresentation sheetPresentationForMode(ShellLayoutMode mode) =>
    switch (mode) {
      ShellLayoutMode.phone => AppSheetPresentation.phone,
      ShellLayoutMode.open => AppSheetPresentation.open,
      ShellLayoutMode.desktop => AppSheetPresentation.desktop,
    };

AppSheetPresentation shellSheetPresentation(BuildContext context) =>
    sheetPresentationForMode(
      ShellLayoutModeScope.maybeOf(context) ?? ShellLayoutMode.phone,
    );
