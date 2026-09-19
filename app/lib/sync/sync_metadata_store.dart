import 'package:drift/drift.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:sync/sync.dart';

/// Durable enrollment phase with explicit persisted codes.
///
/// Codes are stored in `sync_meta.enrollment_phase`; never persist
/// [SyncEnrollmentPhase.index] so reordering the enum cannot corrupt rows.
enum SyncEnrollmentPhase {
  /// Nothing enrolled yet. The initial state; backend selection stays null.
  notEnrolled(0),

  /// The opaque credential payload reached secure storage.
  credentialAcquired(1),

  /// Snapshot transfer or key work is in progress.
  snapshotInProgress(2),

  /// Reconciliation completed durably. Only this phase permits the gate flip.
  reconciliationComplete(3),

  /// The write gate was enabled durably.
  gateEnabled(4);

  const SyncEnrollmentPhase(this.code);

  final int code;

  static SyncEnrollmentPhase fromCode(int code) => values.firstWhere(
    (phase) => phase.code == code,
    orElse: () =>
        throw FormatException('Unknown sync enrollment phase code: $code.'),
  );
}

/// Selected sync backend profile with explicit persisted wire strings.
enum SyncBackendKind {
  supabase('supabase'),
  custom('custom');

  const SyncBackendKind(this.code);

  final String code;

  static SyncBackendKind? fromCode(String? code) {
    if (code == null) return null;
    return values.firstWhere(
      (kind) => kind.code == code,
      orElse: () => throw FormatException('Unknown sync backend: $code.'),
    );
  }
}

/// Error thrown when enabling the sync write gate is refused.
///
/// Only a durable [SyncEnrollmentPhase.reconciliationComplete] phase permits
/// the gate flip; credential presence alone never enables writes.
final class SyncWriteGateException implements Exception {
  const SyncWriteGateException(this.message);

  final String message;

  @override
  String toString() => 'SyncWriteGateException: $message';
}

/// Immutable read view of the singleton sync metadata row.
final class SyncMetadataSnapshot {
  const SyncMetadataSnapshot({
    required this.backend,
    required this.endpoint,
    required this.phase,
    required this.writeEnabled,
    required this.watermarks,
  });

  /// Null until enrollment.
  final SyncBackendKind? backend;

  /// Null until enrollment and unused by managed backends.
  final String? endpoint;

  final SyncEnrollmentPhase phase;
  final bool writeEnabled;

  /// Durable pull cursor per collection, null before the first pull.
  final Map<SyncCollection, String?> watermarks;
}

/// Drift-backed durable sync metadata, sibling to the staging store.
///
/// Every mutation executes atomically in one Drift transaction, including the
/// combined pulled-vector, page-watermark, and pending-acknowledgement update
/// in [recordPulledPage], which commits all values together or rolls back on
/// failure. This store never holds a bearer token, the E2E key, the opaque
/// credential payload, or a second device ID.
final class SyncMetadataStore {
  SyncMetadataStore(this._db);

  final LedgerDatabase _db;

  /// Reads the singleton row plus every keyed record in one transaction, so
  /// startup recovery observes a consistent view.
  Future<SyncMetadataSnapshot> snapshot() => _db.transaction(() async {
    final meta = await _metaRow();
    return SyncMetadataSnapshot(
      backend: SyncBackendKind.fromCode(meta.backend),
      endpoint: meta.endpoint,
      phase: SyncEnrollmentPhase.fromCode(meta.enrollmentPhase),
      writeEnabled: meta.writeEnabled,
      watermarks: {
        for (final collection in SyncCollection.values)
          collection: _watermarkOf(meta, collection),
      },
    );
  });

  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  }) => _updateMeta(
    SyncMetaCompanion(backend: Value(backend.code), endpoint: Value(endpoint)),
  );

  Future<void> clearBackendSelection() => _updateMeta(
    SyncMetaCompanion(
      backend: const Value<String?>(null),
      endpoint: const Value<String?>(null),
    ),
  );

  Future<void> setEnrollmentPhase(SyncEnrollmentPhase phase) =>
      _updateMeta(SyncMetaCompanion(enrollmentPhase: Value(phase.code)));

  /// Flips the write gate. Enabling is refused with [SyncWriteGateException]
  /// unless the stored enrollment phase is reconciliation-complete; the phase
  /// check runs inside the same transaction as the write, so a refused enable
  /// persists nothing. Disabling is always allowed.
  Future<void> setWriteEnabled(bool value) => _db.transaction(() async {
    await _ensureMetaRow();
    if (value) {
      final phase = SyncEnrollmentPhase.fromCode(
        (await _metaRow()).enrollmentPhase,
      );
      if (phase != SyncEnrollmentPhase.reconciliationComplete) {
        throw SyncWriteGateException(
          'Cannot enable sync writes from phase ${phase.name}; '
          'reconciliation must complete first.',
        );
      }
    }
    await _writeMeta(SyncMetaCompanion(writeEnabled: Value(value)));
  });

  Future<void> setPullWatermark(SyncCollection collection, String? cursor) =>
      _updateMeta(_watermarkCompanion(collection, cursor));

  Future<VersionVector?> acknowledgedVector(SyncRowID row) async {
    final found =
        await (_db.select(_db.syncAcknowledgedVectors)..where(
              (t) =>
                  t.collection.equalsValue(row.collection) &
                  t.rowId.equals(row.rowID),
            ))
            .getSingleOrNull();
    return found?.versionData;
  }

  Future<Map<SyncRowID, VersionVector>> acknowledgedVectors() async {
    final rows = await _db.select(_db.syncAcknowledgedVectors).get();
    return {
      for (final row in rows)
        SyncRowID.of(row.collection, row.rowId): row.versionData,
    };
  }

  Future<void> setAcknowledgedVector(SyncRowID row, VersionVector vector) =>
      _db.transaction(() async {
        await _db
            .into(_db.syncAcknowledgedVectors)
            .insertOnConflictUpdate(
              SyncAcknowledgedVectorsCompanion.insert(
                collection: row.collection,
                rowId: row.rowID,
                versionData: vector,
              ),
            );
      });

  Future<String?> pendingAcknowledgement(SyncCollection collection) async {
    final found = await (_db.select(
      _db.syncPendingAcknowledgements,
    )..where((t) => t.collection.equalsValue(collection))).getSingleOrNull();
    return found?.checkpoint;
  }

  Future<Map<SyncCollection, String>> pendingAcknowledgements() async {
    final rows = await _db.select(_db.syncPendingAcknowledgements).get();
    return {for (final row in rows) row.collection: row.checkpoint};
  }

  Future<void> setPendingAcknowledgement(
    SyncCollection collection,
    String checkpoint,
  ) => _db.transaction(() async {
    await _db
        .into(_db.syncPendingAcknowledgements)
        .insertOnConflictUpdate(
          SyncPendingAcknowledgementsCompanion.insert(
            collection: collection,
            checkpoint: checkpoint,
          ),
        );
  });

  Future<void> clearPendingAcknowledgement(SyncCollection collection) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.syncPendingAcknowledgements,
        )..where((t) => t.collection.equalsValue(collection))).go();
      });

  /// Clears [collection]'s pending acknowledgement only if its currently
  /// stored checkpoint still equals [checkpoint].
  ///
  /// A newer checkpoint already recorded for [collection] (for example by a
  /// concurrent [recordPulledPage] call while an older checkpoint's
  /// acknowledge call was in flight) is left untouched, so its retry
  /// obligation is never lost.
  Future<void> clearPendingAcknowledgementIfMatches(
    SyncCollection collection,
    String checkpoint,
  ) => _db.transaction(() async {
    await (_db.delete(_db.syncPendingAcknowledgements)..where(
          (t) =>
              t.collection.equalsValue(collection) &
              t.checkpoint.equals(checkpoint),
        ))
        .go();
  });

  /// Commits one pulled page durably: the verified per-row vectors, the page
  /// watermark, and the pending collection-checkpoint acknowledgement, all in
  /// one atomic Drift transaction.
  ///
  /// An empty [vectors] map records a duplicate or dominated page: the
  /// watermark and acknowledgement still advance while no vector changes.
  /// Throws [ArgumentError] when a vector targets another collection.
  Future<void> recordPulledPage({
    required SyncCollection collection,
    required Map<SyncRowID, VersionVector> vectors,
    required String watermark,
    required String checkpoint,
  }) => _db.transaction(() async {
    for (final entry in vectors.entries) {
      if (entry.key.collection != collection) {
        throw ArgumentError(
          'Vector for ${entry.key} does not belong to the $collection '
          'page.',
        );
      }
      await _db
          .into(_db.syncAcknowledgedVectors)
          .insertOnConflictUpdate(
            SyncAcknowledgedVectorsCompanion.insert(
              collection: collection,
              rowId: entry.key.rowID,
              versionData: entry.value,
            ),
          );
    }
    await _ensureMetaRow();
    await _writeMeta(_watermarkCompanion(collection, watermark));
    await _db
        .into(_db.syncPendingAcknowledgements)
        .insertOnConflictUpdate(
          SyncPendingAcknowledgementsCompanion.insert(
            collection: collection,
            checkpoint: checkpoint,
          ),
        );
  });

  Future<SyncMetadataRow> _metaRow() async {
    await _ensureMetaRow();
    return (_db.select(_db.syncMeta)..where((t) => t.id.equals(0))).getSingle();
  }

  // Writes companion to the singleton row, without its own transaction.
  // Callers must already hold a transaction and have called _ensureMetaRow.
  Future<void> _writeMeta(SyncMetaCompanion companion) =>
      (_db.update(_db.syncMeta)..where((t) => t.id.equals(0))).write(companion);

  Future<void> _updateMeta(SyncMetaCompanion companion) =>
      _db.transaction(() async {
        await _ensureMetaRow();
        await _writeMeta(companion);
      });

  Future<void> _ensureMetaRow() async {
    final existing = await (_db.select(
      _db.syncMeta,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.syncMeta)
          .insert(SyncMetaCompanion.insert(id: const Value(0)));
    }
  }

  static String? _watermarkOf(
    SyncMetadataRow meta,
    SyncCollection collection,
  ) => _watermarkColumnOf(collection).readCursor(meta);

  static SyncMetaCompanion _watermarkCompanion(
    SyncCollection collection,
    String? cursor,
  ) => _watermarkColumnOf(collection).buildCompanion(cursor);

  // One switch, not two: the analyzer flags a missing SyncCollection case
  // here at compile time, unlike a lookup keyed by a Map.
  static _WatermarkColumn _watermarkColumnOf(SyncCollection collection) =>
      switch (collection) {
        SyncCollection.moneySources => _WatermarkColumn(
          readCursor: (meta) => meta.moneySourcesCursor,
          buildCompanion: (cursor) =>
              SyncMetaCompanion(moneySourcesCursor: Value(cursor)),
        ),
        SyncCollection.entries => _WatermarkColumn(
          readCursor: (meta) => meta.entriesCursor,
          buildCompanion: (cursor) =>
              SyncMetaCompanion(entriesCursor: Value(cursor)),
        ),
        SyncCollection.categories => _WatermarkColumn(
          readCursor: (meta) => meta.categoriesCursor,
          buildCompanion: (cursor) =>
              SyncMetaCompanion(categoriesCursor: Value(cursor)),
        ),
        SyncCollection.plans => _WatermarkColumn(
          readCursor: (meta) => meta.plansCursor,
          buildCompanion: (cursor) =>
              SyncMetaCompanion(plansCursor: Value(cursor)),
        ),
        SyncCollection.budgets => _WatermarkColumn(
          readCursor: (meta) => meta.budgetsCursor,
          buildCompanion: (cursor) =>
              SyncMetaCompanion(budgetsCursor: Value(cursor)),
        ),
      };
}

final class _WatermarkColumn {
  const _WatermarkColumn({
    required this.readCursor,
    required this.buildCompanion,
  });

  final String? Function(SyncMetadataRow meta) readCursor;
  final SyncMetaCompanion Function(String? cursor) buildCompanion;
}
