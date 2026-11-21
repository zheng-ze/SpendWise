import 'dart:convert';

String credentialPayload(String deviceID, String bearer) => base64Url.encode(
  utf8.encode(
    jsonEncode({
      'deviceID': deviceID,
      'bearerToken': base64Url.encode(utf8.encode(bearer)),
    }),
  ),
);

String deviceSecret([int fill = 0]) =>
    base64Url.encode(List<int>.filled(32, fill)).replaceAll('=', '');
