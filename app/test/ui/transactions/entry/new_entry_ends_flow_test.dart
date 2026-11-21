import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import '../../../support/row_tap.dart';
import '../../../support/ui_test_timeout.dart';
import 'new_entry_session_harness.dart';

const _everyMonth = 'Every month';
const _chooseDate = 'Choose date';

Finder _entryRow(String key) => find.byKey(ValueKey('new-entry-$key'));

Future<void> _makeRecurring(WidgetTester tester) async {
  await tapRow(tester, _entryRow('repeat'), scrollIntoView: true);
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
    await tapRow(tester, _entryRow('ends'), scrollIntoView: true);

    addDismiss(tester)();
    await tester.pumpAndSettle();
    await tester.tap(find.text(_chooseDate));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerSheet), findsNothing);
    expect(find.byType(AppSheet), findsNothing);
    await harness.opened;
  }, timeout: uiTestTimeout);
}
