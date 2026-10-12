import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';

void useSheetSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpAppSheet(
  WidgetTester tester,
  AppSheet sheet, {
  required AppSheetPresentation presentation,
  Size size = const Size(320, 760),
}) async {
  useSheetSize(tester, size);
  final app = MaterialApp(
    home: _ContractSheetOpener(
      sheet: sheet,
      label: 'open sheet',
      presentation: presentation,
    ),
  );
  await tester.pumpWidget(app);
  await tester.tap(find.text('open sheet'));
  await tester.pumpAndSettle();
}

class _ContractSheetOpener extends StatelessWidget {
  const _ContractSheetOpener({
    required this.sheet,
    required this.label,
    required this.presentation,
  });

  final AppSheet sheet;

  final String label;

  final AppSheetPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showAppSheet<void>(
        context,
        presentation: presentation,
        builder: (_) => sheet,
      ),
      child: Text(label),
    );
  }
}

double appSheetHeight(WidgetTester tester, [int index = 0]) =>
    tester.getSize(find.byType(AppSheet).at(index)).height;

void expectSheetCapped(WidgetTester tester, Size size, [int index = 0]) {
  expect(
    appSheetHeight(tester, index),
    lessThanOrEqualTo(0.66 * size.height + 1),
  );
}

void expectAllSheetsCapped(WidgetTester tester, Size size) {
  final count = find.byType(AppSheet).evaluate().length;
  expect(count, greaterThan(0));
  for (var i = 0; i < count; i++) {
    expectSheetCapped(tester, size, i);
  }
}

void expectAlertOutsideSheet(WidgetTester tester) {
  final banner = find.byType(SheetAlert);
  final insideSheet = find.ancestor(
    of: banner,
    matching: find.byType(AppSheet),
  );
  expect(banner, findsOneWidget);
  expect(insideSheet, findsNothing);
}
