import 'dart:collection';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:spendwise/persistence/ledger_database.dart';

/// Raised instead of returning an empty vector, because an empty vector claims
/// the row has no write history and so drops every causal relationship it had.
class VersionVectorDecodeError implements Exception {
  const VersionVectorDecodeError(this.reason);

  final String reason;

  @override
  String toString() => 'VersionVectorDecodeError($reason)';
}

/// Merging is deliberately absent, belonging to the sync engine that does not
/// exist yet.
class VersionVector {
  factory VersionVector(Map<String, int> counters) {
    final normalized = <String, int>{};
    for (final entry in counters.entries) {
      if (entry.value != 0) normalized[normalizedID(entry.key)] = entry.value;
    }
    return VersionVector._(normalized);
  }

  const VersionVector._(this._counters);

  static const empty = VersionVector._(<String, int>{});

  final Map<String, int> _counters;

  Map<String, int> get counters => UnmodifiableMapView(_counters);

  VersionVector bump(String device) {
    final key = normalizedID(device);
    return VersionVector._({..._counters, key: (_counters[key] ?? 0) + 1});
  }

  /// A device absent from either side counts as zero, so an empty vector
  /// dominates only other empty vectors.
  bool dominates(VersionVector other) {
    for (final entry in other._counters.entries) {
      if ((_counters[entry.key] ?? 0) < entry.value) return false;
    }
    return true;
  }

  bool isConcurrent(VersionVector other) =>
      !dominates(other) && !other.dominates(this);

  List<int> encode() => utf8.encode(json.encode(_counters));

  /// An empty blob is a row with no history yet, distinct from a corrupt one.
  static VersionVector decode(List<int> blob) {
    if (blob.isEmpty) return empty;

    final Object? decoded;
    try {
      decoded = json.decode(utf8.decode(blob));
    } on FormatException catch (error) {
      throw VersionVectorDecodeError(error.message);
    }

    return switch (decoded) {
      Map<String, dynamic> map when map.keys.join() == 'counters' =>
        _fromEither(map['counters']),
      _ => _fromEither(decoded),
    };
  }

  static VersionVector _fromEither(Object? decoded) => switch (decoded) {
    Map<String, dynamic> map => _fromObject(map),
    List<dynamic> flat => _fromAlternatingArray(flat),
    _ => throw VersionVectorDecodeError('expected an object or array'),
  };

  static VersionVector _fromObject(Map<String, dynamic> map) {
    final counters = <String, int>{};
    for (final entry in map.entries) {
      counters[entry.key] = _count(entry.value);
    }
    return VersionVector(counters);
  }

  static VersionVector _fromAlternatingArray(List<dynamic> flat) {
    if (flat.length.isOdd) {
      throw const VersionVectorDecodeError('odd-length alternating array');
    }
    final counters = <String, int>{};
    for (var i = 0; i < flat.length; i += 2) {
      final device = flat[i];
      if (device is! String) {
        throw const VersionVectorDecodeError('device id is not a string');
      }
      counters[device] = _count(flat[i + 1]);
    }
    return VersionVector(counters);
  }

  static int _count(Object? value) => switch (value) {
    final int count when count >= 0 => count,
    _ => throw VersionVectorDecodeError('bad count $value'),
  };

  @override
  bool operator ==(Object other) =>
      other is VersionVector &&
      other._counters.length == _counters.length &&
      _counters.entries.every((e) => other._counters[e.key] == e.value);

  /// Order-independent, so equal vectors hash alike whatever order they were
  /// built in.
  @override
  int get hashCode => _counters.entries.fold(
    _counters.length,
    (hash, e) => hash ^ Object.hash(e.key, e.value),
  );

  @override
  String toString() => 'VersionVector($_counters)';
}

final _cachedDeviceIDs = Expando<Future<String>>();

Future<String> deviceID(LedgerDatabase db) =>
    _cachedDeviceIDs[db] ??= _claimDeviceID(db);

Future<String> _claimDeviceID(LedgerDatabase db) async {
  final existing = await db.select(db.storeMeta).getSingleOrNull();
  if (existing != null) return normalizedID(existing.deviceId);

  final claimed = normalizedID(newID());
  await db
      .into(db.storeMeta)
      .insert(StoreMetaRow(id: 0, deviceId: claimed, hasSeeded: false));
  return claimed;
}
