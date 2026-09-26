part of '../../sync.dart';

final class StartDeviceBindingRequest {
  StartDeviceBindingRequest({
    required this.identifier,
    required String deviceID,
    this.protocolMajor = syncOperationMajor,
  }) : deviceID = normalizedID(deviceID);

  final String identifier;
  final String deviceID;
  final int protocolMajor;

  Map<String, Object?> toWireJson() => <String, Object?>{
        'protocol_major': protocolMajor,
        'identifier': identifier,
        'device_id': deviceID,
      };

  factory StartDeviceBindingRequest.fromWireJson(Map<String, Object?> value) {
    _expectOperationMajor(value);
    return StartDeviceBindingRequest(
      identifier: _expectString(value, 'identifier'),
      deviceID: _expectString(value, 'device_id'),
      protocolMajor: _expectOperationMajor(value),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StartDeviceBindingRequest &&
      other.identifier == identifier &&
      other.deviceID == deviceID &&
      other.protocolMajor == protocolMajor;

  @override
  int get hashCode => Object.hash(identifier, deviceID, protocolMajor);
}

final class StartDeviceBindingResponse {
  const StartDeviceBindingResponse({
    required this.challengeID,
    required this.expiresAt,
    this.protocolMajor = syncOperationMajor,
  });

  final String challengeID;
  final DateTime expiresAt;
  final int protocolMajor;

  Map<String, Object?> toWireJson() => <String, Object?>{
        'protocol_major': protocolMajor,
        'challenge_id': challengeID,
        'expires_at': expiresAt.toUtc().toIso8601String(),
      };

  factory StartDeviceBindingResponse.fromWireJson(Map<String, Object?> value) {
    final protocolMajor = _expectOperationMajor(value);
    final challengeID = _expectString(value, 'challenge_id');
    if (challengeID.isEmpty) {
      throw const FormatException(
        'Binding challenge_id must not be empty.',
      );
    }
    final expiresRaw = _expectString(value, 'expires_at');
    final expiresAt = DateTime.tryParse(expiresRaw)?.toUtc();
    if (expiresAt == null) {
      throw const FormatException(
        'Binding expires_at must be an RFC 3339 timestamp.',
      );
    }
    return StartDeviceBindingResponse(
      challengeID: challengeID,
      expiresAt: expiresAt,
      protocolMajor: protocolMajor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StartDeviceBindingResponse &&
      other.challengeID == challengeID &&
      other.expiresAt == expiresAt &&
      other.protocolMajor == protocolMajor;

  @override
  int get hashCode => Object.hash(challengeID, expiresAt, protocolMajor);
}

final class VerifyDeviceBindingRequest {
  VerifyDeviceBindingRequest({
    required this.challengeID,
    required this.identifier,
    required String deviceID,
    required this.otp,
    this.protocolMajor = syncOperationMajor,
  }) : deviceID = normalizedID(deviceID);

  final String challengeID;
  final String identifier;
  final String deviceID;
  final String otp;
  final int protocolMajor;

  Map<String, Object?> toWireJson() => <String, Object?>{
        'protocol_major': protocolMajor,
        'challenge_id': challengeID,
        'identifier': identifier,
        'device_id': deviceID,
        'otp': otp,
      };

  factory VerifyDeviceBindingRequest.fromWireJson(Map<String, Object?> value) {
    return VerifyDeviceBindingRequest(
      challengeID: _expectString(value, 'challenge_id'),
      identifier: _expectString(value, 'identifier'),
      deviceID: _expectString(value, 'device_id'),
      otp: _expectString(value, 'otp'),
      protocolMajor: _expectOperationMajor(value),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VerifyDeviceBindingRequest &&
      other.challengeID == challengeID &&
      other.identifier == identifier &&
      other.deviceID == deviceID &&
      other.otp == otp &&
      other.protocolMajor == protocolMajor;

  @override
  int get hashCode =>
      Object.hash(challengeID, identifier, deviceID, otp, protocolMajor);
}

final class VerifyDeviceBindingResponse {
  VerifyDeviceBindingResponse({
    required String accessToken,
    required String bindingAuthorization,
    required this.authorizationExpiresAt,
    this.protocolMajor = syncOperationMajor,
  })  : _accessToken = accessToken,
        _bindingAuthorization = bindingAuthorization;

  final DateTime authorizationExpiresAt;
  final int protocolMajor;
  final String _accessToken;
  final String _bindingAuthorization;

  BeginReconcile authorizeBegin() =>
      BeginReconcile(bindingAuthorization: _bindingAuthorization);

  DeviceCredential sessionCredential(String deviceID) => DeviceCredential._(
        deviceID: normalizedID(deviceID),
        bearerToken: _accessToken,
      );

  Map<String, Object?> toWireJson() => <String, Object?>{
        'protocol_major': protocolMajor,
        'access_token': _accessToken,
        'binding_authorization': _bindingAuthorization,
        'authorization_expires_at':
            authorizationExpiresAt.toUtc().toIso8601String(),
      };

  factory VerifyDeviceBindingResponse.fromWireJson(Map<String, Object?> value) {
    final protocolMajor = _expectOperationMajor(value);
    final accessToken = _expectString(value, 'access_token');
    final bindingAuthorization = _expectString(value, 'binding_authorization');
    if (accessToken.isEmpty || bindingAuthorization.isEmpty) {
      throw const FormatException(
        'Binding verify response must carry non-empty credentials.',
      );
    }
    final expiresRaw = _expectString(value, 'authorization_expires_at');
    final authorizationExpiresAt = DateTime.tryParse(expiresRaw)?.toUtc();
    if (authorizationExpiresAt == null) {
      throw const FormatException(
        'Binding authorization_expires_at must be an RFC 3339 timestamp.',
      );
    }
    return VerifyDeviceBindingResponse(
      accessToken: accessToken,
      bindingAuthorization: bindingAuthorization,
      authorizationExpiresAt: authorizationExpiresAt,
      protocolMajor: protocolMajor,
    );
  }

  @override
  String toString() => 'VerifyDeviceBindingResponse(accessToken: <redacted>, '
      'bindingAuthorization: <redacted>, '
      'authorizationExpiresAt: $authorizationExpiresAt)';

  @override
  bool operator ==(Object other) =>
      other is VerifyDeviceBindingResponse &&
      other._accessToken == _accessToken &&
      other._bindingAuthorization == _bindingAuthorization &&
      other.authorizationExpiresAt == authorizationExpiresAt &&
      other.protocolMajor == protocolMajor;

  @override
  int get hashCode => Object.hash(
        _accessToken,
        _bindingAuthorization,
        authorizationExpiresAt,
        protocolMajor,
      );
}

int _expectOperationMajor(Map<String, Object?> value) {
  final raw = value['protocol_major'];
  if (raw is! int || raw != syncOperationMajor) {
    throw FormatException(
      'protocol_major must be $syncOperationMajor.',
    );
  }
  return raw;
}
