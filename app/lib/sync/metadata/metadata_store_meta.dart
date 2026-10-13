part of '../sync_metadata_store.dart';

// MARK: - Meta Row Access

extension SyncMetadataStoreMeta on SyncMetadataStore {
  Future<SyncMetadataSnapshot> snapshot() => _db.transaction(() async {
    final meta = await _metaRow();
    return SyncMetadataSnapshot(
      backend: SyncBackendKind.fromCode(meta.backend),
      endpoint: meta.endpoint,
      phase: SyncEnrollmentPhase.fromCode(meta.enrollmentPhase),
      writeEnabled: meta.writeEnabled,
      deviceBindingRequired:
          meta.deviceBindingState != SyncDeviceBindingState.notApplicable.code,
      deviceBindingState: SyncDeviceBindingState.fromCode(
        meta.deviceBindingState,
      ),
      reauthResumePhase: switch (meta.reauthResumePhase) {
        null => null,
        final code => SyncEnrollmentPhase.fromCode(code),
      },
      watermarks: {
        for (final collection in SyncCollection.values)
          collection: _watermarkOf(meta, collection),
      },
    );
  });

  Future<void> clearBackendSelection() => _updateMeta(
    SyncMetaCompanion(
      backend: const Value<String?>(null),
      endpoint: const Value<String?>(null),
    ),
  );

  Future<void> setPullWatermark(SyncCollection collection, String? cursor) =>
      _updateMeta(_watermarkCompanion(collection, cursor));

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

  // MARK: - Watermark Columns

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

// MARK: - Watermark Column

final class _WatermarkColumn {
  const _WatermarkColumn({
    required this.readCursor,
    required this.buildCompanion,
  });

  final String? Function(SyncMetadataRow meta) readCursor;
  final SyncMetaCompanion Function(String? cursor) buildCompanion;
}
