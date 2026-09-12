part of '../../sync.dart';

enum SyncCollection {
  moneySources('money_sources'),
  entries('entries'),
  categories('categories'),
  plans('plans'),
  budgets('budgets');

  const SyncCollection(this.wireName);
  final String wireName;

  static SyncCollection fromWireName(String value) => values.firstWhere(
        (item) => item.wireName == value,
        orElse: () => throw FormatException('Unknown sync collection: $value'),
      );
}

enum SiblingLifecycle {
  live('live'),
  tombstone('tombstone');

  const SiblingLifecycle(this.wireName);
  final String wireName;

  static SiblingLifecycle fromWireName(String value) => values.firstWhere(
        (item) => item.wireName == value,
        orElse: () =>
            throw FormatException('Unknown sibling lifecycle: $value'),
      );
}

final class SyncEnvelope {
  const SyncEnvelope({
    required this.protocolVersion,
    required this.userID,
    required this.collection,
    required this.rowID,
    required this.siblingID,
    required this.versionVector,
    required this.lifecycle,
    required this.ciphertext,
  });

  factory SyncEnvelope.create({
    required int protocolVersion,
    required String userID,
    required SyncCollection collection,
    required String rowID,
    required VersionVector versionVector,
    required SiblingLifecycle lifecycle,
    required String ciphertext,
  }) {
    final siblingID = computeSiblingID(
      userID: userID,
      collection: collection,
      rowID: rowID,
      versionVector: versionVector,
    );
    return SyncEnvelope(
      protocolVersion: protocolVersion,
      userID: userID,
      collection: collection,
      rowID: rowID,
      siblingID: siblingID,
      versionVector: versionVector,
      lifecycle: lifecycle,
      ciphertext: ciphertext,
    );
  }

  final int protocolVersion;
  final String userID;
  final SyncCollection collection;
  final String rowID;
  final String siblingID;
  final VersionVector versionVector;
  final SiblingLifecycle lifecycle;
  final String ciphertext;

  Map<String, Object?> toWireJson() => <String, Object?>{
        'protocol_version': protocolVersion,
        'user_id': userID,
        'collection': collection.wireName,
        'row_id': rowID,
        'sibling_id': siblingID,
        'version_vector': versionVector.toWireCounters(),
        'lifecycle': lifecycle.wireName,
        'ciphertext': ciphertext,
      };

  Map<String, Object?> aadFields() => <String, Object?>{
        'protocol_version': protocolVersion,
        'user_id': userID,
        'collection': collection.wireName,
        'row_id': rowID,
        'sibling_id': siblingID,
        'version_vector': versionVector.toWireCounters(),
        'lifecycle': lifecycle.wireName,
      };

  Uint8List aadBytes() =>
      Uint8List.fromList(utf8.encode(canonicalJson(aadFields())));

  static SyncEnvelope fromWireJson(Map<String, Object?> value) {
    final rawVector = value['version_vector'];
    if (rawVector is! Map<Object?, Object?>) {
      throw const FormatException('version_vector must be an object.');
    }
    return SyncEnvelope(
      protocolVersion: _expectInt(value, 'protocol_version'),
      userID: _expectString(value, 'user_id'),
      collection:
          SyncCollection.fromWireName(_expectString(value, 'collection')),
      rowID: _expectString(value, 'row_id'),
      siblingID: _expectString(value, 'sibling_id'),
      versionVector: VersionVector.fromWireCounters(
        rawVector.map<String, Object?>(
            (key, item) => MapEntry(key.toString(), item)),
      ),
      lifecycle:
          SiblingLifecycle.fromWireName(_expectString(value, 'lifecycle')),
      ciphertext: _expectString(value, 'ciphertext'),
    );
  }
}

String computeSiblingID({
  required String userID,
  required SyncCollection collection,
  required String rowID,
  required VersionVector versionVector,
}) {
  final input = <String, Object?>{
    'user_id': userID,
    'collection': collection.wireName,
    'row_id': rowID,
    'version_vector': versionVector.toWireCounters(),
  };
  return _sha256Base64UrlUnpadded(canonicalJson(input));
}

String computeSnapshotHash(Iterable<SyncEnvelope> envelopes) {
  final sorted = envelopes.toList()
    ..sort((a, b) => _compareUtf8(a.siblingID, b.siblingID));
  final payload = <Object?>[
    for (final envelope in sorted) envelope.toWireJson()
  ];
  return _sha256Base64UrlUnpadded(canonicalJson(payload));
}

String _expectString(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String) throw FormatException('$key must be a string.');
  return raw;
}

int _expectInt(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! int) throw FormatException('$key must be an integer.');
  return raw;
}
