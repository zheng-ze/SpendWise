import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/format/amount_parse.dart';

void main() {
  group('parseAmountInput', () {
    test('parses a plain integer', () {
      expect(parseAmountInput('12'), Decimal.fromInt(12));
    });

    test('parses a decimal value', () {
      expect(parseAmountInput('12.50'), Decimal.parse('12.50'));
    });

    test('parses a negative value', () {
      expect(parseAmountInput('-12.50'), Decimal.parse('-12.50'));
    });

    test('treats an empty string as zero', () {
      expect(parseAmountInput(''), Decimal.zero);
    });

    test('treats a whitespace-only string as zero', () {
      expect(parseAmountInput('   '), Decimal.zero);
    });

    test('trims surrounding whitespace before parsing', () {
      expect(parseAmountInput('  12.50  '), Decimal.parse('12.50'));
    });

    test('returns null for unparseable text', () {
      expect(parseAmountInput('abc'), isNull);
    });

    test('returns null for a thousands-separated value', () {
      expect(parseAmountInput('1,000'), isNull);
    });

    test('returns null for multiple decimal points', () {
      expect(parseAmountInput('1.2.3'), isNull);
    });

    test('returns null for a bare minus sign', () {
      expect(parseAmountInput('-'), isNull);
    });

    test('returns null for a bare decimal point', () {
      expect(parseAmountInput('.'), isNull);
    });

    test('parses a value with no leading digit before the point', () {
      expect(parseAmountInput('.5'), Decimal.parse('0.5'));
    });
  });
}
