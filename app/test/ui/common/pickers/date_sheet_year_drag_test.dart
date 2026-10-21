import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';

import '../../../support/picker_sheet_harness.dart';
import '../../../support/ui_test_timeout.dart';

const _yearToggleLabel = 'March 2000';

Future<PickerOpener<DateTime>> _openDateSheet(WidgetTester tester) async {
  final opener = await openPicker<DateTime>(
    tester,
    size: phoneTallSize,
    open: (context) => showDatePickerSheet(
      context: context,
      presentation: presentationFor(phoneTallSize),
      title: 'Date',
      initialDate: DateTime(2000, 3, 10),
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    ),
  );
  await tester.tap(find.text(_yearToggleLabel));
  await tester.pumpAndSettle();
  return opener;
}

void main() {
  testWidgets('dragging from the year grid dismisses the date sheet', (
    tester,
  ) async {
    final opener = await _openDateSheet(tester);
    await tester.drag(find.byType(YearPicker), const Offset(0, 700));
    await tester.pumpAndSettle();

    expect(opener.completed, isTrue);
    expect(find.byType(DatePickerSheet), findsNothing);
  }, timeout: uiTestTimeout);
}
