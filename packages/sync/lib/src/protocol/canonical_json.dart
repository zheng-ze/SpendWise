part of '../../sync.dart';

/// Canonical JSON for the protocol's data model.
///
/// This implements the canonical JSON subset required by SpendWise's sync
/// protocol: objects with string keys sorted by Unicode code point, arrays,
/// strings, booleans, null, and integers. Floating-point numbers are
/// intentionally rejected so a future protocol change cannot silently use a
/// non-canonical number formatter.
String canonicalJson(Object? value) => _canonicalJson(value);

String _canonicalJson(Object? value) {
  if (value == null || value is bool || value is String || value is int) {
    return jsonEncode(value);
  }
  if (value is num) {
    throw ArgumentError.value(
      value,
      'value',
      'Non-integer JSON numbers are not supported by the protocol canonicalizer.',
    );
  }
  if (value is List<Object?>) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort(_compareCodePoints);
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  throw ArgumentError.value(
      value, 'value', 'Unsupported canonical JSON value.');
}

int _compareCodePoints(String a, String b) {
  final aa = a.runes.iterator;
  final bb = b.runes.iterator;

  while (true) {
    final hasA = aa.moveNext();
    final hasB = bb.moveNext();
    if (!hasA || !hasB) {
      if (hasA) return 1;
      if (hasB) return -1;
      return 0;
    }

    final comparison = aa.current.compareTo(bb.current);
    if (comparison != 0) return comparison;
  }
}

String _sha256Base64UrlUnpadded(String canonical) {
  final digest = sha256.convert(utf8.encode(canonical));
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}

int _compareUtf8(String a, String b) {
  final aa = utf8.encode(a);
  final bb = utf8.encode(b);
  final length = aa.length < bb.length ? aa.length : bb.length;
  for (var i = 0; i < length; i++) {
    final comparison = aa[i].compareTo(bb[i]);
    if (comparison != 0) return comparison;
  }
  return aa.length.compareTo(bb.length);
}
