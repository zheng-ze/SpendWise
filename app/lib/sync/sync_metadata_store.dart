import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:sync/sync.dart';

import 'package:spendwise/persistence/ledger_database.dart';

/// Holds durable enrollment milestones. Stores each phase as its code,
/// never its index. Stays null before enrollment starts.
enum EnrollmentPhase {
  credentialAcquired('credentialAcquired', 0),
  snapshotKeyWorkInProgress('snapshotKeyWorkInProgress', 1),
  reconciliationComplete('reconciliationComplete', 2),
  gateEnabled('gateEnabled', 3);

  const EnrollmentPhase(this.wireName, this.code);

  final String wireName;
  final int code;

  static EnrollmentPhase fromCode(int value) => values.firstWhere(
    (phase) => phase.code == value,
    orElse: () => throw ArgumentError.value(
      value,
      'code',
      'Unknown enrollment phase code.',
    ),
  );
}

/// Signals an early write-gate enable before reconciliation completes.
/// Disabling the gate never throws.
final class WriteGateNotReadyError implements Exception {
  const WriteGateNotReadyError(this.message);

  final String message;

  @override
  String toString() => 'WriteGateNotReadyError: $message';
}

/// One owed pull-page acknowledgement, keyed by collection and checkpoint.
/// Survives failures and restarts until the backend confirms success.
@immutable
final class PendingCheckpoint {
  const PendingCheckpoint(this.collection, this.checkpoint);

  final SyncCollection collection;
  final String checkpoint;

  @override
  bool operator ==(Object other) =>
      other is PendingCheckpoint &&
      other.collection == collection &&
      other.checkpoint == checkpoint;

  @override
  int get hashCode => Object.hash(collection, checkpoint);

  @override
  String toString() => 'PendingCheckpoint($collection, $checkpoint)';
}

/// Holds sync metadata for one device.
/// Multi-value updates commit atomically.
class SyncMetadataStore {
  SyncMetadataStore(this._db);

  final LedgerDatabase _db;

  static const _metaRowId = 0;

  // Keeps fresh or migrated stores on pre-enrollment defaults.
  Future<SyncMetadataRow> _ensureScalar() async {
    final row =
        await (_db.select(
          _db.syncMetadata,
        )..where((t) => t.id.equals(_metaRowId))).getSingleOrNull() ??
        SyncMetadataRow(
          id: _metaRowId,
          backendSelection: null,
          enrollmentPhase: null,
          writeGate: false,
        );
    return row;
  }

  Future<String?> getBackendSelection() async {
    final row = await _ensureScalar();
    return row.backendSelection;
  }

  Future<void> setBackendSelection(String? profileID) async {
    // Clears to NULL with an explicit present null. A plain upsert omits
    // the null column and keeps the old value.
    await _db.transaction(() async {
      final existing = await _ensureScalar();
      await _db
          .into(_db.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion(
              id: const Value(_metaRowId),
              backendSelection: Value(profileID),
              enrollmentPhase: Value(existing.enrollmentPhase),
              writeGate: Value(existing.writeGate),
            ),
          );
    });
  }

  Future<EnrollmentPhase?> getPhase() async {
    final row = await _ensureScalar();
    final code = row.enrollmentPhase;
    return code == null ? null : EnrollmentPhase.fromCode(code);
  }

  Future<void> setPhase(EnrollmentPhase phase) async {
    // Shares one transaction so concurrent scalar writes serialize
    // instead of losing one update.
    await _db.transaction(() async {
      final existing = await _ensureScalar();
      await _db
          .into(_db.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion(
              id: const Value(_metaRowId),
              backendSelection: Value(existing.backendSelection),
              enrollmentPhase: Value<int?>(phase.code),
              writeGate: Value(existing.writeGate),
            ),
          );
    });
  }

  Future<bool> isWriteGateEnabled() async {
    final row = await _ensureScalar();
    return row.writeGate;
  }

  /// Enables the write gate after reconciliation completes. Repeat enables
  /// stay enabled. Throws [WriteGateNotReadyError] when enabling early.
  Future<void> setWriteGateEnabled(bool enabled) async {
    await _db.transaction(() async {
      final existing = await _ensureScalar();
      if (enabled && !existing.writeGate) {
        final code = existing.enrollmentPhase;
        final phase = code == null ? null : EnrollmentPhase.fromCode(code);
        if (phase != EnrollmentPhase.reconciliationComplete) {
          throw WriteGateNotReadyError(
            'Cannot enable the write gate from phase $phase: durable '
            'enrollment must reach reconciliationComplete first.',
          );
        }
      }
      await _db
          .into(_db.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion(
              id: const Value(_metaRowId),
              backendSelection: Value(existing.backendSelection),
              enrollmentPhase: Value(existing.enrollmentPhase),
              writeGate: Value(enabled),
            ),
          );
    });
  }

  /// Returns the opaque pull cursor for [collection]. Returns null when no
  /// page has been committed yet.
  Future<String?> getWatermark(SyncCollection collection) async {
    final row =
        await (_db.select(_db.syncWatermark)
              ..where((t) => t.collection.equals(collection.wireName)))
            .getSingleOrNull();
    return row?.cursor;
  }

  Future<void> setWatermark(SyncCollection collection, String cursor) async {
    await _db
        .into(_db.syncWatermark)
        .insertOnConflictUpdate(_watermarkRow(collection, cursor));
  }

  Future<Map<SyncCollection, String>> getAllWatermarks() async {
    final rows = await _db.select(_db.syncWatermark).get();
    return {
      for (final row in rows) _collection(row.collection): row.cursor,
    };
  }

  Future<VersionVector?> getAcknowledgedVector(SyncRowID rowID) async {
    final row =
        await (_db.select(_db.syncAcknowledgedVector)..where(
              (t) =>
                  t.collection.equals(rowID.collection.wireName) &
                  t.rowID.equals(rowID.rowID),
            ))
            .getSingleOrNull();
    return _decodeVector(row?.versionData);
  }

  Future<void> setAcknowledgedVector(
    SyncRowID rowID,
    VersionVector vector,
  ) async {
    await _db
        .into(_db.syncAcknowledgedVector)
        .insertOnConflictUpdate(_ackVectorRow(rowID, vector));
  }

  Future<Map<SyncRowID, VersionVector>> getAllAcknowledgedVectors() async {
    final rows = await _db.select(_db.syncAcknowledgedVector).get();
    final result = <SyncRowID, VersionVector>{};
    for (final row in rows) {
      result[SyncRowID.of(
        _collection(row.collection),
        row.rowID,
      )] = _requireVector(
        row.versionData,
        'acknowledged vector ${row.collection}/${row.rowID}',
      );
    }
    return result;
  }

  Future<void> clearAcknowledgedVector(SyncRowID rowID) async {
    await (_db.delete(_db.syncAcknowledgedVector)..where(
          (t) =>
              t.collection.equals(rowID.collection.wireName) &
              t.rowID.equals(rowID.rowID),
        ))
        .go();
  }

  Future<bool> hasPendingAck(
    SyncCollection collection,
    String checkpoint,
  ) async {
    final row =
        await (_db.select(_db.syncPendingAck)..where(
              (t) =>
                  t.collection.equals(collection.wireName) &
                  t.checkpoint.equals(checkpoint),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> setPendingAck(
    SyncCollection collection,
    String checkpoint,
  ) async {
    // Replays after a crash reuse the same checkpoint. A plain insert
    // fails when the row already exists.
    await _db
        .into(_db.syncPendingAck)
        .insertOnConflictUpdate(
          SyncPendingAckData(
            collection: collection.wireName,
            checkpoint: checkpoint,
          ),
        );
  }

  Future<void> clearPendingAck(
    SyncCollection collection,
    String checkpoint,
  ) async {
    await (_db.delete(_db.syncPendingAck)..where(
          (t) =>
              t.collection.equals(collection.wireName) &
              t.checkpoint.equals(checkpoint),
        ))
        .go();
  }

  Future<List<PendingCheckpoint>> allPendingCheckpoints() async {
    final rows = await _db.select(_db.syncPendingAck).get();
    return [
      for (final row in rows)
        PendingCheckpoint(_collection(row.collection), row.checkpoint),
    ];
  }

  /// Commits page vectors, watermark, and pending acknowledgement together.
  /// Rolls back the whole commit when any part fails.
  Future<void> commitPullPage({
    required SyncCollection collection,
    required String checkpoint,
    required String watermark,
    required Map<SyncRowID, VersionVector> acknowledgedVectors,
  }) async {
    await _db.transaction(() async {
      for (final entry in acknowledgedVectors.entries) {
        await _db
            .into(_db.syncAcknowledgedVector)
            .insertOnConflictUpdate(_ackVectorRow(entry.key, entry.value));
      }
      await _db
          .into(_db.syncWatermark)
          .insertOnConflictUpdate(_watermarkRow(collection, watermark));
      // Reuses the checkpoint after a crash. A plain insert fails when the
      // row already exists.
      await _db
          .into(_db.syncPendingAck)
          .insertOnConflictUpdate(
            SyncPendingAckData(
              collection: collection.wireName,
              checkpoint: checkpoint,
            ),
          );
    });
  }

  /// Clears one pending acknowledgement after the backend confirms success.
  Future<void> acknowledgePullPage(
    SyncCollection collection,
    String checkpoint,
  ) async {
    await clearPendingAck(collection, checkpoint);
  }

  Uint8List _encodeVector(VersionVector vector) =>
      Uint8List.fromList(vector.encode());

  VersionVector? _decodeVector(Uint8List? blob) =>
      blob == null ? null : VersionVector.decode(blob);

  // Fails with context so a missing blob points to its row.
  VersionVector _requireVector(Uint8List? blob, String context) {
    final vector = _decodeVector(blob);
    if (vector == null) {
      throw StateError('Missing stored version vector for $context.');
    }
    return vector;
  }

  SyncWatermarkData _watermarkRow(SyncCollection collection, String cursor) =>
      SyncWatermarkData(collection: collection.wireName, cursor: cursor);

  SyncAcknowledgedVectorData _ackVectorRow(
    SyncRowID rowID,
    VersionVector vector,
  ) => SyncAcknowledgedVectorData(
    collection: rowID.collection.wireName,
    rowID: rowID.rowID,
    versionData: _encodeVector(vector),
  );

  SyncCollection _collection(String wireName) =>
      SyncCollection.values.firstWhere(
        (collection) => collection.wireName == wireName,
        orElse: () =>
            throw FormatException('Unknown sync collection: $wireName'),
      );
}
