part of '../sync_metadata_store.dart';

// MARK: - Acknowledged Vectors

extension SyncMetadataStoreAcknowledgements on SyncMetadataStore {
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

  // MARK: - Pending Acknowledgements

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
    await _writeMeta(
      SyncMetadataStoreMeta._watermarkCompanion(collection, watermark),
    );
    await _db
        .into(_db.syncPendingAcknowledgements)
        .insertOnConflictUpdate(
          SyncPendingAcknowledgementsCompanion.insert(
            collection: collection,
            checkpoint: checkpoint,
          ),
        );
  });
}
