part of '../../sync.dart';

sealed class SyncOutcome<T> {
  const SyncOutcome();

  bool get isSuccess => this is SyncSuccess<T>;
}

final class SyncSuccess<T> extends SyncOutcome<T> {
  const SyncSuccess(this.value);

  final T value;
}

sealed class SyncFailure<T> extends SyncOutcome<T> {
  const SyncFailure({this.message, this.retryAfter});

  final String? message;
  final Duration? retryAfter;
  String get code;
}

final class CredentialExpired<T> extends SyncFailure<T> {
  const CredentialExpired({super.message});
  @override
  String get code => 'credential_expired';
}

final class RateLimited<T> extends SyncFailure<T> {
  const RateLimited({super.message, super.retryAfter});
  @override
  String get code => 'rate_limited';
}

final class DeviceRetired<T> extends SyncFailure<T> {
  const DeviceRetired({super.message});
  @override
  String get code => 'device_retired';
}

final class ReconciliationRequired<T> extends SyncFailure<T> {
  const ReconciliationRequired({super.message});
  @override
  String get code => 'reconciliation_required';
}

final class StaleOrInvalidProof<T> extends SyncFailure<T> {
  const StaleOrInvalidProof({super.message});
  @override
  String get code => 'stale_or_invalid_proof';
}

final class SnapshotHashMismatch<T> extends SyncFailure<T> {
  const SnapshotHashMismatch({super.message});
  @override
  String get code => 'snapshot_hash_mismatch';
}

final class ProtocolUnsupported<T> extends SyncFailure<T> {
  const ProtocolUnsupported({super.message});
  @override
  String get code => 'protocol_unsupported';
}

final class InvalidRequest<T> extends SyncFailure<T> {
  const InvalidRequest({super.message});
  @override
  String get code => 'invalid_request';
}

final class NetworkUnavailable<T> extends SyncFailure<T> {
  const NetworkUnavailable({super.message});
  @override
  String get code => 'network_unavailable';
}

final class BackendUnavailable<T> extends SyncFailure<T> {
  const BackendUnavailable({super.message, super.retryAfter});
  @override
  String get code => 'backend_unavailable';
}
