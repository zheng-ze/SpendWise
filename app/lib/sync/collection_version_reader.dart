import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Selectable;
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

/// Drift-backed [CollectionVersionReader], sibling to the other app/lib/sync
/// stores reading over [LedgerDatabase].
///
/// `moneySources` unions `Accounts` and `SubPockets`; every other collection
/// reads its own content table directly. This reader covers exactly the six
/// existing content tables; no orphan-tombstone table exists yet.
final class DriftCollectionVersionReader implements CollectionVersionReader {
  DriftCollectionVersionReader(this._db);

  final LedgerDatabase _db;

  @override
  Future<Map<SyncRowID, RowVersion>> readRowVersions(
    SyncCollection collection,
  ) => switch (collection) {
    SyncCollection.moneySources => _moneySources(),
    SyncCollection.categories => _table(
      _db.select(_db.categories),
      SyncCollection.categories,
      (row) => row.id,
      (row) => row.versionData,
      (row) => row.lifecycle,
    ),
    SyncCollection.entries => _table(
      _db.select(_db.entries),
      SyncCollection.entries,
      (row) => row.id,
      (row) => row.versionData,
      (row) => row.lifecycle,
    ),
    SyncCollection.plans => _table(
      _db.select(_db.plans),
      SyncCollection.plans,
      (row) => row.id,
      (row) => row.versionData,
      (row) => row.lifecycle,
    ),
    SyncCollection.budgets => _table(
      _db.select(_db.budgets),
      SyncCollection.budgets,
      (row) => row.id,
      (row) => row.versionData,
      (row) => row.lifecycle,
    ),
  };

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
    return {...accounts, ...pockets};
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
