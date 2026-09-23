import 'dart:async';

import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

final class CredentialProvider {
  CredentialProvider({required this._database, SecretStore? secretStore})
    : _secretStore = secretStore ?? SecureSecretStore();

  final LedgerDatabase _database;
  final SecretStore _secretStore;

  Future<T> withCredential<T>(
    FutureOr<T> Function(DeviceCredential credential) use,
  ) async {
    final String? payload;
    try {
      payload = await _secretStore.read(syncCredentialSecretKey);
    } catch (_) {
      throw const CredentialUnavailableException(
        CredentialUnavailableReason.storageFailed,
      );
    }
    if (payload == null) {
      throw const CredentialUnavailableException(
        CredentialUnavailableReason.absent,
      );
    }

    final DeviceCredential credential;
    try {
      credential = const CredentialCodec().restore(payload);
    } on FormatException {
      throw const CredentialUnavailableException(
        CredentialUnavailableReason.malformed,
      );
    }

    final String currentDeviceID;
    try {
      currentDeviceID = await deviceID(_database);
    } catch (_) {
      throw const CredentialUnavailableException(
        CredentialUnavailableReason.identityFailed,
      );
    }
    if (credential.deviceID != currentDeviceID) {
      throw const CredentialUnavailableException(
        CredentialUnavailableReason.identityFailed,
      );
    }

    return use(credential);
  }
}

enum CredentialUnavailableReason {
  absent,
  malformed,
  storageFailed,
  identityFailed,
}

final class CredentialUnavailableException implements Exception {
  const CredentialUnavailableException(this.reason);

  final CredentialUnavailableReason reason;

  @override
  String toString() => 'Sync credential unavailable (${reason.name}).';
}
