import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:domain/domain.dart';
import 'package:sync/sync.dart';

import 'package:spendwise/persistence/ledger_database.dart';

/// Drift-backed durable staging of unresolved conflict groups.
///
/// Behaviorally matches the package's [SyncStagingStore] contract: [stage]
/// replaces the prior group for the same collection and row, [pendingConflicts]
/// returns groups oldest first, and [resolve] removes a group, acting as an
/// idempotent no-op when it is absent. Decrypted staged siblings are stored in
/// plaintext, consistent with the existing plaintext LedgerState storage
/// policy, and survive restart and force-quit because they live in the same
/// database file.
///
/// The package's [SyncStagingStore] contract is synchronous and is implemented
/// in-memory by the package engine; Drift reads and writes are asynchronous, so
/// this concrete class exposes the same operations as async members.
class DriftSyncStagingStore {
  DriftSyncStagingStore(this._db);

  final LedgerDatabase _db;

  Future<void> stage(StagedConflict conflict) async {
    final siblings = _encodeSiblings(conflict.siblings);
    await _db.transaction(() async {
      await (_db.delete(_db.syncStagingGroup)
          ..where((t) => t.collection.equals(conflict.collection.wireName) &
                t.rowID.equals(conflict.rowID))
        ).go();
      await _db.into(_db.syncStagingGroup).insert(
        SyncStagingGroupCompanion.insert(
          collection: conflict.collection.wireName,
          rowID: conflict.rowID,
          siblings: siblings,
        ),
      );
    });
  }

  Future<List<StagedConflict>> get pendingConflicts async {
    // The staging table holds only unresolved conflicts, so fetch and sort by
    // the auto-increment sequence in Dart. The ascending sequence orders the
    // oldest stage first, matching the abstract store's oldest-first contract.
    final rows = await (_db.select(_db.syncStagingGroup)).get();
    final ordered = List<SyncStagingGroupData>.from(rows)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return [
      for (final row in ordered)
        _stagedConflict(_collection(row.collection), row.rowID, row.siblings),
    ];
  }

  Future<void> resolve(StagedConflict conflict) async {
    await (_db.delete(_db.syncStagingGroup)
          ..where((t) => t.collection.equals(conflict.collection.wireName) &
                t.rowID.equals(conflict.rowID))
        ).go();
  }

  StagedConflict _stagedConflict(
    SyncCollection collection,
    String rowID,
    Uint8List siblings,
  ) =>
      StagedConflict(collection, rowID, _decodeSiblings(collection, siblings));

  Uint8List _encodeSiblings(List<DecodedSibling> siblings) {
    final entries = <Object?>[
      for (final sibling in siblings)
        {
          'siblingID': sibling.siblingID,
          'versionVector':
              base64Url.encode(sibling.versionVector.encode()),
          'change': base64Url.encode(
            const PayloadCodec().encodeChange(sibling.change),
          ),
        }
    ];
    return utf8.encode(jsonEncode(entries));
  }

  List<DecodedSibling> _decodeSiblings(
    SyncCollection collection,
    Uint8List blob,
  ) {
    final entries = jsonDecode(utf8.decode(blob)) as List<dynamic>;
    return [
      for (final raw in entries)
        _decodeSibling(collection, raw as Map<String, dynamic>),
    ];
  }

  DecodedSibling _decodeSibling(
    SyncCollection collection,
    Map<String, dynamic> entry,
  ) {
    final siblingID = entry['siblingID'] as String;
    final versionVector = VersionVector.decode(
      base64Url.decode(entry['versionVector'] as String),
    );
    final payload = base64Url.decode(entry['change'] as String);
    final change = payload.isEmpty
        ? _deleteFor(collection, siblingID)
        : const PayloadCodec().decodeChange(payload);
    return DecodedSibling(versionVector, change, siblingID);
  }

  LedgerChange _deleteFor(SyncCollection collection, String rowID) {
    switch (collection) {
      case SyncCollection.moneySources:
        return DeleteMoneySource(rowID);
      case SyncCollection.entries:
        return DeleteEntry(rowID);
      case SyncCollection.categories:
        return DeleteCategory(rowID);
      case SyncCollection.plans:
        return DeletePlan(rowID);
      case SyncCollection.budgets:
        return DeleteBudget(rowID);
    }
  }

  SyncCollection _collection(String wireName) => SyncCollection.values.firstWhere(
    (collection) => collection.wireName == wireName,
    orElse: () => throw FormatException('Unknown sync collection: $wireName'),
  );
}
