import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/inputs/number_pad.dart';

class PadTaps {
  final digits = <String>[];
  var decimals = 0;
  var backspaces = 0;
}

Future<PadTaps> pumpNumberPad(
  WidgetTester tester, {
  bool enabled = true,
}) async {
  final taps = PadTaps();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NumberPad(
          enabled: enabled,
          onDigit: taps.digits.add,
          onDecimal: () => taps.decimals++,
          onBackspace: () => taps.backspaces++,
        ),
      ),
    ),
  );
  return taps;
}

Future<void> tapPadLabel(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> tapPadBackspace(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.backspace_outlined));
  await tester.pump();
}
