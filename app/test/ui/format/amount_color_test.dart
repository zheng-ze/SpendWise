import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/money_format.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  late AmountColors colors;

  setUp(() {
    colors = AmountColors.of(ThemeData(brightness: Brightness.light));
  });

  test('the three roles are distinct, so a color identifies a sign', () {
    expect(colors.gain, isNot(colors.loss));
    expect(colors.gain, isNot(colors.neutral));
    expect(colors.loss, isNot(colors.neutral));
  });

  group('netAmountColor', () {
    test('above zero is a gain and below zero is a loss', () {
      expect(colors.netAmountColor(dec('0.01')), colors.gain);
      expect(colors.netAmountColor(dec('-0.01')), colors.loss);
    });

    test('exactly zero is neutral rather than a gain', () {
      expect(colors.netAmountColor(Decimal.zero), colors.neutral);
    });
  });

  group('kindColor', () {
    test('income gains, expense loses, transfer stays neutral', () {
      expect(colors.kindColor(AmountKind.income), colors.gain);
      expect(colors.kindColor(AmountKind.expense), colors.loss);
      expect(colors.kindColor(AmountKind.transfer), colors.neutral);
    });
  });

  test('dark mode resolves its own shades', () {
    final dark = AmountColors.of(ThemeData(brightness: Brightness.dark));
    expect(dark.gain, isNot(colors.gain));
    expect(dark.loss, isNot(colors.loss));
  });
}
