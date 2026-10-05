import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/money_format.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  group('formatMoney', () {
    test('shows the symbol with grouping and two decimal places', () {
      expect(formatMoney(dec('3200')), 'S\$3,200.00');
      expect(formatMoney(dec('1234567.5')), 'S\$1,234,567.50');
      expect(formatMoney(dec('0')), 'S\$0.00');
    });

    test('shows the magnitude of a negative amount with a leading minus', () {
      expect(formatMoney(dec('-42.5')), '-S\$42.50');
    });

    test('a bare variant omits the symbol but keeps grouping and sign', () {
      expect(formatMoney(dec('3200'), symbol: false), '3,200.00');
      expect(formatMoney(dec('-42.5'), symbol: false), '-42.50');
    });

    test('rounds half even without converting through double', () {
      expect(formatMoney(dec('1.005')), 'S\$1.00');
      expect(formatMoney(dec('1.015')), 'S\$1.02');
      expect(formatMoney(dec('1.025')), 'S\$1.02');
      expect(formatMoney(dec('2.675')), 'S\$2.68');
    });
  });

  group('formatSignedMoney', () {
    test('income is prefixed positive and expense negative', () {
      expect(
        formatSignedMoney(dec('12.5'), kind: AmountKind.income),
        '+S\$12.50',
      );
      expect(
        formatSignedMoney(dec('12.5'), kind: AmountKind.expense),
        '-S\$12.50',
      );
    });

    test('a transfer carries no sign', () {
      expect(
        formatSignedMoney(dec('12.5'), kind: AmountKind.transfer),
        'S\$12.50',
      );
    });

    test('without a kind the sign follows the value', () {
      expect(formatSignedMoney(dec('3032.6')), '+S\$3,032.60');
      expect(formatSignedMoney(dec('-167.4')), '-S\$167.40');
      expect(formatSignedMoney(dec('0')), 'S\$0.00');
    });

    test('a bare variant omits the symbol but keeps the sign', () {
      expect(
        formatSignedMoney(dec('12.5'), kind: AmountKind.income, symbol: false),
        '+12.50',
      );
      expect(formatSignedMoney(dec('-167.4'), symbol: false), '-167.40');
    });
  });

  group('formatPlainAmount', () {
    test('has two decimal places, no grouping and no symbol', () {
      expect(formatPlainAmount(dec('3200')), '3200.00');
      expect(formatPlainAmount(dec('-7.5')), '-7.50');
    });

    test('rounds half even rather than truncating', () {
      expect(formatPlainAmount(dec('1.006')), '1.01');
      expect(formatPlainAmount(dec('1.004')), '1.00');
      expect(formatPlainAmount(dec('1.005')), '1.00');
      expect(formatPlainAmount(dec('1.015')), '1.02');
    });
  });

  test('formatPercent has no fraction digits', () {
    expect(formatPercent(0.6449), '64%');
    expect(formatPercent(0), '0%');
    expect(formatPercent(1), '100%');
  });
}
