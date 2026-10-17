import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import '../../../support/picker_sheet_harness.dart';

const _duoSize = Size(466, 900);
const _duoPortraitSize = Size(466, 678);
const _wideOpenSize = Size(1200, 800);
const _phoneSafeTop = 62.0;
const _phoneSafeBottom = 34.0;
const _maxWeekdayGap = 40.0;
const _centerTolerance = 1.0;
const _rowAlignTolerance = 4.0;
const _singleLineMaxHeight = 30.0;

const _groups = [
  PickerOption(
    id: 'food',
    label: 'Food',
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
  List<PickerOption> groups, {
  AppSheetPresentation Function(BuildContext)? presentation,
}) async {
  await openPicker<PickerOutcome>(
    tester,
    size: size,
    open: (context) => showTwoColumnPickerSheet(
      context: context,
      title: 'Category',
      groups: groups,
      sheetPresentation: presentation ?? presentationFor(size),
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

double _titleOffsetFromCenter(WidgetTester tester, String title) {
  final titleX = tester.getCenter(find.text(title)).dx;
  final sheetX = tester.getCenter(find.byType(AppSheet)).dx;
  return (titleX - sheetX).abs();
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
  }

  testWidgets('desktop presentation puts columns side by side', (tester) async {
    await _openGroups(tester, desktopSize, _groups);
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(_childSharesParentRow(tester, 'Food', 'Market'), isTrue);
  });

  testWidgets('open presentation puts columns side by side when wide', (
    tester,
  ) async {
    await _openGroups(
      tester,
      _wideOpenSize,
      _groups,
      presentation: (_) => AppSheetPresentation.open,
    );
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(_childSharesParentRow(tester, 'Food', 'Market'), isTrue);
  });

  testWidgets('phone presentation stacks at 466 x 678', (tester) async {
    await _openGroups(tester, _duoPortraitSize, _groups);
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(_childSharesParentRow(tester, 'Food', 'Market'), isFalse);
  });

  testWidgets('a word too wide for two columns switches to stacked', (
    tester,
  ) async {
    await _openGroups(
      tester,
      _wideOpenSize,
      _wideWordGroups,
      presentation: (_) => AppSheetPresentation.open,
    );
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

  testWidgets('title is centered without a trailing action', (tester) async {
    await openPicker<PickerOutcome>(
      tester,
      size: _duoSize,
      open: (context) => showTwoColumnPickerSheet(
        context: context,
        title: 'Category',
        groups: _groups,
        sheetPresentation: presentationFor(_duoSize),
      ),
    );

    expect(
      _titleOffsetFromCenter(tester, 'Category'),
      lessThanOrEqualTo(_centerTolerance),
    );
  });

  testWidgets('title is centered with a trailing action', (tester) async {
    await openPicker<DateTime>(
      tester,
      size: _duoSize,
      open: (context) => showDatePickerSheet(
        context: context,
        presentation: presentationFor(_duoSize),
        title: 'Date',
        initialDate: DateTime(2026, 10, 10),
        firstDate: DateTime.utc(2000),
        lastDate: DateTime.utc(2100),
      ),
    );

    expect(
      _titleOffsetFromCenter(tester, 'Date'),
      lessThanOrEqualTo(_centerTolerance),
    );
  });
}
