# Persistence

Last reconciled: b1edf90

## Feature overview

The durable layer: a `LedgerStore` contract backed by Drift (SQLite), an in-memory implementation
for tests, the ordered ingest pipeline with debounce and coalescing, the version vector codec, and
the domain-to-row mapping. Rows mirror the domain models 1:1 and must never leak past the store.
Lives in `app/lib/persistence/`.

## Key files

- `app/lib/persistence/ledger_store.dart` — the `LedgerStore` abstract contract and
  `SaveBannerState`.
- `app/lib/persistence/drift_ledger_store.dart` — the Drift implementation of the pipeline.
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

Schema conventions: IDs are lowercase `TEXT` PKs; money is `Decimal` `TEXT` (never `REAL`); dates
are epoch-millis UTC `INTEGER`; booleans are `INTEGER` 0/1; `version_data` is a `BLOB` JSON vector
on every table except `store_meta`; `lifecycle` is an `INTEGER` raw value on every table except
`store_meta`. The `entries` table reserves `note` and `system_kind` columns (day-one reservations,
unused in V1). `plans` flattens the `EntryTemplate` into `template_*` scalar columns.

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
   bump per applied change; on failure the transaction rolls back, and if attempts remain it reports
   `retrying`, waits 200 ms, and re-reads `pending`; after the final failure it reports
   `failedWillRetry` and schedules a timed retry. The batch is never dropped.
5. **`flushNow` barrier** — calls `start()` defensively, pushes a barrier, cancels the debounce
   timer, awaits any in-flight flush, then loops flush cycles until `pending` is empty (or a cycle
   ends in `failedWillRetry`).

## Version vector

`VersionVector` (`version_vector.dart`) holds `Map<String, int>` device→counters with `bump`,
`dominates`, and `isConcurrent`. Merge is deliberately absent — deferred to the future sync
engine. Every applied write, upsert or tombstone, bumps the row's vector once with this device's
`device_id` (a uuid v4 created once in `store_meta`, never changing). Encode is a normalized JSON
object; decode recognizes both the normalized object form and the Swift alternating-array form.
Decode failure throws (a load error surfaces on the next write to that row, not at boot) — a
sanctioned deviation from Swift's decode-or-empty, which would silently reset causal history.

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
- **Permanent failures routed through the transient retry path** — deferred past MVP: the catch-all
  treats a corrupt `version_data` blob as transient, retrying forever behind a banner. The only
  reachable permanent error today. (`persistence.md` §8.3)
- **`category_parent_id` is immutable on upsert** — an existing category's `parent_id` is never
  rewritten on upsert, matching Swift (parent fixed at creation). Pinned by the required test
  `categoryParentIDImmutableOnUpsert` (`persistence.md` §9).

## Requirements

- `flushNow` is a barrier: everything enqueued before the call is on disk when it returns.
  (`ledger_store.dart`, `drift_ledger_store.dart` §4.5)
- Batches ingest in call order; coalescing keeps only the last change per `targetID`.
  (`drift_ledger_store.dart` §4.1–4.3)
- Every applied write bumps the row's version vector exactly once. (`drift_ledger_store.dart` §4.6)
- Vector decode failure throws; merge is absent. (`version_vector.dart`)
- Seeding is gated on `has_seeded`, not emptiness, and commits the flag atomically with the seed.
  (`persistence.md` §7)
- Tombstones set `lifecycle = 3` and are hidden from `load()` but remain in SQLite.
  (`drift_ledger_store.dart` §5)
