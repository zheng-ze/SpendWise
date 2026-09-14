import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:sync/sync.dart';

import 'package:spendwise/persistence/ledger_database.dart';

/// Holds unresolved conflict groups for one device.
/// Staged groups stay durable across restarts.
class DriftSyncStagingStore implements SyncStagingStore {
  DriftSyncStagingStore._(
    this._db,
    List<StagedConflict> seed, {
    this.onWriteError,
  }) : _conflicts = List.of(seed);

  /// Opens the store with staged groups oldest first. Await before use.
  /// Reports each durable write failure once through [onWriteError].
  static Future<DriftSyncStagingStore> open(
    LedgerDatabase db, {
    void Function(Object error, StackTrace stackTrace)? onWriteError,
  }) async {
    final rows = await (db.select(db.syncStagingGroup)).get();
    final ordered = List.of(rows)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return DriftSyncStagingStore._(db, [
      for (final row in ordered)
        _decodeGroup(_collection(row.collection), row.rowID, row.siblings),
    ], onWriteError: onWriteError);
  }

  final LedgerDatabase _db;
  final List<StagedConflict> _conflicts;

  /// Observes one durable write failure, with its stack trace.
  final void Function(Object error, StackTrace stackTrace)? onWriteError;

  // Chains writes so concurrent mutations persist in call order and
  // a failed write never blocks later ones.
  Future<void> _writes = Future<void>.value();

  // Keeps the first failure for the next flush. Later writes still run
  // after an earlier failure.
  Object? _flushError;
  StackTrace? _flushStackTrace;

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
  List<StagedConflict> get pendingConflicts => List.unmodifiable(_conflicts);

  @override
  void resolve(StagedConflict conflict) {
    _conflicts.removeWhere(
      (existing) =>
          existing.collection == conflict.collection &&
          existing.rowID == conflict.rowID,
    );
    _enqueue(() => _persistResolve(conflict));
  }

  /// Awaits staged writes queued so far. Throws the first failure since
  /// the previous flush, even when a later write succeeded.
  Future<void> flush() async {
    final pending = _writes;
    // Drops the settled outcome because the failure already recorded for
    // the next flush.
    await _settle(pending);
    final error = _flushError;
    final stackTrace = _flushStackTrace;
    _flushError = null;
    _flushStackTrace = null;
    if (error != null) {
      Error.throwWithStackTrace(error, stackTrace ?? StackTrace.empty);
    }
  }

  void _enqueue(Future<void> Function() work) {
    final prior = _writes;
    final next = _runAfter(prior, work);
    _writes = next;
    // Ignores the link outcome because failures already report through
    // the next flush.
    next.ignore();
  }

  Future<void> _runAfter(
    Future<void> prior,
    Future<void> Function() work,
  ) async {
    await _settle(prior);
    try {
      await work();
    } on Object catch (error, stackTrace) {
      // Keeps the first failure for the next flush. Later writes still run
      // even when an earlier write failed.
      _flushError ??= error;
      _flushStackTrace ??= stackTrace;
      onWriteError?.call(error, stackTrace);
      rethrow;
    }
  }

  // Swallows a prior failure already saved for the next flush, so
  // later writes still run.
  static Future<void> _settle(Future<void> future) async {
    try {
      await future;
    } on Object catch (_) {
      // Drops the outcome because the failure already reported.
    }
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
    // Rebuilds deletes from the group row. The sibling id names the source,
    // not the row, so using it would target a row that never existed.
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
