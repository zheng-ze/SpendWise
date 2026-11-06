import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';

const _expectedPresentations = {
  ShellLayoutMode.phone: AppSheetPresentation.phone,
  ShellLayoutMode.open: AppSheetPresentation.open,
  ShellLayoutMode.desktop: AppSheetPresentation.desktop,
};

Future<AppSheetPresentation> _resolveWithin(
  WidgetTester tester, {
  ShellLayoutMode? mode,
}) async {
  late AppSheetPresentation presentation;
  final probe = Builder(
    builder: (context) {
      presentation = shellSheetPresentation(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(
    mode == null ? probe : ShellLayoutModeScope(mode: mode, child: probe),
  );
  return presentation;
}

void main() {
  group('sheetPresentationForMode', () {
    for (final entry in _expectedPresentations.entries) {
      test('maps ${entry.key.name} to ${entry.value.name}', () {
        expect(sheetPresentationForMode(entry.key), entry.value);
      });
    }
  });

  group('shellSheetPresentation', () {
    testWidgets('reads the mode from the shell scope', (tester) async {
      final presentation = await _resolveWithin(
        tester,
        mode: ShellLayoutMode.desktop,
      );
      expect(presentation, AppSheetPresentation.desktop);
    });

    testWidgets('falls back to phone without a shell scope', (tester) async {
      final presentation = await _resolveWithin(tester);
      expect(presentation, AppSheetPresentation.phone);
    });
  });
}
