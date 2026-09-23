import 'package:decimal/decimal.dart';
import 'package:ocr/ocr.dart';

final _grandTotalKeywords = [
  'TOTAL DUE',
  'GRAND TOTAL',
  'AMOUNT DUE',
  'BALANCE DUE',
  'TOTAL',
];
final _falseMatchKeywords = ['SUBTOTAL', 'TAX'];
final _currencyNumber = RegExp(
  r'\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+\.\d{1,2})',
);

Decimal? extractAmount(RecognizedText text) {
  for (final line in text.lines) {
    final upper = line.text.toUpperCase();
    if (_falseMatchKeywords.any(upper.contains)) continue;
    if (!_grandTotalKeywords.any(upper.contains)) continue;

    final match = _lastCurrencyMatch(line.text);
    if (match != null) return match;
  }

  return _lastCurrencyNumberInReceipt(text);
}

Decimal? _lastCurrencyNumberInReceipt(RecognizedText text) {
  Decimal? last;
  for (final line in text.lines) {
    final match = _lastCurrencyMatch(line.text);
    if (match != null) last = match;
  }
  return last;
}

Decimal? _lastCurrencyMatch(String line) {
  Decimal? last;
  for (final match in _currencyNumber.allMatches(line)) {
    final digits = match.group(1)?.replaceAll(',', '');
    if (digits == null) continue;
    last = Decimal.tryParse(digits) ?? last;
  }
  return last;
}
