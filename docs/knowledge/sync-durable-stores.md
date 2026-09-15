# Sync: durable app stores

Last reconciled: 693d471

## Layer overview

The app-side durable sync layer keeps sync coordination state in Drift so it survives restart.
It owns the sync schema, the metadata store, and the Drift-backed staging-store implementation.
It never holds a bearer token, the E2E key, or the opaque credential payload; `SecretStore`
owns those separately. Nothing calls these stores yet; the coordinator and the enrollment flow
arrive in later tickets. Source: `app/lib/sync/sync_tables.dart` - table doc comments;
`app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore`;
`app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore`.

## Key files

- `app/lib/sync/sync_tables.dart` - The five sync-coordination tables and their key shapes.
- `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore`, `SyncEnrollmentPhase`,
  `SyncBackendKind`, and `SyncMetadataSnapshot`.
- `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore`, the Drift-backed
  `SyncStagingStore` with async durable core methods and synchronous engine-path overrides.
- `app/lib/persistence/ledger_database.dart` - Schema version 4 and the additive v3 to v4
  migration.
- `app/test/sync/sync_metadata_store_test.dart` - Metadata defaults, round-trips, atomicity and
  rollback, secret separation, and restart durability.
- `app/test/sync/drift_sync_staging_store_test.dart` - Staging contract, ordering, rollback,
  and restart durability.
- `app/test/sync/sync_migration_test.dart` - The additive migration over a version-3-shaped
  database.

## Module interactions

`SyncMetadataStore` wraps `LedgerDatabase`. Its singleton `sync_meta` row holds the nullable
backend selection, the enrollment phase, the write gate, and the five pull watermarks; the
`sync_acknowledged_vectors` table holds composite vectors keyed by `SyncRowID`, and the
`sync_pending_acknowledgements` table holds one staged-but-unacknowledged checkpoint per
collection. Every mutation runs in one Drift transaction, including the combined pulled-vector,
page-watermark, and pending-acknowledgement commit in `recordPulledPage`. Source:
`app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.snapshot`,
`SyncMetadataStore.recordPulledPage`.

`DriftSyncStagingStore` implements the `packages/sync` staging contract (`stage` replaces the
group for the same collection and row, `pendingConflicts` returns oldest first, `resolve` is an
idempotent no-op when absent). Sibling rows keep the package-codec payload bytes, the
persistence-codec version vector, and an explicit lifecycle code; `position` preserves decoded
order and `ORDER BY rowid` preserves oldest-first group order with replacement moving newest.
The async core methods (`stageConflict`, `pendingConflictList`, `resolveConflict`) are the
durable path; the synchronous overrides enqueue the same work for the engine and `flush`
settles it. Source: `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore`;
`packages/sync/lib/src/engine/staging_store.dart` - `SyncStagingStore`.

The v3 to v4 migration creates the five tables with `CREATE TABLE IF NOT EXISTS`, so existing
user rows are preserved. Source: `app/lib/persistence/ledger_database.dart` - `migration`;
`app/test/sync/sync_migration_test.dart` - test
`the v3 to v4 migration preserves existing user rows`.

## Navigation

This layer has no routes or screens. Enrollment, coordination, and conflict-review UI consume
these stores from later tickets. Source: `app/lib/sync/sync_metadata_store.dart` - class doc
`This store never holds a bearer token`.

## APIs

- `SyncMetadataStore.snapshot()` reads the singleton row in one transaction for a consistent
  startup-recovery view. Source: `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.snapshot`.
- `SyncMetadataStore.setBackendSelection` and `clearBackendSelection` write the nullable
  backend profile and endpoint; both stay null until enrollment. Source:
  `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.setBackendSelection`.
- `SyncMetadataStore.setEnrollmentPhase` records `notEnrolled`, `credentialAcquired`,
  `snapshotInProgress`, `reconciliationComplete`, or `gateEnabled` under explicit integer
  codes. Source: `app/lib/sync/sync_metadata_store.dart` - `SyncEnrollmentPhase`.
- `SyncMetadataStore.setWriteEnabled` flips the write gate. Source:
  `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.setWriteEnabled`.
- `SyncMetadataStore.setPullWatermark` records one collection cursor; a null cursor clears it.
  Source: `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.setPullWatermark`.
- `SyncMetadataStore.acknowledgedVector`, `acknowledgedVectors`, and `setAcknowledgedVector`
  read and upsert composite vectors keyed by `SyncRowID`, keeping identical UUIDs in different
  collections independent. Source: `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.setAcknowledgedVector`.
- `SyncMetadataStore.pendingAcknowledgement`, `pendingAcknowledgements`,
  `setPendingAcknowledgement`, and `clearPendingAcknowledgement` keep one durable checkpoint
  per collection, removed only after confirmed acknowledgement. Source:
  `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.setPendingAcknowledgement`.
- `SyncMetadataStore.recordPulledPage` commits verified per-row vectors, the page watermark,
  and the pending acknowledgement atomically; an empty vector map still advances the watermark
  and acknowledgement for duplicate or dominated pages, and a cross-collection vector throws
  `ArgumentError` before anything commits. Source: `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.recordPulledPage`.
- `DriftSyncStagingStore.open` loads persisted groups so staged conflicts survive a force-quit;
  `pendingConflictList` re-reads them oldest first. Source:
  `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore.open`,
  `DriftSyncStagingStore.pendingConflictList`.

## Gotchas and invariants

- Every `SyncMetadataStore` mutation executes atomically in one Drift transaction. A failed
  commit rolls back every value in the batch, including multi-value page records. Source:
  `app/test/sync/sync_metadata_store_test.dart` - group
  `transaction atomicity and rollback`.
- `SyncEnrollmentPhase` and the staged sibling lifecycle use explicit persisted codes, never
  `enum.index`, so reordering an enum cannot corrupt rows. Source:
  `app/lib/sync/sync_metadata_store.dart` - `SyncEnrollmentPhase`;
  `app/lib/sync/drift_sync_staging_store.dart` - `_stagedLifecycleLive`.
- Identical UUIDs in different collections keep independent acknowledged vectors, matching the
  `SyncRowID` composite identity used by stamps and reconciliation. Source:
  `app/test/sync/sync_metadata_store_test.dart` - test
  `keeps identical UUIDs in different collections independent`.
- Staging replacement moves the group to the newest position, matching the in-memory store's
  remove-then-add order. Source:
  `app/test/sync/drift_sync_staging_store_test.dart` - test
  `a replacement moves to the newest position`.
- `DriftSyncStagingStore.pendingConflicts` reflects the last settled state. Engine-enqueued
  writes need `flush` (or the async core method) before their durability can be relied on, for
  example before advancing a page watermark over staged rows. Source:
  `app/lib/sync/drift_sync_staging_store.dart` - class doc, `DriftSyncStagingStore.flush`.
- `resolve` matches only collection and row ID, so resolving from a stale view can remove a
  newer replacement group for the same row. Source:
  `packages/sync/lib/src/engine/staging_store.dart` - `InMemorySyncStagingStore.resolve`;
  `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore.resolveConflict`.
- Unknown enrollment-phase codes, backend strings, collections, and sibling lifecycles read
  back as `FormatException`, surfacing corruption loudly instead of defaulting. Source:
  `app/lib/sync/sync_metadata_store.dart` - `SyncEnrollmentPhase.fromCode`,
  `SyncBackendKind.fromCode`;
  `app/lib/sync/drift_sync_staging_store.dart` - `DriftSyncStagingStore._decodeSibling`.

## Requirements

- Keep backend selection null until enrollment, with durable phases, write gate, five
  watermarks, composite acknowledged vectors, and pending pull acknowledgements. Source:
  `app/test/sync/sync_metadata_store_test.dart` - group `defaults`.
- Commit every metadata mutation, including combined page updates, in one atomic Drift
  transaction with rollback on failure. Source:
  `app/test/sync/sync_metadata_store_test.dart` - group
  `transaction atomicity and rollback`.
- Never store a bearer token, E2E key, opaque credential payload, or second device ID in the
  sync schema; the schema column sets guard this structurally. Source:
  `app/test/sync/sync_metadata_store_test.dart` - group `secret separation`.
- Keep the schema change additive so migration preserves existing user rows. Source:
  `app/test/sync/sync_migration_test.dart` - test
  `the v3 to v4 migration preserves existing user rows`.
- Implement the staging contract exactly: replacement by `SyncRowID`, oldest-first ordering,
  idempotent resolve, and post-force-quit reconstruction. Source:
  `app/test/sync/drift_sync_staging_store_test.dart` - groups `stage`,
  `pendingConflicts`, `resolve`, and `restart durability`.
