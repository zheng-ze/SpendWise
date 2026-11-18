import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/inputs/statement_day_picker.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';

import '../../../support/picker_sheet_harness.dart';
import '../../../support/sheet_contract.dart';
import '../../../support/ui_test_timeout.dart';

Future<void> _openSheet(
  WidgetTester tester,
  ValueChanged<int> onSelected, {
  int? selected,
}) async {
  final picker = StatementDayPicker(
    selected: selected,
    onSelected: onSelected,
    sheetPresentation: presentationFor(phoneTallSize),
  );
  useSheetSize(tester, phoneTallSize);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: picker)));
  await tester.tap(find.text(selected?.toString() ?? 'Select'));
  await tester.pumpAndSettle();
}

void main() {
  group('parseStatementDay', () {
    test('accepts days 1 through 28 including both boundaries', () {
      expect(parseStatementDay('1'), 1);
      expect(parseStatementDay('15'), 15);
      expect(parseStatementDay('28'), 28);
    });

    test('rejects 0, 29 and above, blank and non-digit text', () {
      expect(parseStatementDay('0'), isNull);
      expect(parseStatementDay('29'), isNull);
      expect(parseStatementDay('99'), isNull);
      expect(parseStatementDay(''), isNull);
      expect(parseStatementDay('a1'), isNull);
    });
  });

  testWidgets('pressing Done applies the initial day and closes the sheet', (
    tester,
  ) async {
    final received = <int>[];
    await _openSheet(tester, received.add);
    expect(find.byType(AppPickerSheet), findsOneWidget);

    await tester.tap(find.byKey(pickerDoneKey));
    await tester.pumpAndSettle();

    expect(received, [1]);
    expect(find.byType(AppPickerSheet), findsNothing);
  }, timeout: uiTestTimeout);
}
