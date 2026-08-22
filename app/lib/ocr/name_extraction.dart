import 'package:ocr/ocr.dart';

const _scanDepth = 5;
const _maxConsecutiveSkips = 3;
const _minLength = 3;
const _maxLength = 35;
const _maxWords = 6;
const _maxDigitDensity = 0.2;

final _addressPattern = RegExp(
  r'\d+\s+\w+\s+(street|st|avenue|ave|road|rd|drive|dr|lane|ln|blvd|boulevard)',
  caseSensitive: false,
);
final _phonePattern = RegExp(r'(\(\d{3}\)\s?|\d{3}[-.\s])\d{3}[-.\s]\d{4}');
final _urlOrEmailOrHandlePattern = RegExp(
  r'(https?://|www\.|@|\.com|\.net|\.org)',
  caseSensitive: false,
);
final _boilerplateKeywords = [
  'STORE #',
  'REG',
  'TERM',
  'THANK YOU',
  'RECEIPT',
  'INVOICE',
];
final _greetingKeywords = ['WELCOME TO', 'CUSTOMER COPY', 'DUPLICATE'];
final _alphabeticCharacter = RegExp(r'[a-zA-Z]');
final _digit = RegExp(r'\d');

/// Extracts the merchant name from the first few lines, or null if none of
/// them look like a name rather than an address, phone number, or banner.
String? extractName(RecognizedText text) {
  final scanned = text.lines.take(_scanDepth).toList();

  String? bestCandidate;
  double? bestHeight;
  var consecutiveSkips = 0;

  for (final line in scanned) {
    if (_isSkippable(line.text)) {
      consecutiveSkips++;
      if (bestCandidate == null && consecutiveSkips >= _maxConsecutiveSkips) {
        return null;
      }
      continue;
    }
    consecutiveSkips = 0;

    if (!_looksLikeAName(line.text)) continue;

    final height = line.bounds?.height;
    if (bestCandidate == null) {
      bestCandidate = line.text;
      bestHeight = height;
    } else if (bestHeight != null && height != null && height > bestHeight) {
      bestCandidate = line.text;
      bestHeight = height;
    }
  }

  return bestCandidate;
}

bool _isSkippable(String line) {
  final upper = line.toUpperCase();
  return _addressPattern.hasMatch(line) ||
      _phonePattern.hasMatch(line) ||
      _urlOrEmailOrHandlePattern.hasMatch(line) ||
      _boilerplateKeywords.any(upper.contains) ||
      _greetingKeywords.any(upper.contains);
}

bool _looksLikeAName(String line) {
  final trimmed = line.trim();
  if (trimmed.length < _minLength || trimmed.length > _maxLength) return false;
  if (trimmed.split(RegExp(r'\s+')).length > _maxWords) return false;
  if (!_alphabeticCharacter.hasMatch(trimmed)) return false;
  return _digitDensity(trimmed) < _maxDigitDensity;
}

double _digitDensity(String text) {
  final digitCount = _digit.allMatches(text).length;
  return digitCount / text.length;
}
