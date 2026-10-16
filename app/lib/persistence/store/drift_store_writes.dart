part of 'drift_ledger_store.dart';

// MARK: - Write Model

class _Barrier {
  final Completer<void> reached = Completer<void>();
}

final class _StampedChange {
  const _StampedChange(this.change, [this.stamp]);

  final LedgerChange change;

  final VersionVector? stamp;
}

final class _CoalescedWrite {
  const _CoalescedWrite(this.change, this.stamp, this.carried);

  final LedgerChange change;

  final VersionVector? stamp;

  final VersionVector? carried;
}

// MARK: - Coalescing

List<_CoalescedWrite> _coalesce(List<_StampedChange> pending) {
  final lastIndex = <SyncRowID, int>{};
  final carried = <SyncRowID, VersionVector>{};
  for (var i = 0; i < pending.length; i++) {
    final change = pending[i].change;
    final row = SyncRowID.of(collectionFor(change), change.targetID);
    lastIndex[row] = i;
    final stamp = pending[i].stamp;
    if (stamp != null) {
      final soFar = carried[row];
      carried[row] = soFar == null ? stamp : _pointwiseMax(soFar, stamp);
    }
  }
  final kept = lastIndex.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return [
    for (final survivor in kept)
      _CoalescedWrite(
        pending[survivor.value].change,
        pending[survivor.value].stamp,
        carried[survivor.key],
      ),
  ];
}

VersionVector _pointwiseMax(VersionVector a, VersionVector b) {
  final counters = Map<String, int>.of(a.counters);
  for (final entry in b.counters.entries) {
    final current = counters[entry.key];
    if (current == null || entry.value > current) {
      counters[entry.key] = entry.value;
    }
  }
  return VersionVector(counters);
}

VersionVector _withFloor(VersionVector stored, VersionVector? floor) =>
    floor == null ? stored : _pointwiseMax(floor, stored);

// MARK: - Applying

extension _DriftStoreWrites on DriftLedgerStore {
  Future<void> _apply(_CoalescedWrite write) async {
    final change = write.change;
    switch (change) {
      case UpsertAccount(:final account):
        await _upsert(
          db.accounts,
          account.id,
          write,
          (v) => accountToRow(account, v),
        );
      case UpsertPocket(:final pocket):
        await _upsert(
          db.subPockets,
          pocket.id,
          write,
          (v) => pocketToRow(pocket, v),
        );
      case UpsertCategory(:final category):
        final stored = await _categoryRow(category.id);
        await _upsert(
          db.categories,
          category.id,
          write,
          (v) => categoryUpsertRow(category, v, stored: stored),
        );
      case UpsertEntry(:final entry):
        await _upsert(
          db.entries,
          entry.id,
          write,
          (v) => entryToRow(entry, v).toCompanion(false),
        );
      case UpsertPlan(:final plan):
        await _upsert(
          db.plans,
          plan.id,
          write,
          (v) => planToRow(
            plan,
            v,
          ).toCompanion(true).copyWith(templateNote: Value(plan.template.note)),
        );
      case UpsertBudget(:final budget):
        await _upsert(
          db.budgets,
          budget.id,
          write,
          (v) => budgetToRow(budget, v),
        );
      case DeleteMoneySource(:final id):
        if (!await _tombstone(db.accounts, id, write)) {
          if (!await _tombstone(db.subPockets, id, write)) {
            await _writeOrphanIfStamped(SyncCollection.moneySources, id, write);
          }
        }
      case DeleteCategory(:final id):
        if (!await _tombstone(db.categories, id, write)) {
          await _writeOrphanIfStamped(SyncCollection.categories, id, write);
        }
      case DeleteEntry(:final id):
        if (!await _tombstone(db.entries, id, write)) {
          await _writeOrphanIfStamped(SyncCollection.entries, id, write);
        }
      case DeletePlan(:final id):
        if (!await _tombstone(db.plans, id, write)) {
          await _writeOrphanIfStamped(SyncCollection.plans, id, write);
        }
      case DeleteBudget(:final id):
        if (!await _tombstone(db.budgets, id, write)) {
          await _writeOrphanIfStamped(SyncCollection.budgets, id, write);
        }
    }
  }

  Future<void> _writeSeedFlag() async {
    await db
        .into(db.storeMeta)
        .insertOnConflictUpdate(
          rows.StoreMetaRow(id: 0, deviceId: await _device, hasSeeded: true),
        );
  }

  Future<String> get _device => deviceID(db);

  Future<rows.Category?> _categoryRow(String id) => (db.select(
    db.categories,
  )..where((row) => row.id.equals(normalizedID(id)))).getSingleOrNull();

  Future<Uint8List?> _storedVersion(String table, String id) async {
    final row = await db
        .customSelect(
          'SELECT version_data FROM $table WHERE id = ?',
          variables: [Variable<String>(normalizedID(id))],
        )
        .getSingleOrNull();
    return row?.read<Uint8List>('version_data');
  }

  VersionVector _decodeVersion(Uint8List stored) {
    try {
      return versionFromRow(stored);
    } on VersionVectorDecodeError catch (error) {
      throw PermanentSaveError(error.message);
    }
  }

  Future<VersionVector> _bumpedVersion<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String id, [
    VersionVector? floor,
  ]) async {
    final stored = await _storedVersion(table.actualTableName, id);
    final version = stored == null
        ? VersionVector.empty
        : _decodeVersion(stored);
    return _withFloor(version, floor).bump(await _device);
  }

  Future<void> _upsert<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String id,
    _CoalescedWrite write,
    Insertable<D> Function(VersionVector version) toRow,
  ) async {
    final collection = collectionFor(write.change);
    final orphan = await _orphanVersion(collection, id);
    if (orphan == null) {
      final version =
          write.stamp ?? await _bumpedVersion(table, id, write.carried);
      await db.into(table).insertOnConflictUpdate(toRow(version));
      return;
    }
    await _clearOrphan(collection, id);
    final stamp = write.stamp;
    if (stamp != null) {
      final version = _pointwiseMax(orphan, stamp);
      await db.into(table).insertOnConflictUpdate(toRow(version));
      return;
    }
    final floor = _pointwiseMax(orphan, write.carried ?? VersionVector.empty);
    final version = await _bumpedVersion(table, id, floor);
    await db.into(table).insertOnConflictUpdate(toRow(version));
  }

  Future<bool> _tombstone<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String id,
    _CoalescedWrite write,
  ) async {
    final name = table.actualTableName;
    final stored = await _storedVersion(name, id);
    if (stored == null) return false;

    final version =
        write.stamp ??
        _withFloor(_decodeVersion(stored), write.carried).bump(await _device);
    await db.customUpdate(
      'UPDATE $name SET lifecycle = ?, version_data = ? WHERE id = ?',
      variables: [
        Variable<int>(LifecycleState.tombstoned.code),
        Variable<Uint8List>(Uint8List.fromList(version.encode())),
        Variable<String>(normalizedID(id)),
      ],
      updates: {table},
    );
    return true;
  }

  Future<VersionVector?> _orphanVersion(
    SyncCollection collection,
    String id,
  ) async {
    final row = await db
        .customSelect(
          'SELECT version_data FROM sync_orphan_tombstones '
          'WHERE collection = ? AND row_id = ?',
          variables: [
            Variable<String>(collection.wireName),
            Variable<String>(normalizedID(id)),
          ],
          readsFrom: {db.syncOrphanTombstones},
        )
        .getSingleOrNull();
    final stored = row?.read<Uint8List>('version_data');
    return stored == null ? null : _decodeVersion(stored);
  }

  Future<void> _writeOrphanIfStamped(
    SyncCollection collection,
    String id,
    _CoalescedWrite write,
  ) async {
    final stamp = write.stamp;
    if (stamp == null) return;
    await db
        .into(db.syncOrphanTombstones)
        .insertOnConflictUpdate(
          rows.OrphanTombstoneRow(
            collection: collection,
            rowId: normalizedID(id),
            versionData: stamp,
          ),
        );
  }

  Future<void> _clearOrphan(SyncCollection collection, String id) async {
    await db.customUpdate(
      'DELETE FROM sync_orphan_tombstones WHERE collection = ? AND row_id = ?',
      variables: [
        Variable<String>(collection.wireName),
        Variable<String>(normalizedID(id)),
      ],
      updates: {db.syncOrphanTombstones},
    );
  }
}
