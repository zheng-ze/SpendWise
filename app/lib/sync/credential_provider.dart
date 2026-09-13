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

  /// Restores and checks the current credential before invoking [use].
  /// The callback must keep credential use within its returned future.
  Future<T> withCredential<T>(
    FutureOr<T> Function(DeviceCredential credential) use,
  ) async {
    final DeviceCredential credential;
    try {
      final payload = await _secretStore.read(syncCredentialSecretKey);
      if (payload == null) throw const CredentialUnavailableException();
      credential = const CredentialCodec().restore(payload);
      if (credential.deviceID != await deviceID(_database)) {
        throw const CredentialUnavailableException();
      }
    } catch (_) {
      throw const CredentialUnavailableException();
    }
    return use(credential);
  }
}

final class CredentialUnavailableException implements Exception {
  const CredentialUnavailableException();

  @override
  String toString() => 'Sync credential unavailable.';
}
