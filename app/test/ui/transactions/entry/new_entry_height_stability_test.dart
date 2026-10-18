import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import '../../../support/ui_test_timeout.dart';
import 'new_entry_session_harness.dart';

const _everyMonth = 'Every month';
const _outsideTap = Offset(5, 5);
const _smallKeyboard = 100.0;

Finder _row(String key) => find.byKey(ValueKey('new-entry-$key'));

double _sheetHeight(WidgetTester tester) {
  final surface = find
      .descendant(of: find.byType(AppSheet), matching: find.byType(Material))
      .first;
  return tester.getSize(surface).height;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<double> _openRestingRecurringAdd(WidgetTester tester) async {
  final harness = await pumpShell(tester);
  await openAdd(tester, harness);
  await _tap(tester, _row('repeat'));
  await tester.tap(find.text(_everyMonth));
  await tester.pumpAndSettle();
  return _sheetHeight(tester);
}

void _setKeyboard(WidgetTester tester, double inset) {
  tester.view.viewInsets = FakeViewPadding(bottom: inset);
  addTearDown(tester.view.resetViewInsets);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Add sheet height follows the pad and keyboard only', () {
    testWidgets('focusing text fields and opening pickers keeps the height', (
      tester,
    ) async {
      final rest = await _openRestingRecurringAdd(tester);

      await _tap(tester, _row('name'));
      expect(_sheetHeight(tester), rest);
      await _tap(tester, _row('note'));
      expect(_sheetHeight(tester), rest);
      await _tap(tester, _row('category'));
      await tester.tapAt(_outsideTap);
      await tester.pumpAndSettle();
      expect(_sheetHeight(tester), rest);
    }, timeout: uiTestTimeout);

    testWidgets('the pad grows the sheet and its removal restores it', (
      tester,
    ) async {
      final rest = await _openRestingRecurringAdd(tester);

      await _tap(tester, find.byType(TextField).first);
      expect(_sheetHeight(tester), greaterThan(rest));
      await _tap(tester, _row('name'));
      expect(_sheetHeight(tester), rest);
    }, timeout: uiTestTimeout);

    testWidgets(
      'a keyboard inset grows the sheet and dismissing inputs restores it',
      (tester) async {
        final rest = await _openRestingRecurringAdd(tester);
        await _tap(tester, _row('name'));

        _setKeyboard(tester, _smallKeyboard);
        await tester.pumpAndSettle();
        expect(_sheetHeight(tester), greaterThan(rest));

        _setKeyboard(tester, 0);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add entry'));
        await tester.pumpAndSettle();
        expect(_sheetHeight(tester), rest);
      },
      timeout: uiTestTimeout,
    );
  });
}
