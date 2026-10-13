part of '../../sync.dart';

// MARK: - Engine Key Seam

/// Narrow scoped accessor the engine uses to obtain the raw E2E key.
///
/// The engine never receives the app's general SecretStore or the opaque
/// credential payload; this is its only key-related dependency.
typedef SyncE2EKeyAccessor = Future<Uint8List> Function();

// MARK: - Engine Errors

/// Error thrown when an authenticated envelope's decrypted payload does not
/// match the envelope's declared collection, row ID, or tombstone shape.
///
/// Distinct from [SyncPayloadDecryptionError] (AEAD authentication failure)
/// and [PayloadDecodeError] (authentic bytes this codec cannot read): an
/// identity mismatch means the bytes were authentic but the decoded entity
/// does not belong to this envelope.
final class SyncPayloadIdentityError implements Exception {
  const SyncPayloadIdentityError(this.message);

  final String message;

  @override
  String toString() => 'SyncPayloadIdentityError: $message';
}

/// Error thrown when [SyncEngine.encode] is asked to push a row the version
/// source does not track, so no stored [RowVersion] is available.
final class SyncUntrackedRowError implements Exception {
  const SyncUntrackedRowError(this.message);

  final String message;

  @override
  String toString() => 'SyncUntrackedRowError: $message';
}
