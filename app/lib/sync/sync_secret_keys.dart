import 'dart:convert';

const syncCredentialSecretKey = 'spendwise.sync.device-credential';
const syncDeviceSecretKey = 'spendwise.sync.device-binding-secret';
const syncE2EKeySecretKey = 'spendwise.sync.e2e-key';
const syncWriteProofSecretKey = 'spendwise.sync.write-proof';

bool isValidSyncDeviceSecret(String secret) {
  if (secret.isEmpty || secret.contains('=')) {
    return false;
  }
  final List<int> decoded;
  try {
    decoded = base64Url.decode(base64Url.normalize(secret));
  } on FormatException {
    return false;
  }
  if (decoded.length != 32) {
    return false;
  }
  return base64Url.encode(decoded).replaceAll('=', '') == secret;
}
