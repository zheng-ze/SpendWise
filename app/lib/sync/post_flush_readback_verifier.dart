import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:spendwise/sync/row_readback_outcome.dart';
import 'package:sync/sync.dart';

/// Verifies a stamped flush by reading every submitted row back from real
/// storage.
///
/// This classifies each row's readback outcome. It does not itself commit any
/// metadata state; the coordinator decides what to do with a passed or failed
/// classification.
final class PostFlushReadbackVerifier {
  const PostFlushReadbackVerifier(this._reader);

  final CollectionVersionReader _reader;

  /// Reads back every [stamped] row, grouped by collection so each
  /// collection is read from storage once, and classifies its outcome.
  Future<Map<SyncRowID, RowReadbackOutcome>> verify(
    Map<SyncRowID, VersionVector> stamped,
  ) async {
    final byCollection = <SyncCollection, Map<SyncRowID, VersionVector>>{};
    for (final entry in stamped.entries) {
      byCollection.putIfAbsent(entry.key.collection, () => {})[entry.key] =
          entry.value;
    }

    final outcomes = <SyncRowID, RowReadbackOutcome>{};
    for (final group in byCollection.entries) {
      final stored = await _reader.readRowVersions(group.key);
      for (final rowEntry in group.value.entries) {
        outcomes[rowEntry.key] = _classify(
          stored[rowEntry.key],
          rowEntry.value,
        );
      }
    }
    return outcomes;
  }

  static RowReadbackOutcome _classify(
    RowVersion? stored,
    VersionVector submitted,
  ) {
    if (stored == null) return const RowReadbackMissing();
    final storedVector = stored.versionVector;
    if (storedVector == submitted) return const RowReadbackEqual();
    if (storedVector.dominates(submitted)) {
      return RowReadbackDominated(storedVector);
    }
    return RowReadbackIncompatible(storedVector);
  }
}
