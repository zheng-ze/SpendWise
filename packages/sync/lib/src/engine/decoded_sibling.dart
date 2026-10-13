part of '../../sync.dart';

// MARK: - Decoded Sibling

/// A decoded, decrypted sibling carried into a [StagedConflict]: its version
/// vector, the [LedgerChange] decoded from its ciphertext, and the stable
/// [siblingID] taken from the original envelope.
///
/// [StagedConflict] carries these decoded values rather than raw envelopes so
/// a later durable store can persist already-decrypted content without a
/// second decryption pass. [siblingID] is preserved so a later conflict-review
/// store can audit, deduplicate, and identify a sibling's source across slices.
@immutable
final class DecodedSibling {
  const DecodedSibling(this.versionVector, this.change, this.siblingID);

  final VersionVector versionVector;
  final LedgerChange change;

  /// Stable per-sibling identity from the original envelope.
  final String siblingID;

  @override
  bool operator ==(Object other) =>
      other is DecodedSibling &&
      other.versionVector == versionVector &&
      other.change == change &&
      other.siblingID == siblingID;

  @override
  int get hashCode => Object.hash(versionVector, change, siblingID);

  @override
  String toString() =>
      'DecodedSibling($change under $versionVector, sibling $siblingID)';
}

// MARK: - Row Conversion

DecodedSibling _toDecodedSibling(_DecodedRow row) => DecodedSibling(
      row.envelope.versionVector,
      row.change,
      row.envelope.siblingID,
    );
