import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/backend_selection_writer.dart';
import 'package:sync/sync.dart';

enum SyncEnrollmentPhase {
  notEnrolled(0),

  credentialAcquired(1),
  snapshotInProgress(2),

  reconciliationComplete(3),
  gateEnabled(4),

  bindingAuthorizationRequired(5),
  sessionReauthRequired(6);

  const SyncEnrollmentPhase(this.code);

  final int code;

  static SyncEnrollmentPhase fromCode(int code) => values.firstWhere(
    (phase) => phase.code == code,
    orElse: () =>
        throw FormatException('Unknown sync enrollment phase code: $code.'),
  );
}

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

final class SyncWriteGateException implements Exception {
  const SyncWriteGateException(this.message);

  final String message;

  @override
  String toString() => 'SyncWriteGateException: $message';
}

final class SyncMetadataSnapshot {
  const SyncMetadataSnapshot({
    required this.backend,
    required this.endpoint,
    required this.phase,
    required this.writeEnabled,
    this.deviceBindingRequired = false,
    required this.watermarks,
  });

  final SyncBackendKind? backend;

  final String? endpoint;

  final SyncEnrollmentPhase phase;
  final bool writeEnabled;

  // The row needs binding authorization before writes may resume.
  final bool deviceBindingRequired;

  final Map<SyncCollection, String?> watermarks;
}

final class SyncMetadataStore implements BackendSelectionWriter {
  SyncMetadataStore(this._db);

  final LedgerDatabase _db;

  @visibleForTesting
  LedgerDatabase get database => _db;

  Future<SyncMetadataSnapshot> snapshot() => _db.transaction(() async {
    final meta = await _metaRow();
    return SyncMetadataSnapshot(
      backend: SyncBackendKind.fromCode(meta.backend),
      endpoint: meta.endpoint,
      phase: SyncEnrollmentPhase.fromCode(meta.enrollmentPhase),
      writeEnabled: meta.writeEnabled,
      deviceBindingRequired: meta.deviceBindingState != 0,
      watermarks: {
        for (final collection in SyncCollection.values)
          collection: _watermarkOf(meta, collection),
      },
    );
  });

  @override
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
