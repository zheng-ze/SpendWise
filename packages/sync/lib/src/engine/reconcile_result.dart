part of '../../sync.dart';

// MARK: - Reconcile Result

@immutable
final class ReconcileResult {
  ReconcileResult._(
    this.changes,
    this.stamps,
    this.stagedConflicts,
    this.winningInputIndex,
  );

  factory ReconcileResult({
    required List<LedgerChange> changes,
    required Map<SyncRowID, VersionVector> stamps,
    required List<StagedConflict> stagedConflicts,
    required Map<SyncRowID, int> winningInputIndex,
  }) =>
      ReconcileResult._(
        List.unmodifiable(changes),
        Map.unmodifiable(stamps),
        List.unmodifiable(stagedConflicts),
        Map.unmodifiable(winningInputIndex),
      );

  final List<LedgerChange> changes;
  final Map<SyncRowID, VersionVector> stamps;
  final List<StagedConflict> stagedConflicts;

  final Map<SyncRowID, int> winningInputIndex;

  bool get hasConflicts => stagedConflicts.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is ReconcileResult &&
      _listEquals(other.changes, changes) &&
      _mapEquals(other.stamps, stamps) &&
      _listEquals(other.stagedConflicts, stagedConflicts) &&
      _mapEquals(other.winningInputIndex, winningInputIndex);

  @override
  int get hashCode => Object.hash(
        _hashList(changes),
        _hashMap(stamps),
        _hashList(stagedConflicts),
        _hashMap(winningInputIndex),
      );
}

// MARK: - Content Equality

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

int _hashList<T>(List<T> values) =>
    Object.hashAll(values.map((value) => value.hashCode));

int _hashMap<K, V>(Map<K, V> map) {
  var hash = 0;
  for (final entry in map.entries) {
    hash ^= Object.hash(entry.key, entry.value);
  }
  return hash;
}
