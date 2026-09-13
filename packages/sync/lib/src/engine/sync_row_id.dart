part of '../../sync.dart';

/// Composite identity of a sync row: a [SyncCollection] and a normalized row
/// ID.
///
/// Identical UUIDs in different collections map to distinct [SyncRowID]s, so
/// they keep independent stamps, acknowledged vectors, and grouping outcomes.
@immutable
final class SyncRowID {
  SyncRowID._(this.collection, this.rowID);

  /// Builds a row ID, normalizing [rowID] to a lowercase UUID string.
  ///
  /// This is the only public construction path: the raw generative
  /// constructor is private so an unnormalized [rowID] can never enter a
  /// [SyncRowID] and break map-key equality and lookup.
  factory SyncRowID.of(SyncCollection collection, String rowID) =>
      SyncRowID._(collection, normalizedID(rowID));

  final SyncCollection collection;
  final String rowID;

  @override
  bool operator ==(Object other) =>
      other is SyncRowID &&
      other.collection == collection &&
      other.rowID == rowID;

  @override
  int get hashCode => Object.hash(collection, rowID);

  @override
  String toString() => 'SyncRowID($collection, $rowID)';
}
