import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';

const _dismissDrag = Offset(0, 900);

const _outsideTap = Offset(5, 5);

Future<void> dismissAddSheet(WidgetTester tester) async {
  final sheet = tester.element(find.byType(AppSheet).last);
  final presentation = AppSheetAlertSlot.maybeOf(sheet)?.presentation;
  if (presentation == AppSheetPresentation.phone) {
    await tester.drag(find.text('Add entry'), _dismissDrag);
  } else {
    await tester.tapAt(_outsideTap);
  }
  await tester.pumpAndSettle();
}
