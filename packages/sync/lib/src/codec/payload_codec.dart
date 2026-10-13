part of '../../sync.dart';

// MARK: - Payload Codec

/// Hand-written, explicitly versioned codec between sync-payload bytes and the
/// domain entities that back upsert [LedgerChange]s.
///
/// Version 1 is the only emitted version. Tombstones carry no payload, so the
/// codec encodes only entity upserts and rejects empty payloads on decode.
final class PayloadCodec {
  const PayloadCodec();

  static const int currentVersion = 1;

  // MARK: - Encode

  /// Encodes [change] to payload bytes.
  ///
  /// Upserts serialize the underlying entity; deletes are payload-free and
  /// return an empty list.
  List<int> encodeChange(LedgerChange change) {
    final data = _encodeData(change);
    if (data == null) return const <int>[];
    final payload = <String, Object?>{
      'version': currentVersion,
      'entity': data.entity,
      'data': data.fields,
    };
    return utf8.encode(canonicalJson(payload));
  }

  // MARK: - Decode

  /// Decodes [payload] into the upsert [LedgerChange] that produced it.
  ///
  /// Throws [PayloadDecodeError] for an empty, malformed, or unsupported
  /// payload.
  LedgerChange decodeChange(List<int> payload) {
    if (payload.isEmpty) {
      throw const PayloadDecodeError(
        'Payload is empty; tombstones carry no entity payload.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payload));
    } on FormatException {
      throw const PayloadDecodeError('Payload is not valid JSON.');
    }
    if (decoded is! Map<Object?, Object?>) {
      throw const PayloadDecodeError(
          'Payload must be a canonical JSON object.');
    }
    final map = decoded.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
    final version = _int(map, 'version');
    if (version != currentVersion) {
      throw PayloadDecodeError(
        'Unsupported payload version: $version.',
      );
    }
    final entity = _str(map, 'entity');
    final data = map['data'];
    if (data is! Map<String, Object?>) {
      throw const PayloadDecodeError('Payload data must be an object.');
    }
    return _decodeEntity(entity, data);
  }
}
