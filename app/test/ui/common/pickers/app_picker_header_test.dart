import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';

import '../../../support/ui_test_timeout.dart';

const _narrowWidth = 320.0;
const _wideWidth = 600.0;
const _largeTextScale = 1.5;
const _viewHeight = 400.0;
const _centerTolerance = 1.0;
const _title = 'Category';
const _dateTitle = 'Date';

Future<void> _pumpHeader(
  WidgetTester tester, {
  required double width,
  required String title,
  Widget? leading,
  Widget? trailing,
}) async {
  tester.view.physicalSize = Size(width, _viewHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final header = AppPickerHeader(
    title: title,
    leading: leading,
    trailing: trailing,
  );
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(_largeTextScale)),
        child: child!,
      ),
      home: Scaffold(body: header),
    ),
  );
}

TextButton _button(String label) =>
    TextButton(onPressed: () {}, child: Text(label));

bool _titleIsWhole(WidgetTester tester, String title) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
  return !paragraph.didExceedMaxLines &&
      paragraph.size.width >= paragraph.getMaxIntrinsicWidth(double.infinity);
}

double _titleCenterOffset(WidgetTester tester, String title) {
  final center = tester.getCenter(find.text(title)).dx;
  return (center - tester.view.physicalSize.width / 2).abs();
}

void main() {
  testWidgets('a lone title stays whole and centered at 320 px and 1.5x text', (
    tester,
  ) async {
    await _pumpHeader(tester, width: _narrowWidth, title: _title);

    expect(_titleIsWhole(tester, _title), isTrue);
    expect(_titleCenterOffset(tester, _title), lessThan(_centerTolerance));
  }, timeout: uiTestTimeout);

  testWidgets('a title beside Done stays whole and clear of it at 320 px', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      width: _narrowWidth,
      title: _title,
      trailing: _button('Done'),
    );

    final title = tester.getRect(find.text(_title));
    final done = tester.getRect(find.text('Done'));
    expect(_titleIsWhole(tester, _title), isTrue);
    expect(title.right, lessThanOrEqualTo(done.left));
  }, timeout: uiTestTimeout);

  testWidgets('Today and Done never collide with each other or the title', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      width: _narrowWidth,
      title: _dateTitle,
      leading: _button('Today'),
      trailing: _button('Done'),
    );

    final today = tester.getRect(find.text('Today'));
    final done = tester.getRect(find.text('Done'));
    final title = tester.getRect(find.text(_dateTitle));
    expect(today.right, lessThanOrEqualTo(title.left));
    expect(title.right, lessThanOrEqualTo(done.left));
  }, timeout: uiTestTimeout);

  testWidgets('a title between Today and Done is centered where it fits', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      width: _wideWidth,
      title: _dateTitle,
      leading: _button('Today'),
      trailing: _button('Done'),
    );

    expect(_titleIsWhole(tester, _dateTitle), isTrue);
    expect(_titleCenterOffset(tester, _dateTitle), lessThan(_centerTolerance));
  }, timeout: uiTestTimeout);
}
