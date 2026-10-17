import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';

import '../../../support/ui_test_timeout.dart';

const _word = 'Wide';
const _childLabel = 'Kid';
const _parentIconSize = 28.0;
const _parentRowChrome = 92.0;
const _columnDividerWidth = 1.0;
const _measuringWidth = 600.0;
const _viewportHeight = 800.0;

const _groups = [
  PickerOption(
    id: 'parent',
    label: _word,
    leading: CategoryIcon(
      symbolName: 'local_cafe',
      color: Colors.red,
      size: _parentIconSize,
    ),
    children: [PickerOption(id: 'child', label: _childLabel)],
  ),
];

Future<void> _pumpAtWidth(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, _viewportHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final body = SizedBox(
    width: width,
    child: const PickerGroupBody(groups: _groups),
  );
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey(width),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: body),
      ),
    ),
  );
  await tester.tap(find.text(_word));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('switches to side by side exactly at the parent row chrome', (
    tester,
  ) async {
    await _pumpAtWidth(tester, _measuringWidth);
    final wordWidth = tester
        .renderObject<RenderParagraph>(find.text(_word))
        .getMaxIntrinsicWidth(double.infinity);
    final threshold = 2 * (_parentRowChrome + wordWidth) + _columnDividerWidth;

    await _pumpAtWidth(tester, threshold - 1);
    final stackedChildY = tester.getTopLeft(find.text(_childLabel)).dy;
    final stackedParentY = tester.getTopLeft(find.text(_word)).dy;
    expect(stackedChildY, greaterThan(stackedParentY));

    await _pumpAtWidth(tester, threshold);
    final sideChildY = tester.getTopLeft(find.text(_childLabel)).dy;
    final sideParentY = tester.getTopLeft(find.text(_word)).dy;
    final parentHeight = tester.getSize(find.text(_word)).height;
    expect(sideChildY, closeTo(sideParentY, parentHeight));
    final wordLines = tester.renderObject<RenderParagraph>(find.text(_word));
    expect(wordLines.size.height, parentHeight);
  }, timeout: uiTestTimeout);
}
