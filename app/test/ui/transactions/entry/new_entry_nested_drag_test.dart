import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';

import '../../../support/sheet_probe.dart';
import 'new_entry_session_harness.dart';
import '../../../support/ui_test_timeout.dart';

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
  final expense = find.text('Expense');
  final center = tester.getCenter(expense);
  return tester.startGesture(center);
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

Future<void> _dismissFallbackFromBodyTop(WidgetTester tester) async {
  _useFallbackLayout(tester);
  final harness = await _openAdd(tester, size: _compactPhone);

  final expense = find.text('Expense');
  await tester.drag(expense, _longPull);

  await _expectDismissed(tester, harness);
}

Future<void> _dismissFittingFormWithHiddenPad(WidgetTester tester) async {
  final harness = await _openAdd(tester);
  await tester.tap(find.text(_pad));
  await tester.pumpAndSettle();

  final expense = find.text('Expense');
  await tester.drag(expense, _longPull);

  await _expectDismissed(tester, harness);
}

Future<void> _scrollBodyBeforeSheet(WidgetTester tester) async {
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
}

Future<void> _returnSheetBeforeBody(WidgetTester tester) async {
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
}

Future<void> _keepFormAfterResize(WidgetTester tester) async {
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
}

Future<void> _settleReleasesWithoutMotion(WidgetTester tester) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await _openAdd(tester);
  final top = sheetTop(tester);

  final pad = find.text(_pad);
  await tester.drag(pad, _shortPull);
  await tester.pump();
  expect(sheetTop(tester), top);

  final expense = find.text('Expense');
  await tester.drag(expense, _shortPull);
  await tester.pump();
  expect(sheetTop(tester), top);
}

Future<void> _reopenFreshDraft(WidgetTester tester) async {
  final harness = await _openAdd(tester);
  harness.form.setAmount('12.50');
  harness.form.setName('Lunch');
  await tester.pumpAndSettle();
  expect(harness.draft['name'], 'Lunch');

  final pad = find.text(_pad);
  await tester.drag(pad, _longPull);
  await _expectDismissed(tester, harness);
  await openAdd(tester, harness);

  expect(harness.draft['amount'], '');
  expect(harness.draft['name'], '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('body drags without scroll extent', () {
    testWidgets(
      'the whole-sheet fallback dismisses from the body top',
      _dismissFallbackFromBodyTop,
      timeout: uiTestTimeout,
    );

    testWidgets(
      'a form that fits dismisses once the pad is hidden',
      _dismissFittingFormWithHiddenPad,
      timeout: uiTestTimeout,
    );
  });

  group('reversing a body gesture', () {
    testWidgets(
      'scroll up then down moves the body before the sheet',
      _scrollBodyBeforeSheet,
      timeout: uiTestTimeout,
    );

    testWidgets(
      'pull down then up returns the sheet before the body',
      _returnSheetBeforeBody,
      timeout: uiTestTimeout,
    );
  });

  group('unfinished and reduced-motion drags', () {
    testWidgets(
      'a drag cut off by a resize leaves the form in place',
      _keepFormAfterResize,
      timeout: uiTestTimeout,
    );

    testWidgets(
      'header and body releases settle at once without motion',
      _settleReleasesWithoutMotion,
      timeout: uiTestTimeout,
    );
  });

  group('a dismissed draft', () {
    testWidgets(
      'reopening after a drag starts a fresh draft',
      _reopenFreshDraft,
      timeout: uiTestTimeout,
    );
  });
}
