import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';

const _expectedPresentations = {
  ShellLayoutMode.phone: AppSheetPresentation.phone,
  ShellLayoutMode.open: AppSheetPresentation.open,
  ShellLayoutMode.desktop: AppSheetPresentation.desktop,
};

void main() {
  group('sheetPresentationForMode', () {
    for (final entry in _expectedPresentations.entries) {
      test('maps ${entry.key.name} to ${entry.value.name}', () {
        expect(sheetPresentationForMode(entry.key), entry.value);
      });
    }
  });
}
