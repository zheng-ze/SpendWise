import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';

import 'new_entry_session_harness.dart';

const _dragDown = Offset(0, 160);

Finder get _amountField => find.byType(TextField).first;

Finder get _nameField => find.byType(TextField).at(1);

Future<EntryHarness> _openAdd(
  WidgetTester tester, {
  Size size = phoneSize,
}) async {
  final harness = await pumpShell(tester, size: size);
  await openAdd(tester, harness);
  return harness;
}

Future<void> _tapOutside(WidgetTester tester) async {
  await tester.tap(find.text('Add entry'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('input surfaces follow focus', () {
    testWidgets('the pad shows for the autofocused Amount only', (
      tester,
    ) async {
      await _openAdd(tester);
      expect(find.byType(NumberPad), findsOneWidget);

      await tester.tap(_nameField);
      await tester.pumpAndSettle();

      expect(find.byType(NumberPad), findsNothing);
    });

    testWidgets('an outside tap hides the pad and Amount shows it again', (
      tester,
    ) async {
      final harness = await _openAdd(tester);
      harness.form.setAmount('12');
      await tester.pumpAndSettle();

      await _tapOutside(tester);
      expect(find.byType(NumberPad), findsNothing);
      expect(harness.recorder.sheets, hasLength(1));
      expect(harness.draft['amount'], '12');

      await tester.tap(_amountField);
      await tester.pumpAndSettle();
      expect(find.byType(NumberPad), findsOneWidget);
    });

    testWidgets('a pad tap keeps the pad', (tester) async {
      final harness = await _openAdd(tester);

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();

      expect(find.byType(NumberPad), findsOneWidget);
      expect(harness.draft['amount'], '7');
    });

    testWidgets('an outside tap dismisses the keyboard', (tester) async {
      await _openAdd(tester);
      await tester.tap(_nameField);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);

      await _tapOutside(tester);

      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byType(NumberPad), findsNothing);
    });
  });

  group('drag to dismiss', () {
    testWidgets('dragging the phone sheet down retires the session', (
      tester,
    ) async {
      final harness = await _openAdd(tester);

      await tester.drag(find.text('Add entry'), _dragDown);
      await tester.pumpAndSettle();
      await harness.opened;

      expect(harness.recorder.sheets, isEmpty);
      expect(harness.presentation, NewEntryPresentation.closed);
    });

    testWidgets('dragging the open layout does nothing', (tester) async {
      final harness = await _openAdd(tester, size: openSize);

      await tester.drag(find.text('Add entry'), _dragDown);
      await tester.pumpAndSettle();

      expect(harness.recorder.sheets, hasLength(1));
    });
  });

  testWidgets('segment labels stay on one line at 202 dp and 1.5x text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openAdd(tester, size: const Size(600, 480));

    for (final label in ['Expense', 'Income', 'Transfer']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      final selection = TextSelection(
        baseOffset: 0,
        extentOffset: label.length,
      );
      expect(paragraph.getBoxesForSelection(selection), hasLength(1));
    }
    expect(tester.takeException(), isNull);
  });
}
