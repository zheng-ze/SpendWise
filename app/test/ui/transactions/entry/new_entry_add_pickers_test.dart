import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/ui_test_timeout.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import 'new_entry_session_harness.dart';

const _outsideTap = Offset(5, 5);

const _dismissDrag = Offset(0, 700);

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
  }, timeout: uiTestTimeout);

  testWidgets('pick-category dismissal keeps the category', (tester) async {
    final harness = await _openAdd(tester);
    harness.form.applyPickedCategory(coffeeId);

    await _request(tester, harness.form.requestPickCategory);
    await tester.tapAt(_outsideTap);
    await tester.pumpAndSettle();

    expect(harness.draft['category'], coffeeId);
  }, timeout: uiTestTimeout);

  testWidgets('pick-account applies the chosen account', (tester) async {
    final harness = await _openAdd(tester);

    await _request(tester, harness.form.requestPickSource);
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();

    expect(harness.draft['source'], checkingId);
  }, timeout: uiTestTimeout);

  testWidgets('pick-repeat applies a frequency and dismissal keeps it', (
    tester,
  ) async {
    final harness = await _openAdd(tester);

    await _request(tester, harness.form.requestPickRecurrence);
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await _request(tester, harness.form.requestPickRecurrence);
    await tester.tapAt(_outsideTap);
    await tester.pumpAndSettle();

    expect(harness.draft['recurrence'], RecurrenceFrequency.weekly);
  }, timeout: uiTestTimeout);

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
  }, timeout: uiTestTimeout);

  testWidgets('end date picker presents on AppSheet and dismissal keeps null', (
    tester,
  ) async {
    final harness = await _openAdd(tester);

    await _request(tester, harness.form.requestPickEndDate);
    expect(find.byType(AppSheet), findsNWidgets(2));
    await tester.tapAt(_outsideTap);
    await tester.pumpAndSettle();

    expect(harness.draft['endDate'], isNull);
  }, timeout: uiTestTimeout);

  testWidgets('desktop Add presents the picker as a desktop AppSheet', (
    tester,
  ) async {
    final harness = await _openAdd(tester, size: const Size(1440, 900));

    await _request(tester, harness.form.requestPickCategory);

    expect(find.byType(AppSheet), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets('an open picker follows a shrink to phone width live', (
    tester,
  ) async {
    final harness = await _openAdd(tester, size: openSize);

    await _request(tester, harness.form.requestPickCategory);
    final picker = find.byType(AppSheet).last;
    final before = AppSheetAlertSlot.maybeOf(tester.element(picker));
    await resize(tester, const Size(320, 760));
    final after = AppSheetAlertSlot.maybeOf(
      tester.element(find.byType(AppSheet).last),
    );

    expect(before?.presentation, AppSheetPresentation.open);
    expect(after?.presentation, AppSheetPresentation.phone);
    expect(find.text('Cancel'), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets('every Add picker has no Cancel and drags down to dismiss', (
    tester,
  ) async {
    final harness = await _openAdd(tester);
    final requests = [
      harness.form.requestPickCategory,
      harness.form.requestPickSource,
      harness.form.requestPickRecurrence,
      harness.form.requestPickDate,
      harness.form.requestPickEndDate,
    ];

    for (final request in requests) {
      await _request(tester, request);
      expect(find.byType(AppSheet), findsNWidgets(2));
      expect(find.text('Cancel'), findsNothing);
      await tester.drag(find.byType(AppPickerHeader), _dismissDrag);
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsOneWidget);
    }
  }, timeout: uiTestTimeout);
}
