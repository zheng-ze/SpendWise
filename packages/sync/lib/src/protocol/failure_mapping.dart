part of '../../sync.dart';

/// Client-side failure mapping shared by every sync adapter.
///
/// An explicit 426 (or `protocol_unsupported` code) stays
/// [ProtocolUnsupported]: the server refused the operation major.
/// [IncompatibleServer] is terminal and client-detected instead, covering a
/// named `incompatible_server` code and responses the client cannot parse as
/// v2 at all; it is never routed from an HTTP status.
SyncFailure<T> syncFailureFromHttp<T>(
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
    case 'device_authorization_required':
      return DeviceAuthorizationRequired<T>(message: message);
    case 'incompatible_server':
      return IncompatibleServer<T>(message: message);
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
    428 => DeviceAuthorizationRequired<T>(message: message),
    429 => RateLimited<T>(message: message, retryAfter: retryAfter),
    503 => BackendUnavailable<T>(message: message, retryAfter: retryAfter),
    _ =>
      BackendUnavailable<T>(message: message ?? 'Unexpected HTTP $statusCode.'),
  };
}
