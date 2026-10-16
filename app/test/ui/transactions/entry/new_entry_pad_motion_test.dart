import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/transactions/entry/animated_input_surface.dart';

import 'new_entry_session_harness.dart';

const _midAnimation = Duration(milliseconds: 100);
const _padHeight = 192.0;
const _keyboardHeight = 300.0;

Finder get _amountField => find.byType(TextField).first;

Future<EntryHarness> _openAdd(WidgetTester tester) async {
  final harness = await pumpShell(tester);
  await openAdd(tester, harness);
  return harness;
}

Future<void> _hidePad(WidgetTester tester) async {
  await tester.tap(find.text('Add entry'));
}

double _padHeightNow(WidgetTester tester) =>
    tester.getSize(find.byType(AnimatedInputSurface)).height;

void _expectPartial(double height) {
  expect(height, greaterThan(0));
  expect(height, lessThan(_padHeight));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pad motion', () {
    testWidgets('the pad shrinks out and grows back through partial sizes', (
      tester,
    ) async {
      await _openAdd(tester);
      expect(_padHeightNow(tester), _padHeight);

      await _hidePad(tester);
      await tester.pump();
      await tester.pump(_midAnimation);
      _expectPartial(_padHeightNow(tester));
      await tester.pumpAndSettle();
      expect(find.byType(NumberPad), findsNothing);

      await tester.tap(_amountField);
      await tester.pump();
      await tester.pump(_midAnimation);
      _expectPartial(_padHeightNow(tester));
      await tester.pumpAndSettle();
      expect(_padHeightNow(tester), _padHeight);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion swaps the pad at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _openAdd(tester);

      await _hidePad(tester);
      await tester.pump();
      await tester.pump();

      expect(find.byType(NumberPad), findsNothing);
    });

    testWidgets('a rising keyboard never shares height with the pad', (
      tester,
    ) async {
      await _openAdd(tester);
      await tester.tap(find.byType(TextField).at(1));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.pump();

      expect(_padHeightNow(tester), 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancel keeps the pad through the exit transition', (
      tester,
    ) async {
      final harness = await _openAdd(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(_midAnimation);

      expect(find.byType(NumberPad), findsOneWidget);
      expect(_padHeightNow(tester), _padHeight);
      await tester.pumpAndSettle();
      await harness.opened;
      expect(harness.recorder.sheets, isEmpty);
    });
  });
}
