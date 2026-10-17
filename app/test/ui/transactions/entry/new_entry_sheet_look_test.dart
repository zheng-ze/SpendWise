import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../../support/sheet_probe.dart';
import 'new_entry_session_harness.dart';
import '../../../support/ui_test_timeout.dart';

const _desktopWindow = Size(1440, 900);
const _desktopDialogWidth = 340.0;
const _desktopDialogRadius = 18.0;
const _groupRadius = 14.0;
const _segmentGap = 2.0;
const _lightTopBorder = 1.0;
const _handleWidth = 34.0;
const _handleHeight = 4.0;

Finder get _handle => find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.constraints ==
          const BoxConstraints.tightFor(
            width: _handleWidth,
            height: _handleHeight,
          ),
);

Future<EntryHarness> _open(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Size size = phoneSize,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  final theme = buildSpendWiseTheme(brightness);
  final harness = await pumpShell(
    tester,
    size: size,
    platform: platform,
    theme: theme,
  );
  await openAdd(tester, harness);
  return harness;
}

BoxDecoration _chromeDecoration(WidgetTester tester) {
  final chrome = find
      .descendant(of: sheetSurface, matching: find.byType(Container))
      .first;
  return tester.widget<Container>(chrome).decoration! as BoxDecoration;
}

Rect _segmentRect(WidgetTester tester, String label) {
  final segment = find.ancestor(
    of: find.text(label),
    matching: find.byType(InkWell),
  );
  return tester.getRect(segment.first);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('phone backing', () {
    testWidgets('light Add sheets sit on the canvas with an edge hairline', (
      tester,
    ) async {
      await _open(tester);

      final decoration = _chromeDecoration(tester);
      final border = decoration.border! as Border;
      expect(
        tester.widget<Material>(sheetSurface).color,
        SpendWiseColors.light.base,
      );
      expect(border.top.color, SpendWiseColors.light.edge);
      expect(border.top.width, _lightTopBorder);
      expect(decoration.boxShadow, isNotEmpty);
      expect(_handle, findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('dark Add sheets keep the raised backing', (tester) async {
      await _open(tester, brightness: Brightness.dark);

      final decoration = _chromeDecoration(tester);
      expect(
        tester.widget<Material>(sheetSurface).color,
        SpendWiseColors.dark.raised,
      );
      expect(decoration.boxShadow, isNull);
    }, timeout: uiTestTimeout);
  });

  group('desktop dialog', () {
    testWidgets('uses the reference geometry without a handle', (tester) async {
      await _open(tester, size: _desktopWindow, platform: TargetPlatform.macOS);

      final radius = _chromeDecoration(tester).borderRadius;
      expect(tester.getSize(sheetSurface).width, _desktopDialogWidth);
      expect(radius, BorderRadius.circular(_desktopDialogRadius));
      expect(_handle, findsNothing);
    }, timeout: uiTestTimeout);
  });

  group('form details', () {
    testWidgets('segments keep their height and a 2 dp gap when selected', (
      tester,
    ) async {
      await _open(tester);
      final expense = _segmentRect(tester, 'Expense');
      final income = _segmentRect(tester, 'Income');

      expect(expense.height, income.height);
      expect(income.left - expense.right, _segmentGap);
    }, timeout: uiTestTimeout);

    testWidgets('the form group uses the reference radius', (tester) async {
      await _open(tester);

      final group = find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.shape is RoundedRectangleBorder &&
            (widget.shape! as RoundedRectangleBorder).borderRadius ==
                BorderRadius.circular(_groupRadius),
      );
      expect(group, findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('the sheet surface is the Add form variant', (tester) async {
      await _open(tester);

      final sheet = tester.widget<AppSheet>(find.byType(AppSheet));
      expect(sheet.variant, AppSheetVariant.form);
    }, timeout: uiTestTimeout);
  });
}
