import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/ui_test_timeout.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';

import 'new_entry_session_harness.dart';

const _dragDown = Offset(0, 320);

Finder get _amountField => find.byType(TextField).first;

Finder get _noteField => find.byKey(const ValueKey('new-entry-note'));

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

const _formSwipe = Offset(0, -60);
const _cancelPickerTap = Offset(10, 10);
const _padKey = '5';

Future<void> _pressPadKey(WidgetTester tester, PointerDeviceKind kind) async {
  final center = tester.getCenter(find.text(_padKey));
  final gesture = await tester.startGesture(center, kind: kind);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _expectPadAcceptsPress(
  WidgetTester tester,
  EntryHarness harness,
  PointerDeviceKind kind,
) async {
  await _pressPadKey(tester, kind);
  expect(find.byType(NumberPad), findsOneWidget);
  expect(harness.draft['amount'], _padKey);
}

Future<void> _swipeForm(WidgetTester tester) async {
  await tester.drag(find.text('Expense'), _formSwipe);
  await tester.pumpAndSettle();
}

Future<void> _expectKindTappable(
  WidgetTester tester,
  EntryHarness harness,
  String label,
  EntryFormKind kind,
) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  final state = harness.container.read(entryFormViewModelProvider(null)).value;
  expect(state!.kind, kind);
}

Future<void> _openPendingAdd(
  WidgetTester tester,
  EntryHarness harness,
  Completer<void> gate,
) async {
  harness.faults.initGate = gate;
  harness.opened = harness.open();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _dragSheetDown(WidgetTester tester) async {
  await tester.drag(find.text('Add entry'), _dragDown);
  await tester.pumpAndSettle();
}

Future<void> _pickAccountFrom(
  WidgetTester tester,
  Finder field,
  Offset? cancelAt,
) async {
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
  if (cancelAt == null) {
    await tester.tap(find.text('Checking'));
  } else {
    await tester.tapAt(cancelAt);
  }
  await tester.pumpAndSettle();
}

Future<void> _expectReachable(
  WidgetTester tester,
  Rect sheet,
  List<String> labels,
) async {
  for (final label in labels) {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    final rect = tester.getRect(finder);
    expect(finder.hitTestable(), findsOneWidget, reason: label);
    expect(rect.left, greaterThanOrEqualTo(sheet.left), reason: label);
    expect(rect.right, lessThanOrEqualTo(sheet.right), reason: label);
  }
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
    }, timeout: uiTestTimeout);

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
    }, timeout: uiTestTimeout);

    testWidgets('a pad tap keeps the pad', (tester) async {
      final harness = await _openAdd(tester);

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();

      expect(find.byType(NumberPad), findsOneWidget);
      expect(harness.draft['amount'], '7');
    }, timeout: uiTestTimeout);

    testWidgets('an outside tap dismisses the keyboard', (tester) async {
      await _openAdd(tester);
      await tester.tap(_nameField);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);

      await _tapOutside(tester);

      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byType(NumberPad), findsNothing);
    }, timeout: uiTestTimeout);
  });

  group('Note in the live Add sheet', () {
    const multiline = 'first line\nsecond line';

    Future<void> typeNote(WidgetTester tester) async {
      await tester.ensureVisible(_noteField);
      await tester.pumpAndSettle();
      await tester.tap(_noteField);
      await tester.pumpAndSettle();
      await tester.enterText(_noteField, multiline);
      await tester.pumpAndSettle();
    }

    String noteDraft(EntryHarness harness) => harness.container
        .read(entryFormViewModelProvider(null))
        .value!
        .noteText;

    testWidgets(
      'typing multiline text reaches the draft with the keyboard up',
      (tester) async {
        final harness = await _openAdd(tester);

        await typeNote(tester);

        expect(noteDraft(harness), multiline);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(find.byType(NumberPad), findsNothing);
        expect(find.text('Save entry').hitTestable(), findsOneWidget);
      },
      timeout: uiTestTimeout,
    );

    testWidgets(
      'opening Repeat from Note keeps the draft and both surfaces down',
      (tester) async {
        final harness = await _openAdd(tester);
        await typeNote(tester);

        await tester.ensureVisible(find.text('Repeat'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Repeat'));
        await tester.pumpAndSettle();
        await tester.tapAt(_cancelPickerTap);
        await tester.pumpAndSettle();

        expect(noteDraft(harness), multiline);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(find.byType(NumberPad), findsNothing);
        expect(harness.recorder.sheets, hasLength(1));
      },
      timeout: uiTestTimeout,
    );
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
    }, timeout: uiTestTimeout);

    testWidgets('dragging the open layout does nothing', (tester) async {
      final harness = await _openAdd(tester, size: openSize);

      await tester.drag(find.text('Add entry'), _dragDown);
      await tester.pumpAndSettle();

      expect(harness.recorder.sheets, hasLength(1));
    }, timeout: uiTestTimeout);
  });

  group('outside dismissal ignores pointer kinds and scrolling', () {
    for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.stylus]) {
      testWidgets('a ${kind.name} pad press keeps the pad', (tester) async {
        final harness = await _openAdd(tester);

        await _expectPadAcceptsPress(tester, harness, kind);
      }, timeout: uiTestTimeout);
    }

    testWidgets('a toolbar press does not dismiss the pad', (tester) async {
      final harness = await _openAdd(tester);
      harness.form.setAmount('12');
      await tester.pumpAndSettle();

      await tester.longPress(_amountField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();

      expect(find.byType(NumberPad), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('swiping the form keeps the pad', (tester) async {
      await _openAdd(tester);

      await _swipeForm(tester);

      expect(find.byType(NumberPad), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('swiping the form keeps the keyboard', (tester) async {
      await _openAdd(tester);
      await tester.tap(_nameField);
      await tester.pumpAndSettle();

      await _swipeForm(tester);

      expect(tester.testTextInput.isVisible, isTrue);
    }, timeout: uiTestTimeout);
  });

  group('loading and failed Add sheets drag down', () {
    testWidgets('a pending initialization retires on drag', (tester) async {
      final harness = await pumpShell(tester);
      final gate = Completer<void>();
      await _openPendingAdd(tester, harness, gate);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await _dragSheetDown(tester);
      gate.complete();
      await tester.pumpAndSettle();
      await harness.opened;

      expect(harness.recorder.sheets, isEmpty);
      harness.faults.initGate = null;
      await openAdd(tester, harness);
      expect(find.byType(NumberPad), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('a failed initialization retires on drag', (tester) async {
      final harness = await pumpShell(tester);
      harness.faults.failInit = true;
      harness.opened = harness.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Retry'), findsOneWidget);

      await _dragSheetDown(tester);
      await harness.opened;

      expect(harness.recorder.sheets, isEmpty);
      harness.faults.failInit = false;
      await openAdd(tester, harness);
      expect(find.byType(NumberPad), findsOneWidget);
    }, timeout: uiTestTimeout);
  });

  group('input surfaces stay dismissed after a picker', () {
    testWidgets(
      'a dismissed picker from Amount focus leaves surfaces dismissed',
      (tester) async {
        await _openAdd(tester);

        await _pickAccountFrom(tester, _amountField, _cancelPickerTap);

        expect(find.byType(NumberPad), findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
      },
      timeout: uiTestTimeout,
    );

    testWidgets(
      'a completed picker from Name focus leaves surfaces dismissed',
      (tester) async {
        final harness = await _openAdd(tester);

        await _pickAccountFrom(tester, _nameField, null);

        expect(harness.draft['source'], checkingId);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(find.byType(NumberPad), findsNothing);
      },
      timeout: uiTestTimeout,
    );
  });

  testWidgets('segments wrap, stay inside the sheet and stay tappable', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = await _openAdd(tester, size: const Size(600, 480));
    await _tapOutside(tester);
    final sheet = tester.getRect(find.byType(AppSheet));

    for (final label in ['Income', 'Transfer', 'Expense']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(sheet.left));
      expect(rect.right, lessThanOrEqualTo(sheet.right));
    }
    await _expectKindTappable(tester, harness, 'Income', EntryFormKind.income);
    await _expectKindTappable(
      tester,
      harness,
      'Transfer',
      EntryFormKind.transfer,
    );
    await _expectKindTappable(
      tester,
      harness,
      'Expense',
      EntryFormKind.expense,
    );
    await _expectReachable(tester, sheet, [
      'Save',
      'Date',
      'Account',
      'Category',
      'Save entry',
    ]);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);
}
