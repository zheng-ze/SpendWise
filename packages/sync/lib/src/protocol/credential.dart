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

/// Device-bound credential layering an in-memory device secret over a bearer.
///
/// [DeviceCredential] stays bearer plus device ID only so routine reauth can
/// replace the bearer without touching the secret. Binding repair never
/// enters through this type: callers that hold only a bearer must not be
/// able to present it where a bound credential is required.
final class BoundDeviceCredential extends SyncCredential {
  BoundDeviceCredential._({
    required this.deviceID,
    required String bearerToken,
    required String deviceSecret,
  })  : _bearerToken = bearerToken,
        _deviceSecret = deviceSecret,
        super._();

  factory BoundDeviceCredential.bind(
    DeviceCredential credential, {
    required String deviceSecret,
  }) =>
      BoundDeviceCredential._(
        deviceID: normalizedID(credential.deviceID),
        bearerToken: credential._bearerToken,
        deviceSecret: deviceSecret,
      );

  final String deviceID;
  final String _bearerToken;
  final String _deviceSecret;

  @override
  String toString() =>
      'BoundDeviceCredential(deviceID: $deviceID, token: <redacted>, '
      'deviceSecret: <redacted>)';

  @override
  bool operator ==(Object other) =>
      other is BoundDeviceCredential &&
      other.deviceID == deviceID &&
      other._bearerToken == _bearerToken &&
      other._deviceSecret == _deviceSecret;

  @override
  int get hashCode => Object.hash(deviceID, _bearerToken, _deviceSecret);
}
