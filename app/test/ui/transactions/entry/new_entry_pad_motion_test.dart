import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import '../../../support/pad_probe.dart';
import 'new_entry_session_harness.dart';

const _midAnimation = Duration(milliseconds: 100);
const _padHeight = 192.0;
const _smallInset = 100.0;
const _tallInset = 300.0;
const _liveWindow = Size(393, 852);
const _safeTop = 47.0;
const _safeBottom = 34.0;
const _dismissDrag = Offset(0, 500);

Finder get _amountField => find.byType(TextField).first;

Finder get _nameField => find.byType(TextField).at(1);

Future<EntryHarness> _openAdd(WidgetTester tester, {Size? size}) async {
  final harness = await pumpShell(tester, size: size ?? phoneSize);
  await openAdd(tester, harness);
  return harness;
}

Future<void> _hidePad(WidgetTester tester) async {
  await tester.tap(find.text('Add entry'));
  await tester.pump();
}

double _sheetHeight(WidgetTester tester) {
  final surface = find
      .descendant(of: find.byType(AppSheet), matching: find.byType(Material))
      .first;
  return tester.getSize(surface).height;
}

void _setInset(WidgetTester tester, double inset) {
  tester.view.viewInsets = FakeViewPadding(bottom: inset);
  addTearDown(tester.view.resetViewInsets);
}

void _expectPartial(double height) {
  expect(height, greaterThan(0));
  expect(height, lessThan(_padHeight));
}

void _expectNeverAdding(WidgetTester tester, double inset) {
  expect(padReservedHeight(tester) + inset, lessThanOrEqualTo(_padHeight + 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pad motion', () {
    testWidgets('the pad shrinks out and grows back through partial sizes', (
      tester,
    ) async {
      await _openAdd(tester);
      expect(padReservedHeight(tester), _padHeight);

      await _hidePad(tester);
      await tester.pump(_midAnimation);
      _expectPartial(padReservedHeight(tester));
      await tester.pumpAndSettle();
      expect(find.byType(NumberPad), findsNothing);

      await tester.tap(_amountField);
      await tester.pump();
      await tester.pump(_midAnimation);
      _expectPartial(padReservedHeight(tester));
      await tester.pumpAndSettle();
      expect(padReservedHeight(tester), _padHeight);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sheet grows and shrinks with the pad', (tester) async {
      await _openAdd(tester);
      final grown = _sheetHeight(tester);

      await _hidePad(tester);
      await tester.pump(_midAnimation);
      final during = _sheetHeight(tester);
      await tester.pumpAndSettle();
      final shrunk = _sheetHeight(tester);

      expect(shrunk, lessThan(during));
      expect(during, lessThan(grown));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion swaps the pad and height at once', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _openAdd(tester);
      final grown = _sheetHeight(tester);

      await _hidePad(tester);
      await tester.pump();

      expect(find.byType(NumberPad), findsNothing);
      expect(_sheetHeight(tester), lessThan(grown));
    });

    testWidgets('Name focus shrinks the pad while the keyboard rises', (
      tester,
    ) async {
      await _openAdd(tester);

      await tester.tap(_nameField);
      await tester.pump();
      await tester.pump(_midAnimation);
      final animating = padReservedHeight(tester);
      _expectPartial(animating);

      _setInset(tester, _smallInset);
      await tester.pump();
      _expectNeverAdding(tester, _smallInset);
      _setInset(tester, _tallInset);
      await tester.pump();
      expect(padReservedHeight(tester), 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a falling keyboard hands the space back to the pad', (
      tester,
    ) async {
      await _openAdd(tester);
      await tester.tap(_nameField);
      _setInset(tester, _tallInset);
      await tester.pumpAndSettle();

      await tester.tap(_amountField);
      _setInset(tester, _smallInset);
      await tester.pump();
      await tester.pump(_midAnimation);

      _expectNeverAdding(tester, _smallInset);
    });

    testWidgets('a drag dismissal keeps the pad through the exit', (
      tester,
    ) async {
      final harness = await _openAdd(tester);

      await tester.drag(find.text('Add entry'), _dismissDrag);
      await tester.pump();
      await tester.pump(_midAnimation);

      expect(padReservedHeight(tester), _padHeight);
      await tester.pumpAndSettle();
      await harness.opened;
      expect(harness.recorder.sheets, isEmpty);
    });
  });

  group('the grown sheet keeps the form visible', () {
    testWidgets('rows stay above Save entry with the pad at 393 x 852', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(
        top: _safeTop,
        bottom: _safeBottom,
      );
      addTearDown(tester.view.resetViewPadding);
      await _openAdd(tester, size: _liveWindow);

      for (final label in ['Category', 'Account', 'Date']) {
        expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
      }
      expect(_nameField.hitTestable(), findsOneWidget);
      final save = tester.getRect(find.text('Save entry'));
      final pad = tester.getRect(find.byType(NumberPad));
      expect(save.bottom, lessThanOrEqualTo(pad.top));
      expect(tester.getRect(find.text('Date')).bottom, lessThan(save.top));
    });
  });
}
