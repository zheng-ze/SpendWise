import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/recurrence_picker.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import '../../../support/picker_sheet_harness.dart';
import '../../../support/sheet_contract.dart';
import '../../../support/ui_test_timeout.dart';

const _longLabel = 'A very long category name that must wrap at narrow widths';

const _groups = [
  PickerOption(
    id: 'food',
    label: _longLabel,
    children: [
      PickerOption(id: 'cafe', label: 'Cafe'),
      PickerOption(id: 'grocery', label: 'Grocery'),
    ],
  ),
  PickerOption(id: 'solo', label: 'Solo'),
];

const _outsideTap = Offset(5, 5);

const _dismissDrag = Offset(0, 700);

const _sizes = [phoneTallSize, phoneShortSize, desktopSize];

Future<PickerOpener<PickerOutcome>> _openGroups(
  WidgetTester tester,
  Size size,
) {
  return openPicker<PickerOutcome>(
    tester,
    size: size,
    open: (context) => showTwoColumnPickerSheet(
      context: context,
      title: 'Category',
      groups: _groups,
      sheetPresentation: presentationFor(size),
    ),
  );
}

Future<PickerOpener<RecurrenceFrequency?>> _openRecurrence(
  WidgetTester tester,
  Size size,
) {
  return openPicker<RecurrenceFrequency?>(
    tester,
    size: size,
    open: (context) => showRecurrencePickerSheet(
      context: context,
      selected: RecurrenceFrequency.monthly,
      sheetPresentation: presentationFor(size),
    ),
  );
}

Future<PickerOpener<DateTime>> _openDate(WidgetTester tester, Size size) {
  return openPicker<DateTime>(
    tester,
    size: size,
    open: (context) => showDatePickerSheet(
      context: context,
      presentation: presentationFor(size),
      title: 'Date',
      initialDate: DateTime(2026, 3, 10),
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    ),
  );
}

void main() {
  for (final size in _sizes) {
    group('at ${size.width.toInt()} x ${size.height.toInt()}', () {
      testWidgets('category sheet is capped without Cancel', (tester) async {
        await _openGroups(tester, size);

        expectAllSheetsCapped(tester, size);
        expect(find.text('Cancel'), findsNothing);
        expect(tester.takeException(), isNull);
      }, timeout: uiTestTimeout);

      testWidgets('recurrence sheet lists every option without overflow', (
        tester,
      ) async {
        await _openRecurrence(tester, size);

        expectAllSheetsCapped(tester, size);
        expect(find.text('One time'), findsOneWidget);
        expect(find.byType(ListTile), findsNWidgets(6));
        expect(tester.takeException(), isNull);
      }, timeout: uiTestTimeout);

      testWidgets('date sheet shows Today and Done without Cancel', (
        tester,
      ) async {
        await _openDate(tester, size);

        expectAllSheetsCapped(tester, size);
        expect(find.text('Cancel'), findsNothing);
        expect(find.byKey(pickerDoneKey), findsOneWidget);
        expect(find.byKey(pickerTodayKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, timeout: uiTestTimeout);
    });
  }

  testWidgets('narrow width stacks children under the expanded parent', (
    tester,
  ) async {
    await _openGroups(tester, phoneTallSize);

    await tester.tap(find.text(_longLabel));
    await tester.pumpAndSettle();

    final parentY = tester.getTopLeft(find.text(_longLabel)).dy;
    final childY = tester.getTopLeft(find.text('Cafe')).dy;
    expect(childY, greaterThan(parentY));
  }, timeout: uiTestTimeout);

  testWidgets('desktop width shows parent and child columns side by side', (
    tester,
  ) async {
    await _openGroups(tester, desktopSize);

    await tester.tap(find.text(_longLabel));
    await tester.pumpAndSettle();

    final parentX = tester.getTopLeft(find.text(_longLabel)).dx;
    final childX = tester.getTopLeft(find.text('Cafe')).dx;
    expect(childX, greaterThan(parentX));
  }, timeout: uiTestTimeout);

  testWidgets('choosing a child returns PickerChose with the child id', (
    tester,
  ) async {
    final opener = await _openGroups(tester, phoneTallSize);

    await tester.tap(find.text(_longLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grocery'));
    await tester.pumpAndSettle();

    expect((opener.result! as PickerChose).id, 'grocery');
  }, timeout: uiTestTimeout);

  testWidgets('tapping an expanded parent again selects the parent', (
    tester,
  ) async {
    final opener = await _openGroups(tester, phoneTallSize);

    await tester.tap(find.text(_longLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_longLabel));
    await tester.pumpAndSettle();

    expect((opener.result! as PickerChose).id, 'food');
  }, timeout: uiTestTimeout);

  testWidgets('dragging a picker down dismisses it on phone', (tester) async {
    final opener = await _openGroups(tester, phoneTallSize);

    await tester.drag(find.text('Category'), _dismissDrag);
    await tester.pumpAndSettle();

    expect(opener.completed, isTrue);
    expect(opener.result, isNull);
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('tapping outside dismisses every picker', (tester) async {
    final groups = await _openGroups(tester, phoneTallSize);
    await tester.tapAt(_outsideTap);
    await tester.pumpAndSettle();
    final recurrence = await _openRecurrence(tester, phoneTallSize);
    await tester.tapAt(_outsideTap);
    await tester.pumpAndSettle();
    final date = await _openDate(tester, phoneTallSize);
    await tester.tapAt(_outsideTap);
    await tester.pumpAndSettle();

    expect(groups.completed, isTrue);
    expect(recurrence.completed, isTrue);
    expect(date.completed, isTrue);
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('date header orders Today, centered title, Done', (tester) async {
    await _openDate(tester, phoneTallSize);

    final today = tester.getCenter(find.byKey(pickerTodayKey));
    final title = tester.getCenter(find.text('Date'));
    final done = tester.getCenter(find.byKey(pickerDoneKey));
    final sheet = tester.getCenter(find.byType(AppSheet));

    expect(today.dx, lessThan(title.dx));
    expect(title.dx, lessThan(done.dx));
    expect(title.dx, closeTo(sheet.dx, 0.5));
    expect(today.dy, closeTo(done.dy, 0.5));
  }, timeout: uiTestTimeout);

  testWidgets('recurrence choice returns the frequency', (tester) async {
    final opener = await _openRecurrence(tester, phoneTallSize);

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();

    expect(opener.result, RecurrenceFrequency.weekly);
  }, timeout: uiTestTimeout);

  testWidgets(
    'recurrence One time returns null and dismissal keeps selection',
    (tester) async {
      final chosen = await _openRecurrence(tester, phoneTallSize);
      await tester.tap(find.text('One time'));
      await tester.pumpAndSettle();
      final cancelled = await _openRecurrence(tester, phoneTallSize);
      await tester.tapAt(_outsideTap);
      await tester.pumpAndSettle();

      expect(chosen.completed, isTrue);
      expect(chosen.result, isNull);
      expect(cancelled.result, RecurrenceFrequency.monthly);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('date selection stays draft until Done', (tester) async {
    final opener = await _openDate(tester, phoneTallSize);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(opener.completed, isFalse);
    await tester.tap(find.byKey(pickerDoneKey));
    await tester.pumpAndSettle();

    expect(opener.result, DateTime(2026, 3, 15));
  }, timeout: uiTestTimeout);

  testWidgets('date dismissal discards the draft', (tester) async {
    final opener = await _openDate(tester, phoneTallSize);

    await tester.tap(find.text('15'));
    await tester.tapAt(_outsideTap);
    await tester.pumpAndSettle();

    expect(opener.completed, isTrue);
    expect(opener.result, isNull);
  }, timeout: uiTestTimeout);

  testWidgets('Today then Done returns the current day', (tester) async {
    final opener = await _openDate(tester, phoneTallSize);

    await tester.tap(find.byKey(pickerTodayKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(pickerDoneKey));
    await tester.pumpAndSettle();

    expect(opener.result, DateUtils.dateOnly(DateTime.now()));
  }, timeout: uiTestTimeout);

  testWidgets('without a sheet presentation the legacy sheet is used', (
    tester,
  ) async {
    await openPicker<PickerOutcome>(
      tester,
      size: phoneTallSize,
      open: (context) => showTwoColumnPickerSheet(
        context: context,
        title: 'Category',
        groups: _groups,
      ),
    );

    expect(find.byType(TwoColumnPickerSheet), findsOneWidget);
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('an expanded lower parent keeps its children in view', (
    tester,
  ) async {
    final groups = [
      for (var i = 0; i < 20; i++)
        PickerOption(
          id: 'p$i',
          label: 'Parent $i',
          children: [PickerOption(id: 'c$i', label: 'Child $i')],
        ),
    ];
    final opener = await openPicker<PickerOutcome>(
      tester,
      size: desktopSize,
      open: (context) => showTwoColumnPickerSheet(
        context: context,
        title: 'Account',
        groups: groups,
        sheetPresentation: presentationFor(desktopSize),
      ),
    );
    final parentScrollable = find
        .descendant(
          of: find.byType(PickerGroupBody),
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.scrollUntilVisible(
      find.text('Parent 18'),
      100,
      scrollable: parentScrollable,
    );
    await tester.tap(find.text('Parent 18'));
    await tester.pumpAndSettle();
    final child = find.text('Child 18');
    final viewport = Offset.zero & tester.view.physicalSize;

    expect(viewport.contains(tester.getCenter(child)), isTrue);
    await tester.tap(child);
    await tester.pumpAndSettle();
    expect((opener.result! as PickerChose).id, 'c18');
  }, timeout: uiTestTimeout);
}
