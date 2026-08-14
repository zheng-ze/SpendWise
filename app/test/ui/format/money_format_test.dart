import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/money_format.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  group('formatCurrency', () {
    test('groups thousands and always shows two decimal places', () {
      expect(formatCurrency(dec('3200')), r'$3,200.00');
      expect(formatCurrency(dec('1234567.5')), r'$1,234,567.50');
      expect(formatCurrency(dec('0')), r'$0.00');
    });

    test('shows the magnitude of a negative amount with a leading minus', () {
      expect(formatCurrency(dec('-42.5')), r'-$42.50');
    });
  });

  group('formatSignedAmount', () {
    test('income is prefixed positive and expense negative, both unsigned', () {
      expect(formatSignedAmount(dec('12.5'), AmountKind.income), r'+$12.50');
      expect(formatSignedAmount(dec('-12.5'), AmountKind.expense), r'-$12.50');
    });

    test('a stored expense magnitude is negated regardless of its sign', () {
      expect(formatSignedAmount(dec('12.5'), AmountKind.expense), r'-$12.50');
      expect(formatSignedAmount(dec('-12.5'), AmountKind.income), r'+$12.50');
    });

    test('a transfer carries no sign', () {
      expect(formatSignedAmount(dec('-12.5'), AmountKind.transfer), r'$12.50');
    });
  });

  group('formatPlainAmount', () {
    test('has two decimal places, no grouping and no symbol', () {
      expect(formatPlainAmount(dec('3200')), '3200.00');
      expect(formatPlainAmount(dec('-7.5')), '-7.50');
    });

    test('rounds a third fraction digit rather than truncating', () {
      expect(formatPlainAmount(dec('1.006')), '1.01');
      expect(formatPlainAmount(dec('1.004')), '1.00');
    });
  });

  test('formatPercent has no fraction digits', () {
    expect(formatPercent(0.6449), '64%');
    expect(formatPercent(0), '0%');
    expect(formatPercent(1), '100%');
  });
}
