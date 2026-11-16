import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:spendwise/ui/overview/overview_waterfall_layout.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import 'overview_fixture.dart';
import '../../support/ui_test_timeout.dart';

const _desktopBelowWideSize = Size(1249, 800);
const _desktopWideSize = Size(1250, 800);
const _openWindowSize = Size(1600, 900);
const _addEntrySplitOffset = 800.0;

Future<void> _pumpDesktop(WidgetTester tester, Size windowSize) =>
    pumpOverviewWindow(
      tester,
      state: defaultState(),
      windowSize: windowSize,
      mode: ShellLayoutMode.desktop,
    );

Future<void> _pumpOpen(WidgetTester tester, {bool sheetCovered = false}) =>
    pumpOverviewWindow(
      tester,
      state: defaultState(),
      windowSize: _openWindowSize,
      mode: ShellLayoutMode.open,
      splitOffset: sheetCovered ? _addEntrySplitOffset : 0,
      sheetCovered: sheetCovered,
    );

int _columnCount(WidgetTester tester) => tester
    .widget<OverviewWaterfall>(find.byType(OverviewWaterfall))
    .columnCount;

void main() {
  group('Overview grid layout wiring', () {
    testWidgets('desktop below 1250 uses two columns', (tester) async {
      await _pumpDesktop(tester, _desktopBelowWideSize);

      expect(_columnCount(tester), 2);
    }, timeout: uiTestTimeout);

    testWidgets('desktop at 1250 uses three columns', (tester) async {
      await _pumpDesktop(tester, _desktopWideSize);

      expect(_columnCount(tester), 3);
    }, timeout: uiTestTimeout);

    testWidgets('open full page uses three columns', (tester) async {
      await _pumpOpen(tester);

      expect(_columnCount(tester), 3);
    }, timeout: uiTestTimeout);

    // The split page stays above the 3-column floor of 3 * 220 + 2 * 10 + 28 =
    // 708 dp (grid 772 dp), so only the singleColumn presentation can collapse
    // it; dropping the presentation wiring makes this case fail.
    testWidgets('open with a covering sheet uses one column', (tester) async {
      await _pumpOpen(tester, sheetCovered: true);

      expect(_columnCount(tester), 1);
    }, timeout: uiTestTimeout);
  });
}
