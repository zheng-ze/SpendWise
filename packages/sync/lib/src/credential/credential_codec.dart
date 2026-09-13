part of '../../sync.dart';

/// Production credential persistence codec.
///
/// Exports an authenticated [DeviceCredential] to an opaque secure-storage
/// payload and restores it without ever surfacing the private bearer token
/// through public values, stringification, diagnostics, logs, or failures.
///
/// The token is stored base64url-encoded inside the payload, which itself is
/// base64url-encoded, so the raw bearer never appears as a substring of the
/// exported payload. The private [DeviceCredential._] constructor is the only
/// path that reconstructs the bearer, keeping it out of the public API.
final class CredentialCodec {
  const CredentialCodec();

  String export(DeviceCredential credential) {
    final body = <String, Object?>{
      'deviceID': credential.deviceID,
      'bearerToken': base64Url.encode(utf8.encode(credential._bearerToken)),
    };
    return base64Url.encode(utf8.encode(jsonEncode(body)));
  }

  DeviceCredential restore(String payload) {
    final decoded = jsonDecode(utf8.decode(_decodeBase64Url(payload)));
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException(
        'Credential payload must be a JSON object.',
      );
    }
    final map = decoded.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
    final deviceID = map['deviceID'];
    final bearerB64 = map['bearerToken'];
    if (deviceID is! String || bearerB64 is! String) {
      throw const FormatException('Credential payload is malformed.');
    }
    final bearer = utf8.decode(_decodeBase64Url(bearerB64));
    // Reconstruct through the private constructor so the bearer never reaches
    // any public factory or field.
    return DeviceCredential._(
        deviceID: normalizedID(deviceID), bearerToken: bearer);
  }

  Uint8List _decodeBase64Url(String value) {
    final remainder = value.length % 4;
    final padded = remainder == 0 ? value : value + '=' * (4 - remainder);
    return Uint8List.fromList(base64Url.decode(padded));
  }
}
