import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ocr/date_extraction.dart';

RecognizedText textOf(List<String> lines) {
  return RecognizedText(
    lines.map((line) => RecognizedLine(text: line)).toList(),
  );
}

void main() {
  test('numberOverTwelveResolvesDayRegardlessOfLocale', () {
    final text = textOf(['Store', '13/04/25', 'TOTAL 9.00']);

    final result = extractDate(text, locale: 'en_US');

    expect(result, DateTime.utc(2025, 4, 13));
  });

  test('numberOverTwelveResolvesDayEvenUnderDayFirstLocale', () {
    final text = textOf(['Store', '04/13/25', 'TOTAL 9.00']);

    final result = extractDate(text, locale: 'en_GB');

    expect(result, DateTime.utc(2025, 4, 13));
  });

  test('bothNumbersAmbiguousFallsBackToUsLocaleMonthFirst', () {
    final text = textOf(['Store', '03/04/25', 'TOTAL 9.00']);

    final result = extractDate(text, locale: 'en_US');

    expect(result, DateTime.utc(2025, 3, 4));
  });

  test('bothNumbersAmbiguousFallsBackToGbLocaleDayFirst', () {
    final text = textOf(['Store', '03/04/25', 'TOTAL 9.00']);

    final result = extractDate(text, locale: 'en_GB');

    expect(result, DateTime.utc(2025, 4, 3));
  });

  test('noDateShapedTextDefaultsToNow', () {
    final text = textOf(['Store', 'No date here', 'TOTAL 9.00']);
    final fixedNow = DateTime.utc(2026, 8, 22, 14, 30);

    final result = extractDate(text, now: fixedNow);

    expect(result, DateTime.utc(2026, 8, 22));
  });
}
