part of '../../sync.dart';

/// Error thrown when a [StagedConflict] group fails construction validation:
/// fewer than two siblings, a sibling whose decoded change targets a
/// different collection or row than the group itself, or a pair of siblings
/// that is not mutually concurrent.
final class StagedConflictValidationError implements Exception {
  const StagedConflictValidationError(this.message);

  final String message;

  @override
  String toString() => 'StagedConflictValidationError: $message';
}

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
  ) {
    final normalizedRowID = normalizedID(rowID);
    final owned = List<DecodedSibling>.unmodifiable(siblings);
    if (owned.length < 2) {
      throw StagedConflictValidationError(
        'A conflict group needs at least two siblings; received '
        '${owned.length}.',
      );
    }
    for (final sibling in owned) {
      if (collectionFor(sibling.change) != collection) {
        throw StagedConflictValidationError(
          'Sibling ${sibling.siblingID} targets '
          '${collectionFor(sibling.change)}, not the group collection '
          '$collection.',
        );
      }
      if (normalizedID(sibling.change.targetID) != normalizedRowID) {
        throw StagedConflictValidationError(
          'Sibling ${sibling.siblingID} targets '
          '${normalizedID(sibling.change.targetID)}, not the group row '
          '$normalizedRowID.',
        );
      }
    }
    for (var i = 0; i < owned.length; i += 1) {
      for (var j = i + 1; j < owned.length; j += 1) {
        final first = owned[i];
        final second = owned[j];
        if (!first.versionVector.isConcurrent(second.versionVector)) {
          throw StagedConflictValidationError(
            'Siblings ${first.siblingID} and ${second.siblingID} are not '
            'mutually concurrent; a conflict group must contain only '
            'siblings with no causal ordering between them.',
          );
        }
      }
    }
    return StagedConflict._(collection, normalizedRowID, owned);
  }

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
///
/// [pendingConflictList] is the async durable read behind [pendingConflicts];
/// [flush] settles writes enqueued through the synchronous engine-path
/// overrides, so callers can await durability before acting on staged rows.
abstract class SyncStagingStore {
  void stage(StagedConflict conflict);

  List<StagedConflict> get pendingConflicts;

  void resolve(StagedConflict conflict);

  Future<List<StagedConflict>> pendingConflictList();

  Future<void> flush();
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

  /// Delegates to the synchronous [pendingConflicts] getter: the in-memory
  /// rows are written directly, so there is nothing async to reload.
  @override
  Future<List<StagedConflict>> pendingConflictList() async => pendingConflicts;

  /// No-op: there is nothing async to settle in the in-memory fake.
  @override
  Future<void> flush() async {}
}

bool _siblingsEqual(List<DecodedSibling> a, List<DecodedSibling> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
