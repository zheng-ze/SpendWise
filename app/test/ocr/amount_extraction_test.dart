import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ocr/amount_extraction.dart';

RecognizedText textOf(List<String> lines) {
  return RecognizedText(
    lines.map((line) => RecognizedLine(text: line)).toList(),
  );
}

void main() {
  test('subtotalIsNotMistakenForTotal', () {
    final text = textOf(['Coffee Shop', 'SUBTOTAL 8.00', 'TOTAL 9.50']);

    expect(extractAmount(text), Decimal.parse('9.50'));
  });

  test('taxLineIsNotMistakenForTotal', () {
    final text = textOf(['Store', 'SALES TAX 1.20', 'GRAND TOTAL 12.20']);

    expect(extractAmount(text), Decimal.parse('12.20'));
  });

  test('keywordMissFallsBackToLastCurrencyNumber', () {
    final text = textOf([
      'Store',
      'Item A \$4.00',
      'Item B \$6.50',
      'Cash tendered \$10.50',
    ]);

    expect(extractAmount(text), Decimal.parse('10.50'));
  });

  test('amountDueKeywordMatches', () {
    final text = textOf([
      'Utility Co',
      'Previous balance 20.00',
      'AMOUNT DUE 45.75',
    ]);

    expect(extractAmount(text), Decimal.parse('45.75'));
  });

  test('balanceDueAndTotalDueKeywordsMatch', () {
    final balanceDue = textOf(['Clinic', 'BALANCE DUE 200.00']);
    final totalDue = textOf(['Clinic', 'TOTAL DUE 150.00']);

    expect(extractAmount(balanceDue), Decimal.parse('200.00'));
    expect(extractAmount(totalDue), Decimal.parse('150.00'));
  });

  test('noCurrencyNumberAnywhereReturnsNull', () {
    final text = textOf(['Just some text', 'No numbers here']);

    expect(extractAmount(text), isNull);
  });

  test('parsesThousandsSeparatorCurrency', () {
    final text = textOf(['Store', 'TOTAL \$1,234.56']);

    expect(extractAmount(text), Decimal.parse('1234.56'));
  });
}
