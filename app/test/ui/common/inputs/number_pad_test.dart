import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/inputs/number_pad.dart';

import '../../../support/number_pad_support.dart';
import '../../../support/ui_test_timeout.dart';

void main() {
  testWidgets('digit keys report 1-9 then 0 in layout order', (tester) async {
    final taps = await pumpNumberPad(tester);

    for (final label in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
      await tapPadLabel(tester, label);
    }

    expect(taps.digits, ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']);
    expect(taps.decimals, 0);
    expect(taps.backspaces, 0);
  }, timeout: uiTestTimeout);

  testWidgets('the last row holds decimal, zero and backspace', (tester) async {
    final taps = await pumpNumberPad(tester);

    await tapPadLabel(tester, '.');
    await tapPadBackspace(tester);

    expect(taps.decimals, 1);
    expect(taps.backspaces, 1);
    expect(taps.digits, isEmpty);
    final lastRow = tester.getRect(find.text('.'));
    final zero = tester.getRect(find.text('0'));
    final backspace = tester.getRect(find.byIcon(Icons.backspace_outlined));
    expect(lastRow.center.dy, zero.center.dy);
    expect(backspace.center.dy, zero.center.dy);
    expect(lastRow.center.dx, lessThan(zero.center.dx));
    expect(zero.center.dx, lessThan(backspace.center.dx));
  }, timeout: uiTestTimeout);

  testWidgets('decimal and backspace expose accessible labels', (tester) async {
    await pumpNumberPad(tester);

    expect(find.bySemanticsLabel('Decimal point'), findsOneWidget);
    expect(find.bySemanticsLabel('Backspace'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('a disabled pad emits no callbacks', (tester) async {
    final taps = await pumpNumberPad(tester, enabled: false);

    for (final label in ['1', '5', '9', '0', '.']) {
      await tapPadLabel(tester, label);
    }
    await tapPadBackspace(tester);

    expect(taps.digits, isEmpty);
    expect(taps.decimals, 0);
    expect(taps.backspaces, 0);
  }, timeout: uiTestTimeout);

  testWidgets('four rows of 48 dp keys total 192 dp', (tester) async {
    await pumpNumberPad(tester);

    final pad = tester.getSize(find.byType(NumberPad));
    expect(pad.height, 192);
    for (final label in ['1', '4', '7', '.']) {
      final key = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(key).height, 48);
    }
  }, timeout: uiTestTimeout);

  testWidgets('every digit key is a labelled button, disabled keys say so', (
    tester,
  ) async {
    await pumpNumberPad(tester);
    for (final label in ['0', '5', '9']) {
      final data = tester
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isTrue);
    }

    await pumpNumberPad(tester, enabled: false);
    final disabled = tester
        .getSemantics(find.bySemanticsLabel('5'))
        .getSemanticsData();
    expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
  }, timeout: uiTestTimeout);
}
