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
///
/// A failed write-through never blocks later writes, and it is never silent:
/// each failure is reported once to [onWriteError] (when one is registered)
/// and the next [flush] throws the first failure enqueued since the previous
/// flush threw or resolved, even when a later write in the same window
/// succeeded.
class DriftSyncStagingStore implements SyncStagingStore {
  DriftSyncStagingStore._(
    this._db,
    List<StagedConflict> seed, {
    this.onWriteError,
  }) : _conflicts = List.of(seed);

  /// Opens [db] and hydrates the in-memory cache from its durable staging
  /// rows, oldest first. Await this before handing the store to [SyncEngine].
  ///
  /// [onWriteError] observes each durable write-through failure once, with
  /// its stack trace. Register one wherever staged state must be durable:
  /// without it, a failure between the synchronous cache update and the
  /// background Drift write is visible only to the [flush] awaiting it.
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

  /// Observes one durable write-through failure, with its stack trace.
  final void Function(Object error, StackTrace stackTrace)? onWriteError;

  /// Write-through writes in flight. Chained so concurrent mutations persist
  /// in call order; a failed write never blocks later ones from persisting.
  Future<void> _writes = Future<void>.value();

  /// First write-through failure enqueued since the previous flush threw or
  /// resolved, with its stack trace. Later writes still attempt persistence
  /// after an earlier failure, but the next [flush] surfaces this failure so
  /// staged state that never reached Drift never reads as durable.
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

  /// Awaits every write-through write enqueued so far. Await this before
  /// closing the database (or the process) when staged state must be durable.
  /// Throws the first failure enqueued since the previous flush threw or
  /// resolved, even when a later write in the same window succeeded and is
  /// durably persisted. Each failure surfaces through exactly one flush (and
  /// once through [onWriteError]); a flush with no failure since the previous
  /// one resolves normally.
  Future<void> flush() async {
    final pending = _writes;
    // The failing link already recorded itself in [_flushError] before
    // rethrowing, so its outcome is deliberately not propagated here: the
    // window's first failure is reported once below instead.
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
    // Every link already routes its failure to [onWriteError] and the next
    // [flush]. Observe it here as well so the failure never also escapes to
    // the zone as an unhandled async error while no later write or flush has
    // attached to the link yet.
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
      // Keep the window's first failure: later writes still run (the chain
      // settles each prior link), but the next flush reports this one even
      // when those later writes succeed.
      _flushError ??= error;
      _flushStackTrace ??= stackTrace;
      onWriteError?.call(error, stackTrace);
      rethrow;
    }
  }

  /// Awaits [future] without propagating its outcome. A prior link's failure
  /// was already reported to [onWriteError] (and recorded for its window's
  /// flush) when it ran, so only the chain linkage is swallowed here and
  /// later writes still persist.
  static Future<void> _settle(Future<void> future) async {
    try {
      await future;
    } on Object catch (_) {
      // Deliberate: see [_runAfter]. The failure itself was already reported.
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
