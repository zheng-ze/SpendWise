import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Selectable, Variable;
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/persistence/mappers.dart';
import 'package:sync/sync.dart';

/// Bulk, per-collection read seam over durable current row versions.
///
/// Distinct from `package:sync`'s own [SyncVersionSource], which looks up one
/// row at a time for the package engine's own reconciliation path. This is
/// the app-level primitive push-candidate selection and post-flush
/// verification read over: every persisted live row and tombstone in one
/// [SyncCollection], normalized to [SyncRowID].
abstract class CollectionVersionReader {
  Future<Map<SyncRowID, RowVersion>> readRowVersions(SyncCollection collection);
}

/// Drift-backed [CollectionVersionReader].
///
/// `moneySources` unions `Accounts`, `SubPockets`, and the money-sources
/// orphan tombstones; every other collection unions its own content table
/// with its orphan tombstones. Content wins when both hold the same key.
/// Every constituent read for a collection runs inside one transaction, so
/// the union is a single consistent snapshot.
final class DriftCollectionVersionReader implements CollectionVersionReader {
  DriftCollectionVersionReader(this._db);

  final LedgerDatabase _db;

  @override
  Future<Map<SyncRowID, RowVersion>> readRowVersions(
    SyncCollection collection,
  ) => _db.transaction(() async {
    switch (collection) {
      case SyncCollection.moneySources:
        return _moneySources();
      case SyncCollection.categories:
        return _withOrphans(
          SyncCollection.categories,
          _table(
            _db.select(_db.categories),
            SyncCollection.categories,
            (row) => row.id,
            (row) => row.versionData,
            (row) => row.lifecycle,
          ),
        );
      case SyncCollection.entries:
        return _withOrphans(
          SyncCollection.entries,
          _table(
            _db.select(_db.entries),
            SyncCollection.entries,
            (row) => row.id,
            (row) => row.versionData,
            (row) => row.lifecycle,
          ),
        );
      case SyncCollection.plans:
        return _withOrphans(
          SyncCollection.plans,
          _table(
            _db.select(_db.plans),
            SyncCollection.plans,
            (row) => row.id,
            (row) => row.versionData,
            (row) => row.lifecycle,
          ),
        );
      case SyncCollection.budgets:
        return _withOrphans(
          SyncCollection.budgets,
          _table(
            _db.select(_db.budgets),
            SyncCollection.budgets,
            (row) => row.id,
            (row) => row.versionData,
            (row) => row.lifecycle,
          ),
        );
    }
  });

  Future<Map<SyncRowID, RowVersion>> _moneySources() async {
    final accounts = await _table(
      _db.select(_db.accounts),
      SyncCollection.moneySources,
      (row) => row.id,
      (row) => row.versionData,
      (row) => row.lifecycle,
    );
    final pockets = await _table(
      _db.select(_db.subPockets),
      SyncCollection.moneySources,
      (row) => row.id,
      (row) => row.versionData,
      (row) => row.lifecycle,
    );
    final orphans = await _orphanRows(SyncCollection.moneySources);
    return {...orphans, ...accounts, ...pockets};
  }

  // Unions one collection's content rows with its orphan tombstones. Content
  // wins on key collision; every orphan is definitionally a tombstone.
  Future<Map<SyncRowID, RowVersion>> _withOrphans(
    SyncCollection collection,
    Future<Map<SyncRowID, RowVersion>> content,
  ) async {
    final contentRows = await content;
    final orphanRows = await _orphanRows(collection);
    return {...orphanRows, ...contentRows};
  }

  // Reads the orphan tombstones for one collection through the raw row,
  // never the generated accessor, so the read cannot depend on mapped-row
  // decoding.
  Future<Map<SyncRowID, RowVersion>> _orphanRows(
    SyncCollection collection,
  ) async {
    final found = await _db
        .customSelect(
          'SELECT row_id, version_data FROM sync_orphan_tombstones '
          'WHERE collection = ?',
          variables: [Variable<String>(collection.wireName)],
          readsFrom: {_db.syncOrphanTombstones},
        )
        .get();
    return {
      for (final row in found)
        SyncRowID.of(collection, row.read<String>('row_id')): RowVersion(
          versionVector: versionFromRow(row.read<Uint8List>('version_data')),
          lifecycle: SiblingLifecycle.tombstone,
        ),
    };
  }

  static Future<Map<SyncRowID, RowVersion>> _table<T>(
    Selectable<T> query,
    SyncCollection collection,
    String Function(T row) id,
    Uint8List Function(T row) versionData,
    int Function(T row) lifecycleCode,
  ) async {
    final rows = await query.get();
    return {
      for (final row in rows)
        SyncRowID.of(collection, id(row)): RowVersion(
          versionVector: versionFromRow(versionData(row)),
          lifecycle: _siblingLifecycleOf(lifecycleCode(row)),
        ),
    };
  }

  static SiblingLifecycle _siblingLifecycleOf(int code) =>
      LifecycleState.fromCode(code) == LifecycleState.tombstoned
      ? SiblingLifecycle.tombstone
      : SiblingLifecycle.live;
}

/// In-memory [CollectionVersionReader] test fake for coordinator-level tests
/// that must not touch a real database.
final class InMemoryCollectionVersionReader implements CollectionVersionReader {
  InMemoryCollectionVersionReader([Map<SyncRowID, RowVersion> rows = const {}])
    : _rows = Map.of(rows);

  final Map<SyncRowID, RowVersion> _rows;

  void upsert(SyncRowID rowID, RowVersion version) {
    _rows[rowID] = version;
  }

  @override
  Future<Map<SyncRowID, RowVersion>> readRowVersions(
    SyncCollection collection,
  ) async => {
    for (final entry in _rows.entries)
      if (entry.key.collection == collection) entry.key: entry.value,
  };
}
