# Persistence

Last reconciled: 9066882

## Feature overview

The durable layer: a `LedgerStore` contract backed by Drift (SQLite), an in-memory implementation
for tests, the ordered ingest pipeline with debounce and coalescing, the version vector codec, and
the domain-to-row mapping. Ledger rows mirror the domain models 1:1 and must never leak past the
store. Sync-coordination state lives separately in `app/lib/sync/` (see `sync-durable-stores.md`).
Lives in `app/lib/persistence/`.

## Key files

- `app/lib/persistence/ledger_store.dart` — the `LedgerStore` abstract contract,
  `SaveBannerState` (including `permanentlyFailed`), and `SaveErrorHandler`.
- `app/lib/persistence/drift_ledger_store.dart` — the Drift implementation of the pipeline and
  `PermanentSaveError` classification for undecodable stored version vectors.
- `app/lib/boot/banner_state.dart` — the `SaveBannerState` consumer that maps
  `permanentlyFailed` to `"Couldn't save changes"`.
- `app/lib/persistence/ledger_database.dart`, `ledger_database.g.dart`, `tables.dart` — schema and
  generated row models.
- `app/lib/persistence/mappers.dart` — domain ↔ row mapping.
- `app/lib/persistence/version_vector.dart` — `VersionVector` and its JSON codec.
- `app/lib/persistence/database_connection.dart` — `openLedgerConnection`, which imports
  `database_connection_native.dart` directly (no conditional import; web support was dropped in
  commit `e7a963d`).
- `app/lib/persistence/database_connection_native.dart` — `openConnection`, which opens a
  `NativeDatabase` file under the app's documents directory on every supported platform (Android,
  iOS, macOS, Windows, Linux).
- `app/lib/persistence/persistence_processor.dart` — bus-to-store bridge (also `ledger_runtime.md`).

## Module interactions

`PersistenceProcessor` subscribes to the `EventBus` and forwards each `LedgerPublication` with
the same batch boundaries and no filtering: unstamped publications (including an empty stamps
map) go to `store.enqueue`, stamped ones to `store.enqueueStamped`. `Ledger` publishes through the bus; UI never touches
it. `load()` rebuilds `LedgerState` via `LedgerState.replaying(changes)`, which bypasses validation
by design — it never calls the domain mutators, so no `LedgerError`, no invariant sweep, no cascade
runs (`persistence.md` §5). Replay is shared by `load()`, the in-memory double, and seeding.
Stamped publications carry one `VersionVector` per `SyncRowID`; the store pairs each change with
its stamp at the ingest boundary and carries the pairs through the whole pipeline below.

## `LedgerStore` contract

| Member | Contract |
|---|---|
| `load()` | Reads all non-tombstoned rows, maps to domain, rebuilds `LedgerState` by replay. Throws on failure. Boot-time only. |
| `start()` | Begins draining the ingest queue. Idempotent; safe to call from `flushNow`. |
| `enqueue(changes)` | Synchronous, non-blocking; empty list is a no-op; batches ingest in call order. |
| `enqueueStamped(changes, stamps)` | Stamped variant of `enqueue` for sync publications; each change pairs with the stamp keyed by its `SyncRowID` (`collectionFor` plus `targetID`), or no stamp when the map has none for it. Unstamped publications (including an empty stamps map) keep the `enqueue` bump path. |
| `flushNow()` | Barrier: everything enqueued before the call is on disk when it returns. |
| `setErrorHandler(h)` | Registers the single banner callback; replaces it; no multicast. |
| `SaveBannerState` | `clear`, `retrying`, `failedWillRetry`, and `permanentlyFailed`; the handler signature remains `void Function(SaveBannerState)`. (`ledger_store.dart:SaveBannerState`, `SaveErrorHandler`) |

Ledger-row conventions (tables mixing in `SyncedRow` in `tables.dart`): IDs are lowercase
`TEXT` PKs; money is `Decimal` `TEXT` (never `REAL`); dates are epoch-millis UTC `INTEGER`;
booleans are `INTEGER` 0/1; `version_data` is a `BLOB` JSON vector and `lifecycle` is an `INTEGER`
raw value on every such table (`store_meta` mixes in nothing and carries neither). Sync-coordination
tables in `app/lib/sync/sync_tables.dart` follow their own keys; their table doc comments own that
schema. The `entries` table reserves `note` and `system_kind` columns (day-one reservations,
unused in V1). `plans` flattens the `EntryTemplate` into `template_*` scalar columns.

## Write pipeline

Constants: `debounce = 250 ms`, `maxRetries = 2`, `retryBackoff = 200 ms` (`drift_ledger_store.dart`).

1. **Ordered ingest** — `enqueue` appends unstamped pairs to an unbounded FIFO; `enqueueStamped`
   appends ordered change-plus-optional-stamp pairs; two enqueues stay in sequence,
   which makes last-write-wins coalescing correct.
2. **Debounce** — each batch buffered into `pending` cancels the previous timer and starts a fresh
   250 ms one; a burst produces one save ~250 ms after the last edit.
3. **Coalescing** — at flush, keep only the last change per `SyncRowID`, preserving survivor order;
   upserts and deletes coalesce in the same keyspace, so `UpsertPocket` followed by
   `DeleteMoneySource` for one id applies only the deletion, while identical ids in different
   collections stay independent. Every observed stamp contributes to the row's carried pointwise
   maximum independently of which occurrence survives. Coalescing spans everything in `pending`, not
   a single enqueue batch.
4. **Flush, retry, rollback** — one SQLite transaction applies the coalesced writes. A stamped
   survivor writes its stamp verbatim and never takes a local bump; an unstamped survivor writes
   `max(carriedStamp, storedVector).bump(deviceID)`, so a local edit coalesced after a stamped
   remote strictly dominates every carried stamp, while a stamped remote arriving last keeps its
   surviving stamp verbatim. A null carried floor keeps the existing local bump path bit-for-bit.
   Non-terminal failures retry with `retrying`, then report
   `failedWillRetry` and arm a timed retry; `PermanentSaveError` reports `permanentlyFailed` and
   returns without arming one. Retries and later partial-prefix cycles recompute coalescing from
   the still-pending pairs, so stamp provenance survives them.
   (`app/lib/persistence/drift_ledger_store.dart:_runCycle`)
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

`VersionVector` (`version_vector.dart`) holds `Map<String, int>` device→counters with `bump`,
`dominates`, and `isConcurrent`. Merge is deliberately absent — deferred to the future sync
engine — so the store computes the carried pointwise maximum itself from the public `counters`
view (`drift_ledger_store.dart:_pointwiseMax`). Every applied unstamped write, upsert or tombstone, bumps the row's vector once with this device's
`device_id` (a uuid v4 created once in `store_meta`, never changing). A stamped survivor writes
its stamp verbatim with no bump. Encode is a normalized JSON
object; decode recognizes both the normalized object form and the Swift alternating-array form.
Decode failure does not affect boot because `loadChanges` never decodes `version_data`; the next
unstamped write or tombstone of that row classifies it as `PermanentSaveError` instead of silently resetting
causal history, while a stamped survivor bypasses that decode and overwrites a corrupt stored
vector with its verbatim stamp. (`app/lib/persistence/drift_ledger_store.dart:loadChanges`, `_decodeVersion`,
`_bumpedVersion`, `_tombstone`; commit `2445ed2`)

## Tombstones and load

A delete change never issues SQL `DELETE`; it sets `lifecycle = 3` (tombstoned) and advances the
vector — a bump for an unstamped delete, the verbatim stamp for a stamped one. The row stays in SQLite forever as the sync engine's future deletion record. `load()`
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
- Batches ingest in call order; coalescing keeps only the last change per `SyncRowID`, carrying
  the pointwise maximum of every observed stamp for the row.
  (`drift_ledger_store.dart` §4.1–4.3)
- Every applied unstamped write bumps the row's version vector exactly once; a stamped survivor
  writes its stamp verbatim with no bump. (`drift_ledger_store.dart` §4.6)
- Vector decode failure throws; merge is absent. (`version_vector.dart`)
- Seeding is gated on `has_seeded`, not emptiness, and commits the flag atomically with the seed.
  (`persistence.md` §7)
- Tombstones set `lifecycle = 3` and are hidden from `load()` but remain in SQLite.
  (`drift_ledger_store.dart` §5)
- An undecodable stored version vector on an unstamped write reports `permanentlyFailed` once, arms no timed retry, and
  leaves its pending batch undrained. A stamped survivor bypasses the decode. (tests `a corrupt version vector reports the terminal state
  once`, `the terminal save never drains the pending batch` in `drift_ledger_store_test.dart`)
- `BannerState` renders `permanentlyFailed` as `"Couldn't save changes"`.
  (`BannerState._saveMessage`; test `permanentlyFailedShowsExactSaveMessage` in
  `banner_state_test.dart`)
