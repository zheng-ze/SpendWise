# Persistence

Last reconciled: 3f27737

## Feature overview

The durable layer: a `LedgerStore` contract backed by Drift (SQLite), an in-memory implementation
for tests, the ordered ingest pipeline with debounce and coalescing, the version-vector write
path (type and codecs owned by `packages/sync`, used here on every write), and
the domain-to-row mapping. Rows mirror the domain models 1:1 and must never leak past the store.
Lives in `app/lib/persistence/`.

Schema v4 adds five device-local sync tables to the same SQLite file (metadata, watermarks,
acknowledged vectors, pending acks, staging groups). The tables live here; their durable behavior
lives in the sibling sync-stores layer. Source: `app/lib/persistence/ledger_database.dart` -
`LedgerDatabase`; `app/lib/persistence/tables.dart` - `SyncMetadata`, `SyncWatermark`,
`SyncAcknowledgedVector`, `SyncPendingAck`, `SyncStagingGroup`; sibling entry
`sync-durable-stores.md`.

## Key files

- `app/lib/persistence/ledger_store.dart` — the `LedgerStore` abstract contract,
  `SaveBannerState` (including `permanentlyFailed`), and `SaveErrorHandler`.
- `app/lib/persistence/drift_ledger_store.dart` — the Drift implementation of the pipeline and
  `PermanentSaveError` classification for undecodable stored version vectors.
- `app/lib/boot/banner_state.dart` — the `SaveBannerState` consumer that maps
  `permanentlyFailed` to `"Couldn't save changes"`.
- `app/lib/persistence/ledger_database.dart`, `ledger_database.g.dart`, `tables.dart` — schema and
  generated row models, including the five v4 sync tables and the v3-to-v4 upgrade. `schemaVersion`
  is 4; `_createSyncTables` creates the sync tables.
- `app/lib/sync/sync_metadata_store.dart` — durable sync metadata behavior (sibling layer
  `sync-durable-stores.md`, not owned here).
- `app/lib/sync/drift_sync_staging_store.dart` — durable conflict staging behavior (sibling layer
  `sync-durable-stores.md`, not owned here).
- `app/lib/persistence/mappers.dart` — domain ↔ row mapping, plus `versionFromRow` (decode) and
  the version-to-blob encode used on every write.
- `packages/sync/lib/src/protocol/version_vector.dart` — `VersionVector` and
  `VersionVectorDecodeError`: the causal type persistence imports via `package:sync/sync.dart`
  (relocated from `app/lib/persistence/` in commit `f00c5d9`). Owns `bump`, `dominates`,
  `isConcurrent`, the persistence JSON codec, and the separate wire decimal-string counters.
  Reconciliation orders through this type but merges nothing; see `sync-package-engine.md`.
- `app/lib/persistence/database_connection.dart` — `openLedgerConnection`, which imports
  `database_connection_native.dart` directly (no conditional import; web support was dropped in
  commit `e7a963d`).
- `app/lib/persistence/database_connection_native.dart` — `openConnection`, which opens a
  `NativeDatabase` file under the app's documents directory on every supported platform (Android,
  iOS, macOS, Windows, Linux).
- `app/lib/persistence/persistence_processor.dart` — bus-to-store bridge (also `ledger_runtime.md`).

## Module interactions

`PersistenceProcessor` subscribes to the `EventBus` and forwards every batch to `store.enqueue`
as-is, same batch boundaries, no filtering. `Ledger` publishes through the bus; UI never touches
it. `load()` rebuilds `LedgerState` via `LedgerState.replaying(changes)`, which bypasses validation
by design — it never calls the domain mutators, so no `LedgerError`, no invariant sweep, no cascade
runs (`persistence.md` §5). Replay is shared by `load()`, the in-memory double, and seeding.

## `LedgerStore` contract

| Member | Contract |
|---|---|
| `load()` | Reads all non-tombstoned rows, maps to domain, rebuilds `LedgerState` by replay. Throws on failure. Boot-time only. |
| `start()` | Begins draining the ingest queue. Idempotent; safe to call from `flushNow`. |
| `enqueue(changes)` | Synchronous, non-blocking; empty list is a no-op; batches ingest in call order. |
| `flushNow()` | Barrier: everything enqueued before the call is on disk when it returns. |
| `setErrorHandler(h)` | Registers the single banner callback; replaces it; no multicast. |
| `SaveBannerState` | `clear`, `retrying`, `failedWillRetry`, and `permanentlyFailed`; the handler signature remains `void Function(SaveBannerState)`. (`ledger_store.dart:SaveBannerState`, `SaveErrorHandler`) |

Schema conventions: IDs are lowercase `TEXT` PKs; money is `Decimal` `TEXT` (never `REAL`); dates
are epoch-millis UTC `INTEGER`; booleans are `INTEGER` 0/1; `version_data` is a `BLOB` JSON vector
on every table except `store_meta`; `lifecycle` is an `INTEGER` raw value on every table except
`store_meta`. The `entries` table reserves `note` and `system_kind` columns (day-one reservations,
unused in V1). `plans` flattens the `EntryTemplate` into `template_*` scalar columns.

## Sync schema (v4)

`schemaVersion` is 4. The v4 upgrade is purely additive: the six user tables keep their DDL and
every pre-v4 row survives unchanged. It creates five device-local sync tables and nothing else.
Source: `app/lib/persistence/ledger_database.dart` - `LedgerDatabase.schemaVersion`,
`LedgerDatabase._createSyncTables`; `app/lib/persistence/tables.dart` - `SyncMetadata`,
`SyncWatermark`, `SyncAcknowledgedVector`, `SyncPendingAck`, `SyncStagingGroup`;
`app/test/sync/sync_schema_migration_test.dart` - tests `v3 to v4 upgrade creates the sync tables`
and `v3 to v4 upgrade preserves existing user data`.

- `sync_metadata` - one row (`id = 0`, `CHECK (id = 0)`): nullable `backend_selection` (null until
  enrollment), nullable `enrollment_phase` (explicit enum code, null before enrollment), and
  `write_gate` (`INTEGER NOT NULL DEFAULT 0`, constrained to 0/1). A fresh or migrated store
  reports pre-enrollment defaults with the gate off.
- `sync_watermark` - one row per sync collection (`collection` PK): opaque server-assigned pull
  cursor (`cursor TEXT NOT NULL`). Never a version vector; the fixed reconciliation snapshot is a
  separate value owned outside this table.
- `sync_acknowledged_vector` - backend-acknowledged version vector per normalized
  `(collection, row_id)` (`version_data BLOB NOT NULL`). Identical UUIDs in different collections
  stay independent.
- `sync_pending_ack` - owed pull-page acknowledgement per `(collection, checkpoint)`. Retained
  across failures until the backend confirms success.
- `sync_staging_group` - one durable conflict group per `(collection, row_id)`
  (`UNIQUE (collection, row_id)`): decrypted staged siblings (`sibling_data BLOB NOT NULL`,
  plaintext like the ledger rows) ordered oldest-first by auto-increment `sequence`.

The five `CREATE TABLE` statements share one Drift transaction. A crash or storage failure
partway through rolls every statement back instead of leaving a partial v4 schema at
`user_version` 3 that the next launch could never open again ("table already exists" on retry).
Pinned by `a mid-migration failure rolls back and the retry completes` in
`app/test/sync/sync_schema_migration_test.dart`. Source:
`app/lib/persistence/ledger_database.dart` - `LedgerDatabase._createSyncTables`.

## Write pipeline

Constants: `debounce = 250 ms`, `maxRetries = 2`, `retryBackoff = 200 ms` (`drift_ledger_store.dart`).

1. **Ordered ingest** — `enqueue` appends to an unbounded FIFO; two enqueues stay in sequence,
   which makes last-write-wins coalescing correct.
2. **Debounce** — each batch buffered into `pending` cancels the previous timer and starts a fresh
   250 ms one; a burst produces one save ~250 ms after the last edit.
3. **Coalescing** — at flush, keep only the last change per `targetID`, preserving survivor order;
   upserts and deletes coalesce in the same keyspace. Coalescing spans everything in `pending`, not
   a single enqueue batch.
4. **Flush, retry, rollback** — one SQLite transaction applies the coalesced changes with a version
   bump per applied change. Non-terminal failures retry with `retrying`, then report
   `failedWillRetry` and arm a timed retry; `PermanentSaveError` reports `permanentlyFailed` and
   returns without arming one. (`app/lib/persistence/drift_ledger_store.dart:_runCycle`)
5. **`flushNow` barrier** — calls `start()` defensively, pushes a barrier, cancels the debounce
   timer, awaits any in-flight flush, then loops flush cycles until `pending` is empty (or a cycle
   gives up after reporting a retryable or terminal failure state.
   (`app/lib/persistence/drift_ledger_store.dart:flushNow`, `_runCycle`)

### Terminal save failures

`_decodeVersion` converts `VersionVectorDecodeError` from `versionFromRow` into
`PermanentSaveError`; both upserts and tombstones use it before bumping a stored vector.
`_runCycle` catches that type before `Object`, reports `SaveBannerState.permanentlyFailed`, and
does not arm a timed retry. (`app/lib/persistence/drift_ledger_store.dart:_decodeVersion`,
`_bumpedVersion`, `_tombstone`, `_runCycle`; commit `2445ed2`)

Drift's transaction implementation rolls back and rethrows the callback exception unchanged, so
the preceding typed catch receives `PermanentSaveError` rather than the generic retry path.
(`drift 2.34.3`, `ConnectionUser.transaction`; `drift_ledger_store.dart:_runCycle`)

A terminally failing change remains in `_pending`: only a committed transaction removes its raw
prefix. Each later cycle coalesces the full pending prefix and applies it in one transaction, so a
new unrelated change shares the failing transaction until the corrupted row is repaired.
(`app/lib/persistence/drift_ledger_store.dart:_runCycle`, `_coalesce`; commit `2445ed2`)

## Version vector

`VersionVector` lives in `packages/sync` and persistence imports it; there is no
`app/lib/persistence/version_vector.dart` since commit `f00c5d9`. It holds `Map<String, int>`
device→counters with `bump`, `dominates` (reflexive), and `isConcurrent`. Merge is still absent:
reconciliation reduces each row group to its non-dominated frontier instead of merging.
Source: `packages/sync/lib/src/protocol/version_vector.dart` - `VersionVector`;
`packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine._nonDominatedFrontier`.

Construction normalizes every device id, drops zero counters, rejects negative counters and
ids that normalize alike, and folds an empty map to `VersionVector.empty`. Source:
`packages/sync/lib/src/protocol/version_vector.dart` - `VersionVector` factory.

The persistence codec is UTF-8 JSON with integer counters. Decode accepts an empty blob as the
empty vector, a `{'counters': ...}` wrapper, the normalized object form, and the legacy Swift
alternating-array form for pre-existing rows. The wire codec is separate: `toWireCounters` /
`fromWireCounters` carry counters as decimal strings per the sync protocol, and must not be
confused with the stored integer form. Source:
`packages/sync/lib/src/protocol/version_vector.dart` - `VersionVector.encode`,
`VersionVector.decode`, `VersionVector.toWireCounters`, `VersionVector.fromWireCounters`.

Every applied write, upsert or tombstone, bumps the row's vector once with this device's id: a
uuid v4 claimed once into `store_meta` via `newID`, normalized, and cached per database.
Source: `app/lib/persistence/device_identity.dart` - `deviceID`, `_claimDeviceID`;
`packages/domain/lib/src/ids.dart` - `newID`;
`app/lib/persistence/drift_ledger_store.dart` - `_bumpedVersion`, `_tombstone`.

Decode failure does not affect boot because `loadChanges` never decodes `version_data`; the next
write or tombstone of that row classifies it as `PermanentSaveError` instead of silently resetting
causal history. Source: `app/lib/persistence/drift_ledger_store.dart` - `loadChanges`,
`_decodeVersion`, `_bumpedVersion`, `_tombstone`; `app/lib/persistence/mappers.dart` -
`versionFromRow`.

## Tombstones and load

A delete change never issues SQL `DELETE`; it sets `lifecycle = 3` (tombstoned) and bumps the
vector. The row stays in SQLite forever as the sync engine's future deletion record. `load()`
fetches `WHERE lifecycle != 3` from every table, maps via `toDomain()`, and rebuilds in the order
accounts, pockets, categories, entries, plans.

## Seeding

`seedIfFirstLaunch` is gated on `store_meta.has_seeded`, not database emptiness. It sets the flag,
enqueues the seed changes, and awaits `flushNow()`, with the flag update riding the same
transaction as the first flush so a crash before that save leaves the flag clear and reseeds
cleanly. See `ledger_runtime.md` §6 for the seed dataset.

## Known defects fixed in the port

- **`flushNow` early-return hole** — the port loops flush cycles until `pending` is empty instead
  of running one trailing flush that could early-return. Pinned by the required test
  `flushNowCoversBatchBufferedDuringInFlightSave` (`persistence.md` §8.1).
- **`failedWillRetry` scheduled nothing** — the port arms a timed retry at `retryBackoff` cadence
  that retries a normal flush cycle until success, keeping the banner `failedWillRetry` across
  failed timed cycles. Pinned by the required test
  `failedWillRetryEventuallyPersistsWhenStoreRecovers` (`persistence.md` §8.2).
- **Corrupt version vectors routed through the transient retry path** — `_decodeVersion` now
  classifies an undecodable `version_data` blob as `PermanentSaveError`; `_runCycle` reports
  `SaveBannerState.permanentlyFailed` and does not retry forever. Pinned by
  `a corrupt version vector reports the terminal state once`.
  (`drift_ledger_store.dart:_decodeVersion`, `_runCycle`;
  test `a corrupt version vector reports the terminal state once` in
  `drift_ledger_store_test.dart`; commit `2445ed2`)
- **`category_parent_id` is immutable on upsert** — an existing category's `parent_id` is never
  rewritten on upsert, matching Swift (parent fixed at creation). Pinned by the required test
  `categoryParentIDImmutableOnUpsert` (`persistence.md` §9).

## Requirements

- `flushNow` is a barrier: everything enqueued before the call is on disk when it returns.
  (`ledger_store.dart`, `drift_ledger_store.dart` §4.5)
- Batches ingest in call order; coalescing keeps only the last change per `targetID`.
  (`drift_ledger_store.dart` §4.1–4.3)
- Every applied write bumps the row's version vector exactly once. (`drift_ledger_store.dart` §4.6)
- Vector decode failure throws; merge is absent and reconciliation uses frontier reduction
  instead. (`packages/sync/lib/src/protocol/version_vector.dart` - `VersionVector`,
  `VersionVectorDecodeError`; `packages/sync/lib/src/engine/sync_engine.dart` -
  `SyncEngine._nonDominatedFrontier`)
- Seeding is gated on `has_seeded`, not emptiness, and commits the flag atomically with the seed.
  (`persistence.md` §7)
- Tombstones set `lifecycle = 3` and are hidden from `load()` but remain in SQLite.
  (`drift_ledger_store.dart` §5)
- An undecodable stored version vector reports `permanentlyFailed` once, arms no timed retry, and
  leaves its pending batch undrained. (tests `a corrupt version vector reports the terminal state
  once`, `the terminal save never drains the pending batch` in `drift_ledger_store_test.dart`)
- `BannerState` renders `permanentlyFailed` as `"Couldn't save changes"`.
  (`BannerState._saveMessage`; test `permanentlyFailedShowsExactSaveMessage` in
  `banner_state_test.dart`)
- Schema stays at version 4 with a purely additive v4 upgrade: no user-table DDL change, and
  pre-v4 rows survive unchanged. (`ledger_database.dart` - `LedgerDatabase.schemaVersion`,
  `LedgerDatabase._createSyncTables`; test `v3 to v4 upgrade preserves existing user data` in
  `sync_schema_migration_test.dart`)
- The five v4 sync-table creates share one transaction, so a mid-migration failure leaves no
  partial schema and the retry completes. (test `a mid-migration failure rolls back and the retry
  completes` in `sync_schema_migration_test.dart`)
- `sync_metadata.write_gate` defaults off (`DEFAULT 0`), so a fresh or migrated store never
  enables sync writes before enrollment. (`tables.dart` - `SyncMetadata`;
  `sync_schema_migration_test.dart` - test `upgraded payload columns reject null like a fresh
  database`)
- Sync cursors are opaque server-assigned strings, never version vectors; acknowledged vectors stay
  keyed by normalized `(collection, row_id)`. (`tables.dart` - `SyncWatermark`,
  `SyncAcknowledgedVector`; sibling entry `sync-durable-stores.md`)
