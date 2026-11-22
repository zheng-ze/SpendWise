# Persistence

Last reconciled: 2026-11-22

## Feature overview

The durable layer: a `LedgerStore` contract backed by Drift (SQLite), an in-memory implementation
for tests, the ordered ingest pipeline with debounce and per-row coalescing, and the
domain-to-row mapping. Ledger rows mirror the domain models 1:1 and must never leak past the store.
Lives in `app/lib/persistence/`.

## Key files

- `app/lib/persistence/store/ledger_store.dart` - the `LedgerStore` abstract contract,
  `SaveBannerState` (`clear`, `retrying`, `failedWillRetry`), and `SaveErrorHandler`.
- `app/lib/persistence/store/drift_ledger_store.dart` - the Drift implementation: configuration
  constants, state fields, `start`, `enqueue`, `seedIfFirstLaunch`, `flushNow`. Split into parts:
  `drift_store_loading.dart` (`loadChanges`), `drift_store_scheduling.dart` (ingest, debounce, save
  cycle, retry), `drift_store_writes.dart` (row keys, coalescing, applying changes) and
  `store_failures.dart` (`PersistenceBarrierFailure`).
- `app/lib/boot/banner_state.dart` - the `SaveBannerState` consumer that maps `retrying` and
  `failedWillRetry` to banner messages.
- `app/lib/persistence/database/ledger_database.dart`, `ledger_database.g.dart`, `tables.dart` -
  schema and generated row models.
- `app/lib/persistence/mappers/mappers.dart` - domain to row mapping.
- `app/lib/persistence/database/database_connection.dart` - `openLedgerConnection`, which imports
  `database_connection_native.dart` directly (no conditional import; web support was dropped in
  commit `e7a963d`).
- `app/lib/persistence/database/database_connection_native.dart` - `openConnection`, which opens a
  `NativeDatabase` file under the app's documents directory on every supported platform (Android,
  iOS, macOS, Windows, Linux).
- `app/lib/persistence/store/persistence_processor.dart` - bus-to-store bridge (also
  `ledger_runtime.md`).

## Module interactions

`PersistenceProcessor` subscribes to the `EventBus` and forwards each `LedgerPublication` to
`store.enqueue` with the same batch boundaries and no filtering. `Ledger` publishes through the bus;
UI never touches it. `load()` rebuilds `LedgerState` via `LedgerState.replaying(changes)`, which
bypasses validation by design: it never calls the domain mutators, so no `LedgerError`, no invariant
sweep, no cascade runs (`persistence.md` §5). Replay is shared by `load()`, the in-memory double, and
seeding.

## `LedgerStore` contract

| Member | Contract |
|---|---|
| `load()` | Reads every row of every ledger table, maps to domain, rebuilds `LedgerState` by replay. Archived entry rows (lifecycle 1) replay into `binnedEntries`. Throws on failure, including an invariant violation in the stored rows. Boot-time only. |
| `seedIfFirstLaunch(changes)` | Does nothing when `store_meta.has_seeded` is set; otherwise enqueues the seed changes and awaits `flushNow()` with the flag riding the first save. |
| `start()` | Begins draining the ingest queue. Idempotent; safe to call from `flushNow`. |
| `enqueue(changes)` | Synchronous, non-blocking; empty list is a no-op; batches ingest in call order. |
| `flushNow()` | Barrier: everything enqueued before the call is on disk when it returns. Throws `PersistenceBarrierFailure` if a save cycle gives up with writes still pending. |
| `setErrorHandler(h)` | Registers the single banner callback; replaces it; no multicast. |
| `SaveBannerState` | `clear`, `retrying`, and `failedWillRetry`; the handler signature is `void Function(SaveBannerState)`. (`ledger_store.dart:SaveBannerState`, `SaveErrorHandler`) |

Ledger-row conventions (tables mixing in `LedgerRow` in `tables.dart`): `LedgerRow` holds only
`lifecycle`, an `INTEGER` raw value. IDs are lowercase `TEXT` PKs; money is `Decimal` `TEXT` (never
`REAL`); dates are epoch-millis UTC `INTEGER`; booleans are `INTEGER` 0/1. `store_meta` mixes in
nothing: it holds `id` (constrained to 0) and `has_seeded`. The `entries` table carries nullable
`note` (`TEXT`) and `system_kind` (`INTEGER`) columns alongside the other entry fields. `plans`
flattens the `EntryTemplate` into `template_*` scalar columns, including nullable `template_note`
(`TEXT`). `budgets` holds `id`, nullable `category_id` and `limit_amount` (`TEXT`, the budget's one
limit).

## Write pipeline

Constants: `debounce = 250 ms`, `maxRetries = 2`, `retryBackoff = 200 ms` (`drift_ledger_store.dart`).

1. **Ordered ingest** - `enqueue` appends each batch to an unbounded FIFO; two enqueues stay in
   sequence, which makes last-write-wins coalescing correct.
2. **Debounce** - each batch buffered into `pending` cancels the previous timer and starts a fresh
   250 ms one; a burst produces one save about 250 ms after the last edit.
3. **Coalescing** - at flush, keep only the last change per row key `(_RowKind, id)`, preserving
   survivor order. The row kinds are money sources (accounts and pockets share one kind), categories,
   entries, plans and budgets, and the id is lowercase-normalized. Upserts and deletes coalesce in
   the same keyspace, so `UpsertPocket` followed by `DeleteMoneySource` for one id applies only the
   deletion, while identical ids in different kinds stay independent. Coalescing spans everything in
   `pending`, not a single enqueue batch. (`drift_store_writes.dart:_rowKey`, `_coalesce`)
4. **Flush, retry, rollback** - one SQLite transaction applies the coalesced writes, plus the seed
   flag when seeding. A failed attempt retries up to `maxRetries` times, reporting `retrying` (except
   during a timed retry) and waiting `retryBackoff` between attempts. After the last attempt the
   cycle reports `failedWillRetry`, arms a timed retry and returns. Only a committed transaction
   removes its prefix from `pending`, so retries and later cycles recompute coalescing from the
   still-pending changes. A successful cycle reports `clear`, but only after a non-clear report.
   (`app/lib/persistence/store/drift_store_scheduling.dart:_runCycle`)
5. **`flushNow` barrier** - calls `start()` defensively, pushes a barrier, cancels the debounce
   timer, awaits any in-flight flush, then loops flush cycles until `pending` is empty. A cycle that
   gives up makes `flushNow` throw `PersistenceBarrierFailure` carrying the last failure.
   (`drift_ledger_store.dart:flushNow`, `drift_store_scheduling.dart:_runCycle`)

## Deleting rows and load

A delete change issues a SQL `DELETE` by id and the row is gone. `DeleteMoneySource` deletes from
`accounts` first and, when no account row matched, from `sub_pockets`. `load()` reads every row from
every table with `SELECT *`, maps each via the row mappers, and rebuilds in the order accounts,
pockets, categories, entries, plans, budgets (`drift_store_loading.dart:loadChanges`).

## Archived entries

Archiving an entry publishes `UpsertEntry` with lifecycle 1. The store writes it like any other
upsert. Restoring writes lifecycle 0 the same way, and purging deletes the row as described above.
`entries.lifecycle` already exists and the mappers round-trip it. `load()` selects every row, so
archived rows come back, and `LedgerState.replaying` routes them into `binnedEntries` and rejects any
other non-active lifecycle on a live entry. A corrupt stored row fails the invariant sweep, and boot
shows "Couldn't load your data" with Retry.

Downgrading the app while binned entries exist is unsupported: an older build replays lifecycle 1
rows into `entries`, fails the invariant sweep at boot, and cannot start until the app is upgraded
again. (`app/lib/persistence/store/drift_store_loading.dart:loadChanges`,
`app/lib/persistence/mappers/mappers.dart:entryToRow`; tests
`anArchivedEntryPersistsAsLifecycleOneAndReloadsIntoTheBin`,
`restoringAnArchivedEntryPersistsLifecycleZero`, `purgingAnArchivedEntryRemovesTheRow` in
`drift_ledger_store_test.dart`)

## Entry note and complete entries-row writes

`Entry.note` (`packages/domain/lib/src/entries/entry.dart`) is an optional trimmed string: the
constructor trims the input and maps null and the empty result to null, so a stored note is always
its own trim. `entryFromRow` maps `row.note` into `Entry` and `entryToRow` maps `entry.note` back
(`app/lib/persistence/mappers/mappers_entries.dart`). A row with SQL `NULL` loads as no note with
every other field unchanged, and a whitespace-only note stores as SQL `NULL`.

Every `UpsertEntry` writes the complete mapped entries row through
`entryToRow(entry).toCompanion(false)` (`app/lib/persistence/store/drift_store_writes.dart`). Present
nullable companion values make a null `category_id`, `destination_id`, `note` or `system_kind` clear
its SQL column on conflict updates. Other tables keep their current insertable and null-omission
behavior. (tests `entry note persistence` in `drift_ledger_store_test.dart`, noted and absent-note
mapping tests in `mappers_test.dart`)

## Plan template note

`EntryTemplate.note` is an optional trimmed string normalized at construction like `Entry.note`.
`planFromRow` maps `row.templateNote` into the template and `planToRow` maps `plan.template.note`
back (`app/lib/persistence/mappers/mappers_plans_budgets.dart`). `plans.template_note` is a nullable
column. The Drift row models are regenerated through `build_runner`, never edited by hand.

Every `UpsertPlan` writes through
`planToRow(plan).toCompanion(true).copyWith(templateNote: Value(plan.template.note))`
(`app/lib/persistence/store/drift_store_writes.dart`). Only the `template_note` value is explicitly
present, so a null or whitespace-only note clears its SQL column on conflict updates while other
nullable plan columns keep their omission behavior. (tests `plan note persistence` in
`drift_ledger_store_test.dart`, noted and absent-note plan mapping tests in `mappers_test.dart`)

## Single budget limit

A `Budget` has one `Decimal limit`. The `budgets` table stores `id`, `category_id` (nullable) and
`limit_amount` `TEXT`; the column name avoids the SQL keyword `LIMIT`. `budgetFromRow` parses
`row.limitAmount` with `Decimal.parse` and `budgetToRow` writes `limit.toString()`
(`app/lib/persistence/mappers/mappers_plans_budgets.dart`). (tests in `schema_test.dart`)

## Schema reset

`schemaVersion` is a fresh `9` (`_freshSchemaVersion` in
`app/lib/persistence/database/ledger_database.dart`). The tables are `accounts`, `sub_pockets`,
`categories`, `entries`, `plans`, `budgets` and `store_meta`. A new database runs `createAll`. An
upgrade from any version below 9 does not migrate: `onUpgrade` lists every table in `sqlite_master`
(excluding `sqlite_%`), runs `DROP TABLE IF EXISTS` on each, and calls `createAll`, so the old data
is discarded and the app seeds again on first launch because `store_meta` is recreated empty. Row
models are regenerated through `build_runner`, never edited by hand. (tests in `schema_reset_test.dart`
and `schema_test.dart`)

## Seeding

`seedIfFirstLaunch` is gated on `store_meta.has_seeded`, not database emptiness. It sets the flag,
enqueues the seed changes, and awaits `flushNow()`, with the flag update riding the same transaction
as the first flush so a crash before that save leaves the flag clear and reseeds cleanly. See
`ledger_runtime.md` §6 for the seed dataset.

## Known defects fixed in the port

- **`flushNow` early-return hole** - the port loops flush cycles until `pending` is empty instead of
  running one trailing flush that could early-return. Pinned by the required test
  `flushNowCoversBatchBufferedDuringInFlightSave` (`persistence.md` §8.1).
- **`failedWillRetry` scheduled nothing** - the port arms a timed retry at `retryBackoff` cadence
  that retries a normal flush cycle until success, keeping the banner `failedWillRetry` across
  failed timed cycles. Pinned by the required test
  `failedWillRetryEventuallyPersistsWhenStoreRecovers` (`persistence.md` §8.2).
- **`category_parent_id` is immutable on upsert** - an existing category's `parent_id` is never
  rewritten on upsert, matching Swift (parent fixed at creation). Pinned by the required test
  `categoryParentIDImmutableOnUpsert` (`persistence.md` §9).

## Requirements

- `flushNow` is a barrier: everything enqueued before the call is on disk when it returns.
  (`ledger_store.dart`, `drift_ledger_store.dart` §4.5)
- Batches ingest in call order; coalescing keeps only the last change per row key `(_RowKind, id)`.
  (`drift_store_writes.dart:_coalesce`)
- Seeding is gated on `has_seeded`, not emptiness, and commits the flag atomically with the seed.
  (`persistence.md` §7)
- Deletes remove the row from SQLite and `load()` reads every remaining row.
  (`drift_store_writes.dart:_apply`, `drift_store_loading.dart:loadChanges`)
- Archived entries persist as `lifecycle = 1` and reload into `binnedEntries`; restore persists
  `lifecycle = 0`; purge deletes the row. (`drift_store_loading.dart:loadChanges`)
- A save that fails every attempt reports `failedWillRetry`, arms a timed retry, and leaves its
  pending batch undrained until a cycle commits; `flushNow` then throws
  `PersistenceBarrierFailure`. (`drift_store_scheduling.dart:_runCycle`)
- An upgrade from any schema below 9 drops every table and recreates the fresh schema.
  (`ledger_database.dart:migration`; tests in `schema_reset_test.dart`)
