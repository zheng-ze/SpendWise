# Sync: durable app stores

Last reconciled: 3f27737

## Layer overview

Durable app-side sync state in the same SQLite file as the ledger: `SyncMetadataStore` owns
backend selection, enrollment phase, the write gate, per-collection pull cursors, acknowledged
version vectors, and pending pull acknowledgements; `DriftSyncStagingStore` is the durable
`SyncStagingStore` handed to `SyncEngine` for unresolved conflict groups. Both survive restart and
force-quit because they live in `LedgerDatabase`, not in memory.

This layer sits between two siblings. The `packages/sync` engine (`sync-package-engine.md`) owns
encryption, the payload codec, frontier reduction, and the staging contract but never touches
Drift; this layer implements that contract durably. The persistence pipeline (`persistence.md`)
owns user-row ingest and the v4 schema DDL; this layer owns the behavior over the five sync
tables. Schema v4 details live in `persistence.md`; engine reconciliation details live in
`sync-package-engine.md`.

## Key files

- `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore`, `EnrollmentPhase`,
  `WriteGateNotReadyError`, `PendingCheckpoint`: every durable metadata read and write.
- `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore.open`, `stage`, `resolve`,
  `pendingConflicts`, `flush`: durable staging handed to `SyncEngine`.
- `app/lib/persistence/tables.dart` - `SyncMetadata`, `SyncWatermark`, `SyncAcknowledgedVector`,
  `SyncPendingAck`, `SyncStagingGroup`: table shapes this layer reads and writes.
- `app/lib/persistence/ledger_database.dart` - `LedgerDatabase.schemaVersion`,
  `LedgerDatabase._createSyncTables`: schema v4 and the atomic v3-to-v4 upgrade (DDL owned by
  `persistence.md`).
- `app/test/sync/sync_metadata_store_test.dart` - scalar, watermark, ack-vector, pending-ack, and
  `commitPullPage` contracts, including concurrency, idempotency, rollback, and reopen tests.
- `app/test/sync/drift_sync_staging_store_test.dart` - engine-seam, replacement, ordering,
  roundtrip, tombstone, reopen, and write-failure contracts.
- `app/test/sync/sync_schema_migration_test.dart` - v4 upgrade shape, data preservation, atomicity,
  and the upgraded database serving both stores.

## Module interactions

`SyncMetadataStore` wraps one `LedgerDatabase`. Scalars (`backendSelection`, `enrollmentPhase`,
`writeGate`) share the single `sync_metadata` row (`id = 0`); every scalar mutation reads the
existing row and upserts inside one Drift transaction so concurrent mutations serialize instead of
losing a write. A fresh or migrated store reports pre-enrollment defaults (null, null, gate off)
via `_ensureScalar`. Source: `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore`,
`SyncMetadataStore._ensureScalar`, `SyncMetadataStore.setBackendSelection`,
`SyncMetadataStore.setPhase`, `SyncMetadataStore.setWriteGateEnabled`;
`app/test/sync/sync_metadata_store_test.dart` - groups `scalars` and
`concurrent scalar mutations lose no write`.

`DriftSyncStagingStore` implements the package `SyncStagingStore` seam directly, so the object
passed to `SyncEngine` satisfies the engine contract: `stage` replaces the prior group for the
same collection and row, `pendingConflicts` returns groups oldest-first, `resolve` removes a group
as an idempotent no-op when absent. It keeps a synchronous in-memory cache for the engine and
persists write-through in the background in call order; `open` hydrates the cache from Drift
oldest-first by `sequence`, and `flush` is the durability barrier awaited before closing the
database or the process. Source:
`app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore.open`,
`DriftSyncStagingStore.stage`, `DriftSyncStagingStore.pendingConflicts`,
`DriftSyncStagingStore.resolve`, `DriftSyncStagingStore.flush`;
`packages/sync/lib/src/engine/staging_store.dart` - `SyncStagingStore`;
`app/test/sync/drift_sync_staging_store_test.dart` - groups `engine seam` and `contract`.

Pull progress commits atomically through `commitPullPage`: the page's acknowledged vectors, its
watermark, and its pending acknowledgement commit inside one Drift transaction or roll everything
back. `acknowledgePullPage` clears one owed acknowledgement after the backend confirms success.
Source: `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.commitPullPage`,
`SyncMetadataStore.acknowledgePullPage`; `app/test/sync/sync_metadata_store_test.dart` - group
`commitPullPage`.

Staged siblings are stored decrypted in plaintext (`sibling_data`), consistent with the existing
plaintext ledger storage policy. Wire encryption stays in the package engine (`SyncCipher`);
at-rest staging is not a second encryption layer. Source:
`app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore` class docs,
`DriftSyncStagingStore._encodeSiblings`.

## Navigation

This layer has no routes, screens, back-stack behavior, or deep links. Conflict-review UI lives
outside it and reads `pendingConflicts` when it ships.

## APIs

- `getBackendSelection() / setBackendSelection(String? profileID)` replaces the one-row selection;
  `null` clears via an explicit present-null companion, so the null reaches the `SET` clause
  instead of being omitted. Source: `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.setBackendSelection`; `app/test/sync/sync_metadata_store_test.dart` - test
  `setBackendSelection(null) clears a prior selection`.
- `getPhase() / setPhase(EnrollmentPhase)` round-trips the explicit `code` (0-3), never
  `enum.index`; unknown codes throw `ArgumentError`. Source:
  `app/lib/sync/sync_metadata_store.dart` - `EnrollmentPhase`, `EnrollmentPhase.fromCode`.
- `isWriteGateEnabled() / setWriteGateEnabled(bool)` defaults off. Enabling throws
  `WriteGateNotReadyError` unless durable enrollment records `reconciliationComplete`; enabling
  an already-enabled gate is an idempotent no-op even after the phase advances; disabling never
  throws from any phase. Source: `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.setWriteGateEnabled`, `WriteGateNotReadyError`;
  `app/test/sync/sync_metadata_store_test.dart` - tests
  `enabling the write gate before reconciliationComplete throws`,
  `enabling the write gate at reconciliationComplete succeeds`,
  `enabling an already-enabled gate is an idempotent no-op`, and
  `disabling the write gate succeeds from any phase`.
- `getWatermark(collection) / setWatermark(collection, cursor) / getAllWatermarks()` stores one
  opaque server-assigned pull cursor per collection; missing reads return null, writes replace,
  and the cursor hands straight to `PullRequest(cursor:)`. Five rows, one per `SyncCollection`.
  Source: `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.getWatermark`,
  `SyncMetadataStore.setWatermark`, `SyncMetadataStore.getAllWatermarks`;
  `app/test/sync/sync_metadata_store_test.dart` - group `watermarks`.
- `getAcknowledgedVector(rowID) / setAcknowledgedVector(rowID, vector) /
  getAllAcknowledgedVectors() / clearAcknowledgedVector(rowID)` keys vectors by normalized
  `SyncRowID` (`collection`, `rowID`); identical UUIDs in different collections stay independent.
  Source: `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.getAcknowledgedVector`,
  `SyncMetadataStore.setAcknowledgedVector`; `app/test/sync/sync_metadata_store_test.dart` -
  group `acknowledged vectors`.
- `hasPendingAck(collection, checkpoint) / setPendingAck(collection, checkpoint) /
  clearPendingAck(collection, checkpoint) / allPendingCheckpoints() / acknowledgePullPage(collection,
  checkpoint)` tracks owed pull-page acknowledgements. `setPendingAck` upserts, so a crash/retry
  replay of the same checkpoint never throws a UNIQUE violation. Source:
  `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.setPendingAck`,
  `SyncMetadataStore.acknowledgePullPage`; `app/test/sync/sync_metadata_store_test.dart` - group
  `pending pull acknowledgements`.
- `commitPullPage(collection:, checkpoint:, watermark:, acknowledgedVectors:)` commits vectors,
  watermark, and pending ack together in one transaction; a repeated commit for one checkpoint is
  idempotent; a failure rolls back every write and leaves seeded unrelated state untouched.
  Source: `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.commitPullPage`;
  `app/test/sync/sync_metadata_store_test.dart` - tests
  `commits ack vectors, watermark, and pending ack atomically`,
  `a repeated commitPullPage for one checkpoint is idempotent`, and
  `commitPullPage rolls back every write when the commit fails`.
- `DriftSyncStagingStore.open(db, onWriteError:)` hydrates the cache oldest-first by `sequence` and
  must be awaited before handing the store to `SyncEngine`. Source:
  `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore.open`.
- `stage(conflict)` replaces the group for the same `(collection, rowID)`, appends the new group
  (advancing its sequence), and enqueues a delete-plus-insert inside one transaction. Replacement
  keys on the composite, so the same normalized row id in two collections stages two groups.
  Source: `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore._persistStage`;
  `app/test/sync/drift_sync_staging_store_test.dart` - tests
  `stage replaces the prior group for the same collection and row` and
  `stage replaces only the matching collection for one shared row id`.
- `pendingConflicts` is unmodifiable, synchronous, and oldest-first; a re-stage moves that group
  last. Source: `app/lib/sync/drift_sync_staging_store.dart` -
  `DriftSyncStagingStore.pendingConflicts`; `app/test/sync/drift_sync_staging_store_test.dart` -
  tests `synchronous reads observe writes immediately` and `pendingConflicts returns groups oldest
  first`.
- `resolve(conflict)` removes by `(collection, rowID)` and is an idempotent no-op when absent.
  Source: `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore._persistResolve`;
  `app/test/sync/drift_sync_staging_store_test.dart` - test
  `resolve is an idempotent no-op when the group is absent`.
- `flush()` awaits every write-through write enqueued so far and throws the first failure enqueued
  since the previous flush threw or resolved, even when a later write in the same window
  succeeded; each failure surfaces through exactly one flush and once through `onWriteError`.
  Source: `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore.flush`,
  `DriftSyncStagingStore._runAfter`; `app/test/sync/drift_sync_staging_store_test.dart` - group
  `write-through failures`.

## Gotchas and invariants

- Clearing the backend selection writes NULL explicitly. A plain data-class upsert would omit the
  null column from the `SET` clause and silently keep the old value. Source:
  `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.setBackendSelection`.
- Scalar mutations serialize in transactions. A read-then-upsert without one interleaves
  read-read-write-write under concurrency and loses a write. Source:
  `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.setPhase`,
  `SyncMetadataStore.setBackendSelection`, `SyncMetadataStore.setWriteGateEnabled`.
- Watermarks are opaque cursor strings, never version vectors. The fixed snapshot watermark used
  during initial reconciliation is a separate value. Source:
  `app/lib/persistence/tables.dart` - `SyncWatermark`; `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.getWatermark`.
- Tombstone siblings round-trip to deletes for the group row, not the sibling id. The sibling id
  identifies the source envelope; rebuilding from it would fabricate a delete for a row that never
  existed. Deletes encode as empty payloads. Source:
  `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore._decodeSibling`;
  `app/test/sync/drift_sync_staging_store_test.dart` - test
  `tombstone siblings roundtrip to deletes for the group row`.
- Sibling encoding is JSON UTF-8 over `siblingID`, base64url `versionVector.encode()`, and base64url
  `PayloadCodec.encodeChange(change)`. Source: `app/lib/sync/drift_sync_staging_store.dart` -
  `DriftSyncStagingStore._encodeSiblings`.
- A failed write-through never blocks later writes and is never silent. Each failure is reported
  once to `onWriteError` and the next `flush` throws the first failure even when a later write
  succeeded; the cache then holds undurable groups a reload drops. Without this, staged state the
  cache holds would read as durable when it never reached Drift. Source:
  `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore._runAfter`,
  `DriftSyncStagingStore._settle`, `DriftSyncStagingStore._enqueue`;
  `app/test/sync/drift_sync_staging_store_test.dart` - tests
  `a failed durable write surfaces instead of diverging silently` and
  `flush throws the first failure even when a later write succeeds`.
- Committed page state and staged groups survive close and reopen over the same file, modelling a
  force-quit between commit and acknowledgement or between stage and review. Source:
  `app/test/sync/sync_metadata_store_test.dart` - test
  `committed page state survives close and reopen`;
  `app/test/sync/drift_sync_staging_store_test.dart` - test
  `staged siblings survive close and reopen`.
- `StagedConflict` identity here is `(collection, rowID)` with oldest-first ordering, matching the
  package seam: staging replaces the group, pending retains oldest-first order, resolving an
  absent group is a no-op. Source: `packages/sync/lib/src/engine/staging_store.dart` -
  `SyncStagingStore`; `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore`.

## Requirements

- Keep backend selection nullable until enrollment; clearing writes NULL. Source:
  `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.setBackendSelection`.
- Store `EnrollmentPhase` as its explicit `code`, never `enum.index`. Source:
  `app/lib/sync/sync_metadata_store.dart` - `EnrollmentPhase`.
- Enable the write gate only from `reconciliationComplete`; disabling has no restriction.
  Source: `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.setWriteGateEnabled`.
- Keep pull cursors opaque and per collection; keep acknowledged vectors keyed by normalized
  `SyncRowID`. Source: `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.getWatermark`, `SyncMetadataStore.getAcknowledgedVector`.
- Commit each pulled page's vectors, watermark, and pending ack in one transaction; replays of one
  checkpoint stay idempotent. Source: `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.commitPullPage`.
- Implement the package `SyncStagingStore` seam directly so the store compiles as the engine's
  staging argument: synchronous `stage`/`pendingConflicts`/`resolve` with replacement,
  oldest-first, and idempotent resolve. Source:
  `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore`;
  `app/test/sync/drift_sync_staging_store_test.dart` - group `engine seam`.
- Persist staged groups durably in `sync_staging_group` with `(collection, row_id)` uniqueness and
  `sequence` oldest-first ordering; hydrate oldest-first on `open`. Source:
  `app/lib/persistence/tables.dart` - `SyncStagingGroup`;
  `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore.open`.
- Surface every durable staging write failure through `onWriteError` and the next `flush`; never
  stall later writes and never diverge silently. Source:
  `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore.flush`.
