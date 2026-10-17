import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';

import '../../../support/picker_sheet_harness.dart';
import '../../../support/ui_test_timeout.dart';

const _yearToggleLabel = 'March 2026';
const _smallDrag = 40.0;
const _headerDrag = 120.0;
const _moveTolerance = 1.0;
const _dismissDrag = Offset(0, 700);

Future<PickerOpener<DateTime>> _openDateSheet(WidgetTester tester) async {
  final opener = await openPicker<DateTime>(
    tester,
    size: phoneTallSize,
    open: (context) => showDatePickerSheet(
      context: context,
      presentation: presentationFor(phoneTallSize),
      title: 'Date',
      initialDate: DateTime(2026, 3, 10),
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    ),
  );
  await tester.tap(find.text(_yearToggleLabel));
  await tester.pumpAndSettle();
  return opener;
}

ScrollPosition _yearScroll(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byType(YearPicker),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable).position;
}

double _sheetTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(AppPickerHeader)).dy;

void main() {
  testWidgets('a down drag inside a scrolled year grid scrolls the grid only', (
    tester,
  ) async {
    await _openDateSheet(tester);
    final position = _yearScroll(tester);
    final restingTop = _sheetTop(tester);
    final scrolledBefore = position.pixels;
    expect(scrolledBefore, greaterThan(_smallDrag));

    await tester.drag(find.byType(YearPicker), const Offset(0, _smallDrag));
    await tester.pumpAndSettle();

    expect(position.pixels, lessThan(scrolledBefore));
    expect(_sheetTop(tester), closeTo(restingTop, _moveTolerance));
  }, timeout: uiTestTimeout);

  testWidgets('a down drag at the first year moves the sheet', (tester) async {
    await _openDateSheet(tester);
    final position = _yearScroll(tester);
    position.jumpTo(position.minScrollExtent);
    await tester.pumpAndSettle();
    final restingTop = _sheetTop(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(YearPicker)),
    );
    await gesture.moveBy(const Offset(0, _headerDrag));
    await gesture.moveBy(const Offset(0, _headerDrag));
    await tester.pump();

    expect(_sheetTop(tester), greaterThan(restingTop + _moveTolerance));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_sheetTop(tester), closeTo(restingTop, _moveTolerance));
  }, timeout: uiTestTimeout);

  testWidgets('a long down drag at the first year dismisses the sheet', (
    tester,
  ) async {
    final opener = await _openDateSheet(tester);
    final position = _yearScroll(tester);
    position.jumpTo(position.minScrollExtent);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(YearPicker), _dismissDrag);
    await tester.pumpAndSettle();

    expect(opener.completed, isTrue);
    expect(find.byType(DatePickerSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('a sideways drag in the month view never moves the sheet', (
    tester,
  ) async {
    await openPicker<DateTime>(
      tester,
      size: phoneTallSize,
      open: (context) => showDatePickerSheet(
        context: context,
        presentation: presentationFor(phoneTallSize),
        title: 'Date',
        initialDate: DateTime(2000, 1, 10),
        firstDate: DateTime.utc(2000),
        lastDate: DateTime.utc(2100),
      ),
    );
    final restingTop = _sheetTop(tester);

    await tester.drag(
      find.byType(CalendarDatePicker),
      const Offset(_headerDrag, 0),
    );
    await tester.pumpAndSettle();

    expect(_sheetTop(tester), closeTo(restingTop, _moveTolerance));
    expect(find.byType(DatePickerSheet), findsOneWidget);
  }, timeout: uiTestTimeout);
}
