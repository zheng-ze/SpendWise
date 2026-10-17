import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import 'new_entry_session_harness.dart';

Future<EntryHarness> _openAdd(WidgetTester tester, {Size? size}) async {
  final harness = await pumpShell(tester, size: size ?? phoneSize);
  await openAdd(tester, harness);
  return harness;
}

Future<void> _request(WidgetTester tester, VoidCallback request) async {
  request();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pick-category presents an AppSheet above Add and applies it', (
    tester,
  ) async {
    final harness = await _openAdd(tester);

    await _request(tester, harness.form.requestPickCategory);
    expect(find.byType(AppSheet), findsNWidgets(2));
    expect(find.byType(TwoColumnPickerSheet), findsNothing);
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    expect(harness.draft['category'], coffeeId);
    expect(find.byType(AppSheet), findsOneWidget);
  });

  testWidgets('pick-category None clears and Cancel keeps the category', (
    tester,
  ) async {
    final harness = await _openAdd(tester);
    harness.form.applyPickedCategory(coffeeId);

    await _request(tester, harness.form.requestPickCategory);
    await tester.tap(find.byKey(pickerCancelKey));
    await tester.pumpAndSettle();
    expect(harness.draft['category'], coffeeId);
    await _request(tester, harness.form.requestPickCategory);
    await tester.tap(find.byKey(pickerNoneKey));
    await tester.pumpAndSettle();

    expect(harness.draft['category'], isNull);
  });

  testWidgets('pick-account applies the chosen account', (tester) async {
    final harness = await _openAdd(tester);

    await _request(tester, harness.form.requestPickSource);
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();

    expect(harness.draft['source'], checkingId);
  });

  testWidgets('pick-repeat applies a frequency and Cancel keeps it', (
    tester,
  ) async {
    final harness = await _openAdd(tester);

    await _request(tester, harness.form.requestPickRecurrence);
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await _request(tester, harness.form.requestPickRecurrence);
    await tester.tap(find.byKey(pickerCancelKey));
    await tester.pumpAndSettle();

    expect(harness.draft['recurrence'], RecurrenceFrequency.weekly);
  });

  testWidgets('pick-date stores UTC midnight of the chosen day', (
    tester,
  ) async {
    final harness = await _openAdd(tester);

    await _request(tester, harness.form.requestPickDate);
    await tester.tap(find.text('1').first);
    await tester.tap(find.byKey(pickerDoneKey));
    await tester.pumpAndSettle();

    final date = harness.draft['date']! as DateTime;
    expect(date.isUtc, isTrue);
    expect(date, startOfDayUtc(date));
    expect(date.day, 1);
  });

  testWidgets('end date picker presents on AppSheet and Cancel keeps null', (
    tester,
  ) async {
    final harness = await _openAdd(tester);

    await _request(tester, harness.form.requestPickEndDate);
    expect(find.byType(AppSheet), findsNWidgets(2));
    await tester.tap(find.byKey(pickerCancelKey));
    await tester.pumpAndSettle();

    expect(harness.draft['endDate'], isNull);
  });

  testWidgets('desktop Add presents the picker as a desktop AppSheet', (
    tester,
  ) async {
    final harness = await _openAdd(tester, size: const Size(1440, 900));

    await _request(tester, harness.form.requestPickCategory);

    expect(find.byType(AppSheet), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
