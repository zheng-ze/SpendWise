import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:sync/sync.dart';

/// Explicit sibling-lifecycle codes stored in `sync_staged_siblings`.
///
/// Never persist an enum index; these codes stay stable across refactors.
const int _stagedLifecycleLive = 0;
const int _stagedLifecycleTombstone = 1;

/// Drift-backed [SyncStagingStore] keeping decrypted staged siblings locally,
/// consistent with the existing plaintext `LedgerState` storage.
///
/// The package contract is synchronous while Drift is not. The async core
/// methods ([stageConflict], [pendingConflictList], [resolveConflict]) are the
/// durable operations: each commits in one atomic Drift transaction. The
/// synchronous [SyncStagingStore] overrides exist so the package engine can
/// hold this store; they enqueue the same durable work, and [flush] settles
/// engine-enqueued writes. Await [flush] (or the async core method directly)
/// before relying on durability, for example before advancing a page
/// watermark over staged rows.
///
/// [pendingConflicts] reflects the last settled state; [open] and
/// [pendingConflictList] reload it from the database.
final class DriftSyncStagingStore implements SyncStagingStore {
  DriftSyncStagingStore(this._db);

  /// Loads persisted groups so the store survives a force-quit.
  static Future<DriftSyncStagingStore> open(LedgerDatabase db) async {
    final store = DriftSyncStagingStore(db);
    await store._reload();
    return store;
  }

  final LedgerDatabase _db;
  final List<StagedConflict> _mirror = [];
  final List<Future<void>> _pending = [];

  /// Stages [conflict], replacing the prior group for the same collection and
  /// row, and moves the group to the newest position.
  Future<void> stageConflict(StagedConflict conflict) async {
    final collection = conflict.collection;
    final rowID = conflict.rowID;
    const codec = PayloadCodec();
    await _db.transaction(() async {
      await _deleteGroup(collection, rowID);
      await _db
          .into(_db.syncStagedConflicts)
          .insert(
            SyncStagedConflictsCompanion.insert(
              collection: collection,
              rowId: rowID,
            ),
          );
      for (var index = 0; index < conflict.siblings.length; index += 1) {
        final sibling = conflict.siblings[index];
        await _db
            .into(_db.syncStagedSiblings)
            .insert(
              SyncStagedSiblingsCompanion.insert(
                collection: collection,
                rowId: rowID,
                siblingId: sibling.siblingID,
                versionData: sibling.versionVector,
                payload: Uint8List.fromList(codec.encodeChange(sibling.change)),
                lifecycle: _lifecycleOf(sibling.change),
                position: index,
              ),
            );
      }
    });
    _mirror.removeWhere(
      (existing) =>
          existing.collection == conflict.collection &&
          existing.rowID == conflict.rowID,
    );
    _mirror.add(conflict);
  }

  /// Reads every staged group oldest first, refreshing the settled view.
  Future<List<StagedConflict>> pendingConflictList() async {
    await _reload();
    return List.unmodifiable(_mirror);
  }

  /// Resolves the group for the same collection and row, acting as an
  /// idempotent no-op when it is absent.
  Future<void> resolveConflict(StagedConflict conflict) async {
    final collection = conflict.collection;
    final rowID = conflict.rowID;
    await _db.transaction(() => _deleteGroup(collection, rowID));
    _mirror.removeWhere(
      (existing) =>
          existing.collection == conflict.collection &&
          existing.rowID == conflict.rowID,
    );
  }

  /// Deletes the staged siblings and conflict row for [collection]/[rowID].
  /// Callers must run this inside their own transaction.
  Future<void> _deleteGroup(SyncCollection collection, String rowID) async {
    await (_db.delete(_db.syncStagedSiblings)..where(
          (t) => t.collection.equalsValue(collection) & t.rowId.equals(rowID),
        ))
        .go();
    await (_db.delete(_db.syncStagedConflicts)..where(
          (t) => t.collection.equalsValue(collection) & t.rowId.equals(rowID),
        ))
        .go();
  }

  /// Settles writes enqueued through the synchronous engine-path overrides.
  /// Rethrows the first failure, if any.
  Future<void> flush() async {
    if (_pending.isEmpty) return;
    final pending = List<Future<void>>.of(_pending);
    _pending.clear();
    await Future.wait(pending);
  }

  @override
  void stage(StagedConflict conflict) {
    _pending.add(stageConflict(conflict));
  }

  @override
  List<StagedConflict> get pendingConflicts => List.unmodifiable(_mirror);

  @override
  void resolve(StagedConflict conflict) {
    _pending.add(resolveConflict(conflict));
  }

  Future<void> _reload() async {
    final groupRows = await _db
        .customSelect(
          'SELECT collection, row_id FROM sync_staged_conflicts '
          'ORDER BY rowid',
        )
        .get();
    const codec = PayloadCodec();
    final reloaded = <StagedConflict>[];
    for (final group in groupRows) {
      final collection = SyncCollection.fromWireName(
        group.read<String>('collection'),
      );
      final rowID = group.read<String>('row_id');
      final siblingRows =
          await (_db.select(_db.syncStagedSiblings)
                ..where(
                  (t) =>
                      t.collection.equalsValue(collection) &
                      t.rowId.equals(rowID),
                )
                ..orderBy([
                  (t) => OrderingTerm.asc(t.position),
                  (t) => OrderingTerm.asc(t.siblingId),
                ]))
              .get();
      reloaded.add(
        StagedConflict(collection, rowID, [
          for (final row in siblingRows) _decodeSibling(codec, row),
        ]),
      );
    }
    _mirror
      ..clear()
      ..addAll(reloaded);
  }

  static DecodedSibling _decodeSibling(
    PayloadCodec codec,
    StagedSiblingRow row,
  ) {
    final collection = row.collection;
    final vector = row.versionData;
    final LedgerChange change;
    if (row.lifecycle == _stagedLifecycleTombstone) {
      change = deleteFor(collection, row.rowId);
    } else if (row.lifecycle == _stagedLifecycleLive) {
      change = codec.decodeChange(row.payload.toList());
    } else {
      throw FormatException(
        'Unknown staged sibling lifecycle: ${row.lifecycle}.',
      );
    }
    return DecodedSibling(vector, change, row.siblingId);
  }

  static int _lifecycleOf(LedgerChange change) => switch (change) {
    DeleteBudget() ||
    DeleteCategory() ||
    DeleteEntry() ||
    DeletePlan() ||
    DeleteMoneySource() => _stagedLifecycleTombstone,
    UpsertAccount() ||
    UpsertPocket() ||
    UpsertCategory() ||
    UpsertEntry() ||
    UpsertPlan() ||
    UpsertBudget() => _stagedLifecycleLive,
  };
}
