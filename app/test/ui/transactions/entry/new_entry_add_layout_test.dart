import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/add_sheet_dismiss.dart';

import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';
import 'package:spendwise/ui/transactions/entry/add_amount_block.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';

import '../../../support/pad_probe.dart';
import 'new_entry_session_harness.dart';

const _foldBounds = Rect.fromLTWH(475, 0, 10, 720);
const _desktopDialogMaxWidth = 440.0;
const _compactPhone = Size(320, 560);
const _tallPhone = Size(320, 760);
const _textScale = 1.5;
const _keyboardHeight = 300.0;
const _safeTop = 20.0;
const _safeBottom = 34.0;
const _dragUp = Offset(0, -80);
const _dragDownward = Offset(0, 80);
const _handleWidth = 34.0;
const _titleSize = 18.0;
const _titleLineHeight = 1.2;
const _saveRadius = 10.0;
const _saveLabelSize = 12.0;
const _phoneAmountSize = 32.0;
const _desktopAmountSize = 34.0;
const _amountLetterSpacing = -1.0;
const _amountLineHeight = 1.2;
const _caretWidth = 1.5;
const _amountLabelSize = 10.0;
const _handleHeight = 4.0;

final _frameIds = {'add-expense', 'add-income', 'add-transfer', 'add-desk'};

const _desktopWindow = Size(1440, 900);

extension on _Frame {
  _Frame withBrightness(Brightness value) => (
    kind: kind,
    amount: amount,
    name: name,
    brightness: value,
    desktop: desktop,
  );
}

const _frames = <String, _Frame>{
  'add-expense': (
    kind: EntryFormKind.expense,
    amount: '42.50',
    name: 'FairPrice groceries',
    brightness: Brightness.light,
    desktop: false,
  ),
  'add-income': (
    kind: EntryFormKind.income,
    amount: '3200.00',
    name: 'Monthly salary',
    brightness: Brightness.light,
    desktop: false,
  ),
  'add-transfer': (
    kind: EntryFormKind.transfer,
    amount: '500.00',
    name: 'To savings',
    brightness: Brightness.light,
    desktop: false,
  ),
  'add-desk': (
    kind: EntryFormKind.expense,
    amount: '42.50',
    name: 'FairPrice groceries',
    brightness: Brightness.light,
    desktop: true,
  ),
};

Finder _inSheet(String text) =>
    find.descendant(of: find.byType(AppSheet), matching: find.text(text));

Finder get _amountField => find.byType(TextField).first;

Finder get _nameField => find.byType(TextField).at(1);

Finder get _handle => find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.constraints ==
          const BoxConstraints.tightFor(
            width: _handleWidth,
            height: _handleHeight,
          ),
);

Future<void> _tapRailAdd(WidgetTester tester) async {
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
}

Future<void> _setKeyboard(WidgetTester tester, double height) async {
  tester.view.viewInsets = FakeViewPadding(bottom: height);
  await tester.pumpAndSettle();
}

void _useInsets(WidgetTester tester, {double top = 0, double bottom = 0}) {
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
}

void _useTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

ScrollPosition _scrollPosition(WidgetTester tester, int index) {
  final scrollables = find.descendant(
    of: find.byType(AppSheet),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollables.at(index)).position;
}

Future<void> _dragIntoView(
  WidgetTester tester,
  String label,
  Offset step,
) async {
  final outer = find
      .descendant(
        of: find.byType(AppSheet),
        matching: find.byType(SingleChildScrollView),
      )
      .first;
  await tester.dragUntilVisible(find.text(label), outer, step);
  await tester.pumpAndSettle();
  expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
}

Future<void> _expectChromeReachable(WidgetTester tester) async {
  for (final label in ['Add entry', 'Save entry', '5']) {
    expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
  }
}

typedef _Frame = ({
  EntryFormKind kind,
  String amount,
  String name,
  Brightness brightness,
  bool desktop,
});

void _expectHeader(WidgetTester tester, _Frame frame) {
  final title = tester.widget<Text>(_inSheet('Add entry'));
  expect(title.style!.fontSize, _titleSize);
  expect(title.style!.fontWeight, FontWeight.w600);
  expect(title.style!.height, _titleLineHeight);
  expect(_inSheet('Cancel'), frame.desktop ? findsOneWidget : findsNothing);
  expect(find.text('Save'), findsNothing);
}

void _expectSaveButton(WidgetTester tester) {
  final button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Save entry'),
  );
  final shape = button.style!.shape!.resolve({}) as RoundedRectangleBorder;
  final label = button.style!.textStyle!.resolve({})!;
  expect(shape.borderRadius, BorderRadius.circular(_saveRadius));
  expect(label.fontSize, _saveLabelSize);
  expect(label.fontWeight, FontWeight.w600);
}

void _expectAmount(WidgetTester tester, _Frame frame, SpendWiseColors colors) {
  final field = tester.widget<TextField>(_amountField);
  final style = field.style!;
  expect(field.controller!.text, frame.amount);
  expect(style.fontSize, frame.desktop ? _desktopAmountSize : _phoneAmountSize);
  expect(style.letterSpacing, _amountLetterSpacing);
  expect(style.height, _amountLineHeight);
  expect(field.cursorWidth, _caretWidth);
  expect(field.cursorColor, colors.focus);
  final label = tester.widget<Text>(find.text('Amount / SGD'));
  expect(label.style!.fontSize, _amountLabelSize);
  expect(label.style!.fontWeight, FontWeight.w400);
}

Future<void> _expectFrame(
  WidgetTester tester,
  EntryHarness harness,
  _Frame frame,
) async {
  harness.form.setKind(frame.kind);
  harness.form.setAmount(frame.amount);
  harness.form.setName(frame.name);
  await tester.pumpAndSettle();
  final colors = frame.brightness == Brightness.dark
      ? SpendWiseColors.dark
      : SpendWiseColors.light;

  for (final label in ['Add entry', 'Expense', 'Income', 'Transfer']) {
    expect(_inSheet(label), findsOneWidget, reason: label);
  }
  _expectHeader(tester, frame);
  _expectSaveButton(tester);
  _expectAmount(tester, frame, colors);
  expect(tester.widget<TextField>(_nameField).controller!.text, frame.name);
  expect(find.text('Date'), findsOneWidget);
  final transfer = frame.kind == EntryFormKind.transfer;
  expect(find.text('Category'), transfer ? findsNothing : findsOneWidget);
  expect(find.text('From'), transfer ? findsOneWidget : findsNothing);
  expect(find.text('To'), transfer ? findsOneWidget : findsNothing);
  final block = find.descendant(
    of: find.byType(AddAmountBlock),
    matching: find.byType(Container),
  );
  final decoration = tester.widget<Container>(block.first).decoration;
  expect((decoration! as BoxDecoration).color, colors.surface);
}

Future<EntryHarness> _openFrame(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  final harness = await pumpShell(
    tester,
    size: size,
    platform: platform,
    theme: buildSpendWiseTheme(brightness),
  );
  await openAdd(tester, harness);
  return harness;
}

Future<void> _checkFrameParity(
  WidgetTester tester,
  _Frame frame,
  Brightness brightness,
) async {
  final harness = await _openFrame(
    tester,
    size: frame.desktop ? _desktopWindow : _tallPhone,
    brightness: brightness,
    platform: frame.desktop ? TargetPlatform.macOS : TargetPlatform.iOS,
  );

  await _expectFrame(tester, harness, frame.withBrightness(brightness));
  final pad = frame.desktop ? findsNothing : findsOneWidget;
  final numberPad = find.byType(NumberPad);
  expect(numberPad, pad);
}

void _registerFrameBrightnessTests(String id, _Frame frame) {
  for (final brightness in Brightness.values) {
    testWidgets('$id ${brightness.name}', (tester) async {
      await _checkFrameParity(tester, frame, brightness);
    });
  }
}

void _registerFrameParityTests() {
  test('the registered frame ids are the ticket-owned set', () {
    expect(_frames.keys.toSet(), _frameIds);
  });

  for (final entry in _frames.entries) {
    _registerFrameBrightnessTests(entry.key, entry.value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('open fold and desktop presentation', () {
    testWidgets('AC1 the open fold opens the right-half form with the pad', (
      tester,
    ) async {
      tester.view.displayFeatures = [
        const ui.DisplayFeature(
          bounds: _foldBounds,
          type: ui.DisplayFeatureType.fold,
          state: ui.DisplayFeatureState.postureFlat,
        ),
      ];
      addTearDown(tester.view.resetDisplayFeatures);
      final harness = await pumpShell(tester, size: openSize);

      await _tapRailAdd(tester);

      final sheet = tester.getRect(find.byType(AppSheet));
      expect(harness.recorder.sheets, hasLength(1));
      expect(sheet.left, openSize.width / 2);
      expect(sheet.right, openSize.width);
      expect(sheet.height, openSize.height);
      expect(find.byType(NumberPad), findsOneWidget);
      expect(_handle, findsNothing);
      expect(tester.getRect(find.text(probeLabel)).right, lessThan(sheet.left));
    });

    testWidgets('AC1 a desktop platform keeps the small dialog', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        size: openSize,
        platform: TargetPlatform.macOS,
      );
      await openAdd(tester, harness);

      final sheet = tester.getRect(find.byType(AppSheet));
      final amount = tester.widget<TextField>(_amountField);
      expect(sheet.width, lessThanOrEqualTo(_desktopDialogMaxWidth));
      expect(sheet.center.dx, openSize.width / 2);
      expect(find.byType(NumberPad), findsNothing);
      expect(amount.keyboardType, isNot(TextInputType.none));
      expect(find.widgetWithText(FilledButton, 'Save entry'), findsOneWidget);
      expect(find.text('Save'), findsNothing);

      await tester.enterText(_amountField, '42.50');
      expect(harness.draft['amount'], '42.50');
    });
  });

  group('keyboard handoff reserves one input surface', () {
    testWidgets('Back closing the keyboard restores the pad for Amount', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      _useInsets(tester);
      await openAdd(tester, harness);

      await tester.tap(_nameField);
      await _setKeyboard(tester, _keyboardHeight);
      expect(padReservedHeight(tester), 0);

      await _setKeyboard(tester, 0);

      expect(find.byType(NumberPad), findsOneWidget);
      expect(
        tester.widget<TextField>(_amountField).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('Amount waits for the keyboard inset before showing the pad', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      _useInsets(tester);
      await openAdd(tester, harness);
      await tester.tap(_nameField);
      await _setKeyboard(tester, _keyboardHeight);

      await tester.ensureVisible(_amountField);
      await tester.tap(_amountField);
      await tester.pump();
      expect(padReservedHeight(tester), 0);
      await _setKeyboard(tester, 0);

      expect(find.byType(NumberPad), findsOneWidget);
    });
  });

  group('pinned height at 320 x 560', () {
    testWidgets('zero insets at 1.0x pins everything without a fallback', (
      tester,
    ) async {
      final harness = await pumpShell(tester, size: _compactPhone);
      await openAdd(tester, harness);

      final outer = _scrollPosition(tester, 0);
      final body = _scrollPosition(tester, 1);
      expect(outer.maxScrollExtent, 0);
      expect(body.viewportDimension, greaterThan(0));
      for (final offset in [0.0, body.maxScrollExtent]) {
        body.jumpTo(offset);
        await tester.pumpAndSettle();
        await _expectChromeReachable(tester);
      }
    });

    testWidgets('safe insets at 1.5x keep every control reachable', (
      tester,
    ) async {
      _useInsets(tester, top: _safeTop, bottom: _safeBottom);
      _useTextScale(tester, _textScale);
      final harness = await pumpShell(tester, size: _compactPhone);
      await openAdd(tester, harness);

      for (final label in ['Date', 'Save entry', '5']) {
        await _dragIntoView(tester, label, _dragUp);
      }
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      expect(harness.draft['amount'], '5');
      await _dragIntoView(tester, 'Add entry', _dragDownward);
      expect(tester.takeException(), isNull);
    });
  });

  group('taps outside the fields still act', () {
    testWidgets('segment, row and Save entry are not swallowed', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      harness.form.setAmount('12.50');
      harness.form.setName('Lunch');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(
        harness.container.read(entryFormViewModelProvider(null)).value!.kind,
        EntryFormKind.income,
      );

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checking'));
      await tester.pumpAndSettle();
      expect(harness.draft['source'], checkingId);

      await tester.tap(_nameField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      await harness.opened;

      expect(harness.recorder.sheets, isEmpty);
      expect(harness.ledger.state.entries, hasLength(1));
    });

    testWidgets('the open-layout Cancel acts while the pad is shown', (
      tester,
    ) async {
      final harness = await pumpShell(tester, size: openSize);
      await openAdd(tester, harness);
      expect(find.byType(NumberPad), findsOneWidget);

      await dismissAddSheet(tester);
      await tester.pumpAndSettle();
      await harness.opened;

      expect(harness.recorder.sheets, isEmpty);
    });
  });

  group('frame parity', _registerFrameParityTests);
}
