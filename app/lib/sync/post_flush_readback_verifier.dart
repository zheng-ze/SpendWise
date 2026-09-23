import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:spendwise/sync/row_readback_outcome.dart';
import 'package:sync/sync.dart';

final class PostFlushReadbackVerifier {
  const PostFlushReadbackVerifier(this._reader);

  final CollectionVersionReader _reader;

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
