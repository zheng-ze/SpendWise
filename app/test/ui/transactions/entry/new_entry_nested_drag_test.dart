import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';

import '../../../support/sheet_probe.dart';
import 'new_entry_session_harness.dart';

const _compactPhone = Size(320, 560);
const _safeTop = 20.0;
const _safeBottom = 34.0;
const _textScale = 1.5;
const _longPull = Offset(0, 700);
const _scrollStep = -100.0;
const _backStep = 50.0;
const _pullStep = 200.0;
const _shortPull = Offset(0, 30);
const _pad = 'Add entry';
const _activation = 30.0;

Future<EntryHarness> _openAdd(WidgetTester tester, {Size? size}) async {
  final harness = await pumpShell(tester, size: size ?? phoneSize);
  await openAdd(tester, harness);
  return harness;
}

Future<void> _expectDismissed(WidgetTester tester, EntryHarness harness) async {
  await tester.pumpAndSettle();
  await harness.opened;
  expect(harness.recorder.sheets, isEmpty);
  expect(harness.presentation, NewEntryPresentation.closed);
}

Future<TestGesture> _holdBody(WidgetTester tester) {
  return tester.startGesture(tester.getCenter(find.text('Expense')));
}

Future<void> _move(TestGesture gesture, WidgetTester tester, double dy) async {
  await gesture.moveBy(Offset(0, dy));
  await tester.pump();
}

void _useFallbackLayout(WidgetTester tester) {
  tester.view.padding = const FakeViewPadding(
    top: _safeTop,
    bottom: _safeBottom,
  );
  addTearDown(tester.view.resetViewPadding);
  tester.platformDispatcher.textScaleFactorTestValue = _textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('body drags without scroll extent', () {
    testWidgets('the whole-sheet fallback dismisses from the body top', (
      tester,
    ) async {
      _useFallbackLayout(tester);
      final harness = await _openAdd(tester, size: _compactPhone);

      await tester.drag(find.text('Expense'), _longPull);

      await _expectDismissed(tester, harness);
    });

    testWidgets('a form that fits dismisses once the pad is hidden', (
      tester,
    ) async {
      final harness = await _openAdd(tester);
      await tester.tap(find.text(_pad));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Expense'), _longPull);

      await _expectDismissed(tester, harness);
    });
  });

  group('reversing a body gesture', () {
    testWidgets('scroll up then down moves the body before the sheet', (
      tester,
    ) async {
      await _openAdd(tester, size: _compactPhone);
      final top = sheetTop(tester);
      final gesture = await _holdBody(tester);
      await _move(gesture, tester, -_activation);

      await _move(gesture, tester, _scrollStep);
      await _move(gesture, tester, _backStep);
      expect(sheetTop(tester), top);

      await _move(gesture, tester, _pullStep);
      expect(sheetTop(tester), greaterThan(top));
      expect(sheetTop(tester) - top, lessThan(_pullStep));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('pull down then up returns the sheet before the body', (
      tester,
    ) async {
      await _openAdd(tester, size: _compactPhone);
      final top = sheetTop(tester);
      final gesture = await _holdBody(tester);
      await _move(gesture, tester, _activation);

      await _move(gesture, tester, _pullStep);
      final pulled = sheetTop(tester);
      await _move(gesture, tester, -_backStep);

      expect(pulled, greaterThan(top));
      expect(sheetTop(tester), closeTo(pulled - _backStep, 1));
      await _move(gesture, tester, -_pullStep);
      expect(sheetTop(tester), top);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('unfinished and reduced-motion drags', () {
    testWidgets('a drag cut off by a resize leaves the form in place', (
      tester,
    ) async {
      await _openAdd(tester, size: phoneSize);
      final gesture = await _holdBody(tester);
      await _move(gesture, tester, _activation);
      await _move(gesture, tester, _pullStep);
      expect(sheetTop(tester), greaterThan(0));

      tester.view.physicalSize = openSize;
      await tester.pumpAndSettle();

      expect(sheetTop(tester), 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(sheetTop(tester), 0);
    });

    testWidgets('header and body releases settle at once without motion', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _openAdd(tester);
      final top = sheetTop(tester);

      await tester.drag(find.text(_pad), _shortPull);
      await tester.pump();
      expect(sheetTop(tester), top);

      await tester.drag(find.text('Expense'), _shortPull);
      await tester.pump();
      expect(sheetTop(tester), top);
    });
  });

  group('a dismissed draft', () {
    testWidgets('reopening after a drag starts a fresh draft', (tester) async {
      final harness = await _openAdd(tester);
      harness.form.setAmount('12.50');
      harness.form.setName('Lunch');
      await tester.pumpAndSettle();
      expect(harness.draft['name'], 'Lunch');

      await tester.drag(find.text(_pad), _longPull);
      await _expectDismissed(tester, harness);
      await openAdd(tester, harness);

      expect(harness.draft['amount'], '');
      expect(harness.draft['name'], '');
    });
  });
}
