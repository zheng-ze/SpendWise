part of '../../sync.dart';

// MARK: - Decoded Sibling

@immutable
final class DecodedSibling {
  const DecodedSibling(this.versionVector, this.change, this.siblingID);

  final VersionVector versionVector;
  final LedgerChange change;

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
