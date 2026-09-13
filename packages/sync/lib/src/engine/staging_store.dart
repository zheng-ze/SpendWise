part of '../../sync.dart';

/// A group of mutually concurrent siblings for one collection and row that
/// cannot be resolved without user review.
@immutable
final class StagedConflict {
  StagedConflict._(
    this.collection,
    this.rowID,
    this.siblings,
  );

  factory StagedConflict(
    SyncCollection collection,
    String rowID,
    List<DecodedSibling> siblings,
  ) =>
      StagedConflict._(
        collection,
        normalizedID(rowID),
        List<DecodedSibling>.unmodifiable(siblings),
      );

  final SyncCollection collection;

  /// Normalized lowercase-UUID row ID for this conflict.
  final String rowID;

  /// The decrypted siblings that share this collection and row, ordered as
  /// decoded. Unmodifiable: in-place mutation of the caller's list cannot
  /// reach this conflict.
  final List<DecodedSibling> siblings;

  SyncRowID get row => SyncRowID.of(collection, rowID);

  @override
  bool operator ==(Object other) =>
      other is StagedConflict &&
      other.collection == collection &&
      other.rowID == rowID &&
      _siblingsEqual(other.siblings, siblings);

  @override
  int get hashCode => Object.hash(collection, rowID, _hashList(siblings));
}

/// Contract for durable staging of unresolved conflict groups.
///
/// [stage] replaces the prior group for the same collection and row;
/// [pendingConflicts] returns groups oldest first; [resolve] removes a group,
/// acting as an idempotent no-op when it is absent.
abstract class SyncStagingStore {
  void stage(StagedConflict conflict);

  List<StagedConflict> get pendingConflicts;

  void resolve(StagedConflict conflict);
}

/// In-memory [SyncStagingStore] used as a test fake inside packages/sync.
class InMemorySyncStagingStore implements SyncStagingStore {
  InMemorySyncStagingStore([List<StagedConflict> conflicts = const []])
      : _conflicts = List.of(conflicts);

  final List<StagedConflict> _conflicts;

  @override
  void stage(StagedConflict conflict) {
    _conflicts.removeWhere(
      (existing) =>
          existing.collection == conflict.collection &&
          existing.rowID == conflict.rowID,
    );
    _conflicts.add(conflict);
  }

  @override
  List<StagedConflict> get pendingConflicts => List.unmodifiable(_conflicts);

  @override
  void resolve(StagedConflict conflict) {
    _conflicts.removeWhere(
      (existing) =>
          existing.collection == conflict.collection &&
          existing.rowID == conflict.rowID,
    );
  }
}

bool _siblingsEqual(List<DecodedSibling> a, List<DecodedSibling> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
