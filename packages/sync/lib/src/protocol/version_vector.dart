part of '../../sync.dart';

/// Causal version vector relocated from the app persistence layer.
///
/// The persistence codec intentionally remains distinct from the sync wire
/// representation: [encode]/[decode] use the existing UTF-8 JSON blob format,
/// while [toWireCounters]/[fromWireCounters] use decimal strings as required by
/// the sync protocol.
final class VersionVector {
  factory VersionVector(Map<String, int> counters) {
    final normalized = <String, int>{};
    for (final entry in counters.entries) {
      if (entry.value < 0) {
        throw VersionVectorDecodeError(
          'Counter for ${entry.key} must be a non-negative integer.',
        );
      }
      if (entry.value == 0) continue;

      final key = normalizedID(entry.key);
      if (normalized.containsKey(key)) {
        throw VersionVectorDecodeError(
          'Multiple device IDs normalize to the same ID: $key.',
        );
      }
      normalized[key] = entry.value;
    }

    if (normalized.isEmpty) return empty;
    return VersionVector._(Map.unmodifiable(normalized));
  }

  const VersionVector._(this._counters);

  static const VersionVector empty = VersionVector._(<String, int>{});

  final Map<String, int> _counters;

  Map<String, int> get counters => _counters;

  VersionVector bump(String deviceID) {
    final id = normalizedID(deviceID);
    final next = Map<String, int>.of(_counters);
    next[id] = (next[id] ?? 0) + 1;
    return VersionVector(next);
  }

  /// Whether this vector is causally at or after [other].
  ///
  /// Dominance is reflexive: a vector dominates an equal vector.
  bool dominates(VersionVector other) {
    for (final entry in other._counters.entries) {
      if ((_counters[entry.key] ?? 0) < entry.value) return false;
    }
    return true;
  }

  bool isConcurrent(VersionVector other) =>
      !dominates(other) && !other.dominates(this);

  /// Existing persistence codec: a UTF-8 JSON byte blob with integer counters.
  List<int> encode() => utf8.encode(jsonEncode(_counters));

  /// Decodes the existing persistence representation.
  ///
  /// Empty blobs are the empty vector. Both the normalized JSON-object form and
  /// the legacy Swift alternating-array form are accepted for backwards
  /// compatibility with pre-existing stored rows.
  static VersionVector decode(List<int> encoded) {
    if (encoded.isEmpty) return empty;

    try {
      final decoded = jsonDecode(utf8.decode(encoded));
      final value = decoded is Map<String, dynamic> &&
              decoded.length == 1 &&
              decoded.containsKey('counters')
          ? decoded['counters']
          : decoded;
      return _fromEither(value);
    } on VersionVectorDecodeError {
      rethrow;
    } on Object catch (error) {
      throw VersionVectorDecodeError('Invalid version vector: $error');
    }
  }

  static VersionVector _fromEither(Object? value) {
    if (value is Map<String, dynamic>) {
      final counters = <String, int>{};
      for (final entry in value.entries) {
        final raw = entry.value;
        if (raw is! int) {
          throw VersionVectorDecodeError(
            'Counter for ${entry.key} must be an integer.',
          );
        }
        counters[entry.key] = raw;
      }
      return VersionVector(counters);
    }
    if (value is List<dynamic>) {
      return _fromAlternatingArray(value);
    }
    throw const VersionVectorDecodeError(
      'Version vector must be a JSON object or legacy alternating array.',
    );
  }

  static VersionVector _fromAlternatingArray(List<dynamic> values) {
    if (values.length.isOdd) {
      throw const VersionVectorDecodeError(
        'Legacy version vector must contain alternating device IDs and counters.',
      );
    }

    final counters = <String, int>{};
    for (var index = 0; index < values.length; index += 2) {
      final rawDeviceID = values[index];
      final rawCounter = values[index + 1];
      if (rawDeviceID is! String || rawCounter is! int) {
        throw const VersionVectorDecodeError(
          'Legacy version vector must alternate string device IDs and integer counters.',
        );
      }
      counters[rawDeviceID] = rawCounter;
    }
    return VersionVector(counters);
  }

  /// Protocol representation: version-vector counters are decimal strings.
  Map<String, String> toWireCounters() {
    final keys = _counters.keys.toList()..sort();
    return Map.unmodifiable(<String, String>{
      for (final key in keys) key: _counters[key]!.toString(),
    });
  }

  static VersionVector fromWireCounters(Map<String, Object?> value) {
    final counters = <String, int>{};
    for (final entry in value.entries) {
      final raw = entry.value;
      if (raw is! String || !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(raw)) {
        throw VersionVectorDecodeError(
          'Wire counter for ${entry.key} must be a non-negative decimal string.',
        );
      }
      counters[entry.key] = int.parse(raw);
    }
    return VersionVector(counters);
  }

  @override
  bool operator ==(Object other) {
    if (other is! VersionVector || other._counters.length != _counters.length) {
      return false;
    }
    for (final entry in _counters.entries) {
      if (other._counters[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final keys = _counters.keys.toList()..sort();
    return Object.hashAll(keys.expand((key) => <Object>[key, _counters[key]!]));
  }

  @override
  String toString() {
    final keys = _counters.keys.toList()..sort();
    final entries = keys.map((key) => '$key:${_counters[key]}').join(', ');
    return 'VersionVector($entries)';
  }
}

final class VersionVectorDecodeError implements FormatException {
  const VersionVectorDecodeError(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'VersionVectorDecodeError: $message';
}
