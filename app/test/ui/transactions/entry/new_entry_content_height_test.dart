import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import '../../../support/ui_test_timeout.dart';
import 'new_entry_session_harness.dart';

const _nameKey = ValueKey('new-entry-name');
const _noteKey = ValueKey('new-entry-note');
const _everyMonth = 'Every month';
const _focusBorderGrowth = 1.0;

double _sheetHeight(WidgetTester tester) {
  final surface = find
      .descendant(of: find.byType(AppSheet), matching: find.byType(Material))
      .first;
  return tester.getSize(surface).height;
}

double _bodyOverflow(WidgetTester tester) {
  final scrollable = find
      .descendant(of: find.byType(AppSheet), matching: find.byType(Scrollable))
      .first;
  return tester.state<ScrollableState>(scrollable).position.maxScrollExtent;
}

Future<void> _openRecurringAdd(WidgetTester tester) async {
  final harness = await pumpShell(tester);
  await openAdd(tester, harness);
  final repeat = find.byKey(const ValueKey('new-entry-repeat'));
  await tester.ensureVisible(repeat);
  await tester.tap(repeat);
  await tester.pumpAndSettle();
  await tester.tap(find.text(_everyMonth));
  await tester.pumpAndSettle();
}

Future<void> _dismissInputs(WidgetTester tester) async {
  await tester.tap(find.text('Add entry'));
  await tester.pumpAndSettle();
}

Future<void> _focus(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the Add sheet is as tall as its content', () {
    testWidgets('a recurring form at rest scrolls nothing', (tester) async {
      await _openRecurringAdd(tester);
      await _dismissInputs(tester);

      expect(_bodyOverflow(tester), 0);
    }, timeout: uiTestTimeout);

    for (final key in [_nameKey, _noteKey]) {
      testWidgets('focusing ${key.value} keeps the at-rest height', (
        tester,
      ) async {
        await _openRecurringAdd(tester);
        await _dismissInputs(tester);
        final rest = _sheetHeight(tester);

        await _focus(tester, key);
        final focused = _sheetHeight(tester);
        await _dismissInputs(tester);

        expect(focused, closeTo(rest, _focusBorderGrowth));
        expect(_sheetHeight(tester), rest);
      }, timeout: uiTestTimeout);
    }
  });
}
