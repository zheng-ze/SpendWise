import 'dart:convert';
import 'dart:typed_data';

import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

/// Scoped E2E key reader: the only key-related dependency the sync engine
/// receives is [accessor], a closure that reads exactly one secret.
/// The raw [SecretStore] and the device credential never leave this class.
final class SyncE2EKeyProvider {
  SyncE2EKeyProvider({required this._secretStore});

  final SecretStore _secretStore;

  SyncE2EKeyAccessor get accessor =>
      () => _readKey();

  Future<Uint8List> _readKey() async {
    final String? stored;
    try {
      stored = await _secretStore.read(syncE2EKeySecretKey);
    } on SecretStoreException {
      throw const SyncE2EKeyUnavailableException(
        SyncE2EKeyUnavailableReason.storageFailed,
      );
    }
    if (stored == null) {
      throw const SyncE2EKeyUnavailableException(
        SyncE2EKeyUnavailableReason.absent,
      );
    }
    return decodeAndValidateSyncE2EKey(stored);
  }
}

/// Decodes an unpadded base64url-encoded E2E key and validates its length.
Uint8List decodeAndValidateSyncE2EKey(String encoded) {
  final Uint8List bytes;
  try {
    bytes = base64Url.decode(_addPadding(encoded));
  } on FormatException {
    throw const SyncE2EKeyUnavailableException(
      SyncE2EKeyUnavailableReason.malformed,
    );
  }
  if (bytes.length != SyncCipher.keyByteCount) {
    throw const SyncE2EKeyUnavailableException(
      SyncE2EKeyUnavailableReason.wrongLength,
    );
  }
  return bytes;
}

String _addPadding(String value) {
  final remainder = value.length % 4;
  if (remainder == 0) return value;
  return value + '=' * (4 - remainder);
}

enum SyncE2EKeyUnavailableReason {
  absent,
  malformed,
  storageFailed,
  wrongLength,
}

final class SyncE2EKeyUnavailableException implements Exception {
  const SyncE2EKeyUnavailableException(this.reason);

  final SyncE2EKeyUnavailableReason reason;

  @override
  String toString() => 'Sync E2E key unavailable (${reason.name}).';
}
