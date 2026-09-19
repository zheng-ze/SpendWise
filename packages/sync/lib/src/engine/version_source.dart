part of '../../sync.dart';

/// A row's stored lifecycle and version vector as read from durable storage.
@immutable
final class RowVersion {
  const RowVersion({
    required this.versionVector,
    required this.lifecycle,
  });

  const RowVersion.empty()
      : versionVector = VersionVector.empty,
        lifecycle = SiblingLifecycle.live;

  final VersionVector versionVector;
  final SiblingLifecycle lifecycle;

  @override
  bool operator ==(Object other) =>
      other is RowVersion &&
      other.versionVector == versionVector &&
      other.lifecycle == lifecycle;

  @override
  int get hashCode => Object.hash(versionVector, lifecycle);
}

/// Read seam over durable current row versions.
///
/// The package provides an in-memory fake for its own tests; app/lib/sync
/// supplies the Drift-backed implementation.
abstract class SyncVersionSource {
  RowVersion? readRowVersion(SyncRowID rowID);

  /// Reloads the versions backing [readRowVersion].
  Future<void> refresh();
}

/// In-memory [SyncVersionSource] used as a test fake inside packages/sync.
class InMemorySyncVersionSource implements SyncVersionSource {
  InMemorySyncVersionSource([Map<SyncRowID, RowVersion> rows = const {}])
      : _rows = Map.of(rows);

  /// Copy-on-write view of the stored rows.
  final Map<SyncRowID, RowVersion> _rows;

  void upsert(SyncRowID rowID, RowVersion version) {
    _rows[rowID] = version;
  }

  @override
  RowVersion? readRowVersion(SyncRowID rowID) => _rows[rowID];

  /// No-op: the in-memory rows are written directly, so there is nothing
  /// async to reload.
  @override
  Future<void> refresh() async {}
}
