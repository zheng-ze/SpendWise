import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:sync/sync.dart';

import 'package:spendwise/persistence/ledger_database.dart';

/// Drift-backed durable staging of unresolved conflict groups.
///
/// Implements the package's synchronous [SyncStagingStore] contract on top of
/// an in-memory cache, so the object passed to [SyncEngine] satisfies the seam
/// directly: [stage] replaces the prior group for the same collection and row,
/// [pendingConflicts] returns groups oldest first, and [resolve] removes a
/// group, acting as an idempotent no-op when it is absent.
///
/// Durability comes from Drift write-through: every mutation updates the cache
/// synchronously and enqueues the matching Drift write, which [flush] awaits.
/// [open] hydrates the cache from Drift, so staged groups survive restart and
/// force-quit because they live in the same database file. Decrypted staged
/// siblings are stored in plaintext, consistent with the existing plaintext
/// LedgerState storage policy.
class DriftSyncStagingStore implements SyncStagingStore {
  DriftSyncStagingStore._(this._db, List<StagedConflict> seed)
    : _conflicts = List.of(seed);

  /// Opens [db] and hydrates the in-memory cache from its durable staging
  /// rows, oldest first. Await this before handing the store to [SyncEngine].
  static Future<DriftSyncStagingStore> open(LedgerDatabase db) async {
    final rows = await (db.select(db.syncStagingGroup)).get();
    final ordered = List.of(rows)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return DriftSyncStagingStore._(db, [
      for (final row in ordered)
        _decodeGroup(_collection(row.collection), row.rowID, row.siblings),
    ]);
  }

  final LedgerDatabase _db;
  final List<StagedConflict> _conflicts;

  /// Write-through writes in flight. Chained so concurrent mutations persist
  /// in call order; a failed write never blocks later ones from persisting.
  Future<void> _writes = Future<void>.value();

  @override
  void stage(StagedConflict conflict) {
    _conflicts.removeWhere(
      (existing) =>
          existing.collection == conflict.collection &&
          existing.rowID == conflict.rowID,
    );
    _conflicts.add(conflict);
    _enqueue(() => _persistStage(conflict));
  }

  @override
  List<StagedConflict> get pendingConflicts =>
      List.unmodifiable(_conflicts);

  @override
  void resolve(StagedConflict conflict) {
    _conflicts.removeWhere(
      (existing) =>
          existing.collection == conflict.collection &&
          existing.rowID == conflict.rowID,
    );
    _enqueue(() => _persistResolve(conflict));
  }

  /// Awaits every write-through write enqueued so far. Await this before
  /// closing the database (or the process) when staged state must be durable.
  Future<void> flush() => _writes;

  void _enqueue(Future<void> Function() work) {
    _writes = _writes.then((_) => work(), onError: (_) => work());
  }

  Future<void> _persistStage(StagedConflict conflict) async {
    final siblings = _encodeSiblings(conflict.siblings);
    await _db.transaction(() async {
      await (_db.delete(_db.syncStagingGroup)..where(
            (t) =>
                t.collection.equals(conflict.collection.wireName) &
                t.rowID.equals(conflict.rowID),
          ))
          .go();
      await _db
          .into(_db.syncStagingGroup)
          .insert(
            SyncStagingGroupCompanion.insert(
              collection: conflict.collection.wireName,
              rowID: conflict.rowID,
              siblings: siblings,
            ),
          );
    });
  }

  Future<void> _persistResolve(StagedConflict conflict) async {
    await (_db.delete(_db.syncStagingGroup)..where(
          (t) =>
              t.collection.equals(conflict.collection.wireName) &
              t.rowID.equals(conflict.rowID),
        ))
        .go();
  }

  Uint8List _encodeSiblings(List<DecodedSibling> siblings) {
    final entries = <Object?>[
      for (final sibling in siblings)
        {
          'siblingID': sibling.siblingID,
          'versionVector': base64Url.encode(sibling.versionVector.encode()),
          'change': base64Url.encode(
            const PayloadCodec().encodeChange(sibling.change),
          ),
        },
    ];
    return utf8.encode(jsonEncode(entries));
  }

  static StagedConflict _decodeGroup(
    SyncCollection collection,
    String rowID,
    Uint8List blob,
  ) => StagedConflict(
    collection,
    rowID,
    _decodeSiblings(collection, rowID, blob),
  );

  static List<DecodedSibling> _decodeSiblings(
    SyncCollection collection,
    String rowID,
    Uint8List blob,
  ) {
    final entries = jsonDecode(utf8.decode(blob)) as List<dynamic>;
    return [
      for (final raw in entries)
        _decodeSibling(collection, rowID, raw as Map<String, dynamic>),
    ];
  }

  static DecodedSibling _decodeSibling(
    SyncCollection collection,
    String rowID,
    Map<String, dynamic> entry,
  ) {
    final siblingID = entry['siblingID'] as String;
    final versionVector = VersionVector.decode(
      base64Url.decode(entry['versionVector'] as String),
    );
    final payload = base64Url.decode(entry['change'] as String);
    // Deletes encode as empty payloads. Rebuild the delete for the group row,
    // not the sibling id: the sibling id identifies the source envelope, so
    // using it here would fabricate a delete for a row that never existed.
    final change = payload.isEmpty
        ? deleteFor(collection, rowID)
        : const PayloadCodec().decodeChange(payload);
    return DecodedSibling(versionVector, change, siblingID);
  }

  static SyncCollection _collection(String wireName) =>
      SyncCollection.values.firstWhere(
        (collection) => collection.wireName == wireName,
        orElse: () =>
            throw FormatException('Unknown sync collection: $wireName'),
      );
}
