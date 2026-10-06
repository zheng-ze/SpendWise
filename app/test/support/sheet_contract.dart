import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/app_sheet.dart';
import 'package:spendwise/ui/common/sheet_alert.dart';

void useSheetSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpAppSheet(
  WidgetTester tester,
  AppSheet sheet, {
  Size size = const Size(320, 760),
}) async {
  useSheetSize(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppSheet<void>(context, builder: (_) => sheet),
          child: const Text('open sheet'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open sheet'));
  await tester.pumpAndSettle();
}

double appSheetHeight(WidgetTester tester) =>
    tester.getSize(find.byType(AppSheet)).height;

void expectSheetCapped(WidgetTester tester, Size size) {
  expect(appSheetHeight(tester), lessThanOrEqualTo(0.66 * size.height + 1));
}

void expectAlertOutsideSheet(WidgetTester tester) {
  expect(find.byType(SheetAlert), findsOneWidget);
  expect(
    find.ancestor(of: find.byType(SheetAlert), matching: find.byType(AppSheet)),
    findsNothing,
  );
}
