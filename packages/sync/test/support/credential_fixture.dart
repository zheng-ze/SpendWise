import 'dart:convert';

import 'package:sync/sync.dart';

String credentialPayload(
    {required String deviceID, required String bearerToken}) {
  return base64Url.encode(utf8.encode(jsonEncode({
    'deviceID': deviceID,
    'bearerToken': base64Url.encode(utf8.encode(bearerToken)),
  })));
}

DeviceCredential restoreTestCredential({
  required String deviceID,
  required String bearerToken,
}) {
  return const CredentialCodec().restore(
    credentialPayload(deviceID: deviceID, bearerToken: bearerToken),
  );
}
