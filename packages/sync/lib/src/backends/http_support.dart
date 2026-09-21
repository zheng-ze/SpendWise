part of '../../sync.dart';

Map<String, Object?> _decodeJsonObject(String body) {
  if (body.trim().isEmpty) return const <String, Object?>{};
  final decoded = jsonDecode(body);
  if (decoded is! Map<Object?, Object?>) {
    throw const FormatException('Expected a JSON object response.');
  }
  return decoded
      .map<String, Object?>((key, value) => MapEntry(key.toString(), value));
}

SyncFailure<T> _failureFromHttp<T>(
  int statusCode,
  Map<String, Object?> body, {
  String? retryAfterHeader,
}) {
  final code = (body['failure_code'] ?? body['code'])?.toString();
  final message = body['message']?.toString();
  final retryAfter = _parseRetryAfter(retryAfterHeader);

  switch (code) {
    case 'credential_expired':
      return CredentialExpired<T>(message: message);
    case 'rate_limited':
      return RateLimited<T>(message: message, retryAfter: retryAfter);
    case 'device_retired':
      return DeviceRetired<T>(message: message);
    case 'reconciliation_required':
      return ReconciliationRequired<T>(message: message);
    case 'stale_or_invalid_proof':
      return StaleOrInvalidProof<T>(message: message);
    case 'snapshot_hash_mismatch':
      return SnapshotHashMismatch<T>(
        message: message,
        mismatchedCollection: _decodeMismatchedCollection(body),
      );
    case 'protocol_unsupported':
      return ProtocolUnsupported<T>(message: message);
    case 'invalid_request':
      return InvalidRequest<T>(message: message);
    case 'network_unavailable':
      return NetworkUnavailable<T>(message: message);
    case 'backend_unavailable':
      return BackendUnavailable<T>(message: message, retryAfter: retryAfter);
  }

  return switch (statusCode) {
    400 => InvalidRequest<T>(message: message),
    401 => CredentialExpired<T>(message: message),
    403 => DeviceRetired<T>(message: message),
    409 => ReconciliationRequired<T>(message: message),
    426 => ProtocolUnsupported<T>(message: message),
    429 => RateLimited<T>(message: message, retryAfter: retryAfter),
    503 => BackendUnavailable<T>(message: message, retryAfter: retryAfter),
    _ =>
      BackendUnavailable<T>(message: message ?? 'Unexpected HTTP $statusCode.'),
  };
}

Duration? _parseRetryAfter(String? value) {
  if (value == null) return null;
  final seconds = int.tryParse(value.trim());
  return seconds == null ? null : Duration(seconds: seconds);
}

SyncCollection? _decodeMismatchedCollection(Map<String, Object?> body) {
  final raw = body['mismatched_collection'];
  if (raw is! String) return null;
  try {
    return SyncCollection.fromWireName(raw);
  } on FormatException {
    return null;
  }
}

Map<String, String> _authorizationHeaders(DeviceCredential credential) =>
    <String, String>{
      'authorization': 'Bearer ${credential._bearerToken}',
      'content-type': 'application/json',
      'accept': 'application/json',
    };

DeviceCredential _requireDeviceCredential(SyncCredential credential) {
  if (credential is! DeviceCredential) {
    throw ArgumentError.value(
      credential,
      'credential',
      'This backend requires a DeviceCredential from its matching authenticator.',
    );
  }
  return credential;
}
