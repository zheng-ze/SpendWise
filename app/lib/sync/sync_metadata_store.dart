import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:sync/sync.dart';

import 'package:spendwise/persistence/ledger_database.dart';

/// Monotonic durable enrollment milestones. Stored as the enum's explicit
/// `code`, never its `index`. Null before enrollment starts.
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

/// Error thrown when enabling the sync write gate before durable enrollment
/// records reconciliation complete. Disabling the gate never throws.
final class WriteGateNotReadyError implements Exception {
  const WriteGateNotReadyError(this.message);

  final String message;

  @override
  String toString() => 'WriteGateNotReadyError: $message';
}

/// One owed pull-page acknowledgement, keyed by collection and checkpoint.
///
/// Retained across failures and restarts until the backend confirms success.
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

/// Drift-backed sync metadata for one device.
///
/// Owns the backend selection, durable enrollment phases, the write gate, the
/// five per-collection watermarks, the acknowledged vectors keyed by
/// [SyncRowID], and the pending pull acknowledgements keyed by collection and
/// checkpoint.
///
/// Every mutation that touches more than one of these values commits inside a
/// single Drift transaction, so a combined pulled-vector, page-watermark, and
/// pending-acknowledgement update commits all of them or none.
class SyncMetadataStore {
  SyncMetadataStore(this._db);

  final LedgerDatabase _db;

  static const _metaRowId = 0;

  // --- Scalars fixed to one row -------------------------------------------------

  /// Ensures the scalar row exists before a read, so a fresh or migrated
  /// store reports pre-enrollment defaults instead of a missing row.
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
    // The companion carries an explicit present null so clearing the
    // selection writes NULL. A plain data-class upsert would omit the null
    // column from the SET clause and silently keep the old value.
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
    // The read and the upsert share one transaction so two concurrent scalar
    // mutations serialize instead of interleaving read-read-write-write and
    // losing one write.
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

  /// Enables the write gate only once durable enrollment records
  /// [EnrollmentPhase.reconciliationComplete]. Enabling an already-enabled
  /// gate is an idempotent no-op; disabling the gate has no restriction.
  ///
  /// Throws [WriteGateNotReadyError] when enabling from any earlier phase.
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

  // --- Per-collection watermarks ------------------------------------------------

  Future<VersionVector?> getWatermark(SyncCollection collection) async {
    final row =
        await (_db.select(_db.syncWatermark)
              ..where((t) => t.collection.equals(collection.wireName)))
            .getSingleOrNull();
    return _decodeVector(row?.versionData);
  }

  Future<void> setWatermark(
    SyncCollection collection,
    VersionVector vector,
  ) async {
    await _db
        .into(_db.syncWatermark)
        .insertOnConflictUpdate(_watermarkRow(collection, vector));
  }

  Future<Map<SyncCollection, VersionVector>> getAllWatermarks() async {
    final rows = await _db.select(_db.syncWatermark).get();
    final result = <SyncCollection, VersionVector>{};
    for (final row in rows) {
      result[_collection(row.collection)] = _requireVector(
        row.versionData,
        'watermark ${row.collection}',
      );
    }
    return result;
  }

  // --- Acknowledged vectors keyed by SyncRowID ----------------------------------

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

  // --- Pending pull acknowledgements --------------------------------------------

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
    // Upsert: a crash/retry replays the same checkpoint, so the row may
    // already exist. A plain insert would fail with a UNIQUE violation.
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

  // --- Atomic multi-value commits -----------------------------------------------

  /// Commits the acknowledged vectors for a pulled page, that page's
  /// watermark, and its pending acknowledgement together. All of them commit
  /// inside one Drift transaction, or the whole commit rolls back.
  Future<void> commitPullPage({
    required SyncCollection collection,
    required String checkpoint,
    required VersionVector watermark,
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
      // Upsert for the same crash/retry reason as [setPendingAck]: the row
      // for this collection and checkpoint may already exist.
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

  // --- Encoding helpers ---------------------------------------------------------

  Uint8List _encodeVector(VersionVector vector) =>
      Uint8List.fromList(vector.encode());

  VersionVector? _decodeVector(Uint8List? blob) =>
      blob == null ? null : VersionVector.decode(blob);

  /// Decodes a stored vector, failing with context instead of a bare null
  /// assertion when the stored blob is missing or undecodable.
  VersionVector _requireVector(Uint8List? blob, String context) {
    final vector = _decodeVector(blob);
    if (vector == null) {
      throw StateError('Missing stored version vector for $context.');
    }
    return vector;
  }

  SyncWatermarkData _watermarkRow(
    SyncCollection collection,
    VersionVector vector,
  ) => SyncWatermarkData(
    collection: collection.wireName,
    versionData: _encodeVector(vector),
  );

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
