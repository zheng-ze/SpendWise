part of '../../sync.dart';

/// Opaque credential accepted by [SyncBackend].
sealed class SyncCredential {
  const SyncCredential._();
}

/// Device-scoped credential produced by a matching [SyncAuthenticator].
final class DeviceCredential extends SyncCredential {
  const DeviceCredential._({
    required this.deviceID,
    required String bearerToken,
  })  : _bearerToken = bearerToken,
        super._();

  final String deviceID;
  final String _bearerToken;

  @override
  String toString() =>
      'DeviceCredential(deviceID: $deviceID, token: <redacted>)';

  @override
  bool operator ==(Object other) =>
      other is DeviceCredential &&
      other.deviceID == deviceID &&
      other._bearerToken == _bearerToken;

  @override
  int get hashCode => Object.hash(deviceID, _bearerToken);
}
