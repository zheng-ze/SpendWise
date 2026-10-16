import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';

import 'new_entry_session_harness.dart';

const _followDistance = 60.0;
const _shortDistance = 30.0;
const _longDistance = 260.0;
const _flingDistance = 100.0;
const _flingSpeed = 1500.0;
const _handleInset = 10.0;
const _compactPhone = Size(320, 560);
const _scrollUp = Offset(0, -300);
const _scrolledBackDown = Offset(0, 120);

Future<EntryHarness> _openAdd(WidgetTester tester, {Size? size}) async {
  final harness = await pumpShell(tester, size: size ?? phoneSize);
  await openAdd(tester, harness);
  return harness;
}

Finder get _sheetSurface => find
    .descendant(of: find.byType(AppSheet), matching: find.byType(Material))
    .first;

double _sheetTop(WidgetTester tester) => tester.getRect(_sheetSurface).top;

Future<void> _expectDismissed(WidgetTester tester, EntryHarness harness) async {
  await tester.pumpAndSettle();
  await harness.opened;
  expect(harness.recorder.sheets, isEmpty);
  expect(harness.presentation, NewEntryPresentation.closed);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('interactive drag on the phone sheet', () {
    testWidgets('the sheet follows the finger', (tester) async {
      await _openAdd(tester);
      final top = _sheetTop(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Add entry')),
      );
      await gesture.moveBy(const Offset(0, _followDistance));
      await tester.pump();

      expect(_sheetTop(tester) - top, closeTo(_followDistance, 1));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a short release springs back', (tester) async {
      final harness = await _openAdd(tester);
      final top = _sheetTop(tester);

      await tester.drag(
        find.text('Add entry'),
        const Offset(0, _shortDistance),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(_sheetTop(tester), greaterThan(top));
      await tester.pumpAndSettle();

      expect(_sheetTop(tester), top);
      expect(harness.recorder.sheets, hasLength(1));
    });

    testWidgets('a long release dismisses and retires the session', (
      tester,
    ) async {
      final harness = await _openAdd(tester);

      await tester.drag(find.text('Add entry'), const Offset(0, _longDistance));

      await _expectDismissed(tester, harness);
    });

    testWidgets('a downward fling dismisses', (tester) async {
      final harness = await _openAdd(tester);

      await tester.fling(
        find.text('Add entry'),
        const Offset(0, _flingDistance),
        _flingSpeed,
      );

      await _expectDismissed(tester, harness);
    });

    testWidgets('the handle area drags the sheet', (tester) async {
      final harness = await _openAdd(tester);
      final rect = tester.getRect(_sheetSurface);

      await tester.dragFrom(
        Offset(rect.center.dx, rect.top + _handleInset),
        const Offset(0, _longDistance),
      );

      await _expectDismissed(tester, harness);
    });

    testWidgets('a body drag at offset zero dismisses', (tester) async {
      final harness = await _openAdd(tester);

      await tester.drag(find.text('Expense'), const Offset(0, _longDistance));

      await _expectDismissed(tester, harness);
    });

    testWidgets('a body drag after scrolling does not dismiss', (tester) async {
      final harness = await _openAdd(tester, size: _compactPhone);
      await tester.tap(find.text('Add entry'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Expense'), _scrollUp);
      await tester.pumpAndSettle();
      final top = _sheetTop(tester);

      await tester.drag(find.text('Account'), _scrolledBackDown);
      await tester.pumpAndSettle();

      expect(harness.recorder.sheets, hasLength(1));
      expect(_sheetTop(tester), top);
    });
  });
}
