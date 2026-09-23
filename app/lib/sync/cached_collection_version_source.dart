import 'package:sync/sync.dart';

import 'collection_version_reader.dart';

final class CachedCollectionVersionSource implements SyncVersionSource {
  CachedCollectionVersionSource(this._reader);

  final CollectionVersionReader _reader;
  Map<SyncRowID, RowVersion> _cache = const {};
  Future<void>? _inFlight;

  @override
  Future<void> refresh() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final next = _load();
    _inFlight = next;
    return next;
  }

  Future<void> _load() async {
    try {
      final next = <SyncRowID, RowVersion>{};
      for (final collection in SyncCollection.values) {
        final rows = await _reader.readRowVersions(collection);
        next.addAll(rows);
      }
      _cache = next;
    } finally {
      _inFlight = null;
    }
  }

  @override
  RowVersion? readRowVersion(SyncRowID rowID) => _cache[rowID];
}
