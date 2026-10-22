import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import '../../../support/ui_test_timeout.dart';
import 'new_entry_session_harness.dart';

const _everyMonth = 'Every month';
const _chooseDate = 'Choose date';

Future<void> _tapRow(WidgetTester tester, String key) async {
  final row = find.byKey(ValueKey('new-entry-$key'));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> _makeRecurring(WidgetTester tester) async {
  await _tapRow(tester, 'repeat');
  await tester.tap(find.text(_everyMonth));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a retired Add opens no calendar after the Ends choice', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    await openAdd(tester, harness);
    await _makeRecurring(tester);
    await _tapRow(tester, 'ends');

    addDismiss(tester)();
    await tester.pumpAndSettle();
    await tester.tap(find.text(_chooseDate));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerSheet), findsNothing);
    expect(find.byType(AppSheet), findsNothing);
    await harness.opened;
  }, timeout: uiTestTimeout);
}
