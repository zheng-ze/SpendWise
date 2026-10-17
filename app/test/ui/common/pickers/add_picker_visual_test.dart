import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import '../../../support/picker_sheet_harness.dart';

const _duoSize = Size(466, 900);
const _phoneSafeTop = 62.0;
const _phoneSafeBottom = 34.0;
const _maxWeekdayGap = 40.0;
const _centerTolerance = 1.0;
const _rowAlignTolerance = 4.0;
const _singleLineMaxHeight = 30.0;

const _groups = [
  PickerOption(
    id: 'food',
    label: 'Grocery',
    children: [PickerOption(id: 'market', label: 'Market')],
  ),
  PickerOption(id: 'travel', label: 'Travel'),
];

const _longWordGroups = [
  PickerOption(
    id: 'food',
    label: 'Groceries',
    children: [PickerOption(id: 'market', label: 'Supermarket')],
  ),
  PickerOption(id: 'travel', label: 'Transportation'),
];

const _wideWordGroups = [
  PickerOption(
    id: 'telecom',
    label: 'Telecommunications',
    children: [PickerOption(id: 'mobile', label: 'Mobile')],
  ),
];

Future<void> _openGroups(
  WidgetTester tester,
  Size size,
  List<PickerOption> groups,
) async {
  await openPicker<PickerOutcome>(
    tester,
    size: size,
    open: (context) => showTwoColumnPickerSheet(
      context: context,
      title: 'Category',
      groups: groups,
      sheetPresentation: presentationFor(size),
    ),
  );
}

bool _isOneLine(WidgetTester tester, String word) =>
    tester.getSize(find.text(word)).height <= _singleLineMaxHeight;

bool _childSharesParentRow(WidgetTester tester, String parent, String child) {
  final parentY = tester.getTopLeft(find.text(parent)).dy;
  final childY = tester.getTopLeft(find.text(child)).dy;
  return (childY - parentY).abs() <= _rowAlignTolerance;
}

void main() {
  for (final size in [_duoSize, desktopSize]) {
    testWidgets('no word splits at ${size.width.toInt()} wide', (tester) async {
      await _openGroups(tester, size, _longWordGroups);
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      expect(_isOneLine(tester, 'Groceries'), isTrue);
      expect(_isOneLine(tester, 'Supermarket'), isTrue);
      expect(_isOneLine(tester, 'Transportation'), isTrue);
    });

    testWidgets('columns sit side by side at ${size.width.toInt()} wide', (
      tester,
    ) async {
      await _openGroups(tester, size, _groups);
      await tester.tap(find.text('Grocery'));
      await tester.pumpAndSettle();

      expect(_childSharesParentRow(tester, 'Grocery', 'Market'), isTrue);
    });
  }

  testWidgets('a word too wide for two columns switches to stacked', (
    tester,
  ) async {
    await _openGroups(tester, _duoSize, _wideWordGroups);
    await tester.tap(find.text('Telecommunications'));
    await tester.pumpAndSettle();

    expect(_isOneLine(tester, 'Telecommunications'), isTrue);
    expect(
      _childSharesParentRow(tester, 'Telecommunications', 'Mobile'),
      isFalse,
    );
  });

  testWidgets('date sheet keeps the weekday row near the month header', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(
      top: _phoneSafeTop,
      bottom: _phoneSafeBottom,
    );
    addTearDown(tester.view.resetPadding);
    const size = Size(402, 874);
    await openPicker<DateTime>(
      tester,
      size: size,
      open: (context) => showDatePickerSheet(
        context: context,
        presentation: presentationFor(size),
        title: 'Date',
        initialDate: DateTime(2026, 10, 10),
        firstDate: DateTime.utc(2000),
        lastDate: DateTime.utc(2100),
      ),
    );

    final header = tester.getRect(find.text('October 2026'));
    final weekday = tester.getRect(find.text('S').first);

    expect(weekday.top - header.bottom, lessThanOrEqualTo(_maxWeekdayGap));
  });

  for (final allowsNone in [false, true]) {
    testWidgets('title is centered with allowsNone $allowsNone', (
      tester,
    ) async {
      await openPicker<PickerOutcome>(
        tester,
        size: _duoSize,
        open: (context) => showTwoColumnPickerSheet(
          context: context,
          title: 'Category',
          groups: _groups,
          allowsNone: allowsNone,
          sheetPresentation: presentationFor(_duoSize),
        ),
      );

      final title = tester.getCenter(find.text('Category')).dx;
      final sheet = tester.getCenter(find.byType(AppSheet)).dx;

      expect((title - sheet).abs(), lessThanOrEqualTo(_centerTolerance));
    });
  }
}
