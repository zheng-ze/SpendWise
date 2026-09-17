import 'package:sync/sync.dart';

import 'collection_version_reader.dart';

/// Bridges async bulk [CollectionVersionReader] reads into the synchronous
/// per-row [SyncVersionSource] interface.
///
/// [refresh] rereads every [SyncCollection] and atomically swaps the
/// published cache only after every read succeeds; a failure leaves the
/// previous cache unchanged and rethrows. Overlapping [refresh] calls share
/// one in-flight read. Population is driven by the run slice, so the cache
/// starts empty and [readRowVersion] returns null until the first [refresh].
final class CachedCollectionVersionSource implements SyncVersionSource {
  CachedCollectionVersionSource(this._reader);

  final CollectionVersionReader _reader;
  Map<SyncRowID, RowVersion> _cache = const {};
  Future<void>? _inFlight;

  /// Reloads every collection and publishes the result atomically.
  ///
  /// Single-flight: a call arriving while one is in-flight joins the same
  /// future instead of starting a second read.
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
