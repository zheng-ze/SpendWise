part of '../../sync.dart';

// MARK: - Payload Decode Error

/// Error thrown when a decoded sync payload is malformed or uses a version
/// this codec cannot read.
///
/// Distinct from [SyncPayloadDecryptionError], which is reserved for AEAD
/// authentication failures. A decode failure means the bytes were authentic
/// but not a payload this codec understands.
final class PayloadDecodeError implements FormatException {
  const PayloadDecodeError(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'PayloadDecodeError: $message';
}
