part of '../../sync.dart';

// MARK: - Engine Key Seam

typedef SyncE2EKeyAccessor = Future<Uint8List> Function();

// MARK: - Engine Errors

final class SyncPayloadIdentityError implements Exception {
  const SyncPayloadIdentityError(this.message);

  final String message;

  @override
  String toString() => 'SyncPayloadIdentityError: $message';
}

final class SyncUntrackedRowError implements Exception {
  const SyncUntrackedRowError(this.message);

  final String message;

  @override
  String toString() => 'SyncUntrackedRowError: $message';
}
