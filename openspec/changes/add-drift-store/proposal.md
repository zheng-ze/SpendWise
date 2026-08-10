# Add the Drift store

## Why

Phase 3 gives the app a store *contract* and an in-memory double, which is enough to test the runtime
but loses everything the moment the process dies. Nothing survives a restart.

This is Phase 4, and it is the last layer beneath the UI. It also carries the decisions that are
expensive to revisit later: a schema shipped without its reserved columns costs a migration, and a
version vector that silently resets destroys causal history the future sync engine depends on.

## What Changes

- Add the Drift schema, mirroring the SwiftData rows one-for-one — `accounts`, `sub_pockets`,
  `categories`, `entries`, `plans` (with the entry template flattened into columns), and `store_meta`.
  Every row carries an encoded version vector and a lifecycle code; money columns are text.
- Reserve two columns on day one, free now and a migration later: an entry note (the locked V2
  prerequisite the split wizard writes into) and the system-entry marker.
- Add the domain-to-row mappers in both directions.
- Add `DriftLedgerStore` behind the existing `LedgerStore` contract: ordered FIFO ingest, a 250 ms
  debounce, last-write-wins coalescing per target, and a save that applies inside one transaction.
- Add the retry policy — two retries at 200 ms backoff, then a reported failure and a **timed**
  re-flush, with the pending batch never dropped.
- Add the `flushNow` barrier: everything enqueued before the call is on disk when it returns.
- Add `load()`, which skips tombstoned rows and rebuilds state by replaying upserts.
- Add `VersionVector` with bump, dominates and concurrency comparison. Merge stays deferred to the
  sync engine.
- Port `PersistenceTests` against a real in-memory SQLite database.

Not **BREAKING**: the store slots in behind the Phase 3 contract. `InMemoryLedgerStore` stays as the
test double.

## Capabilities

### New Capabilities

- `persistence-schema`: the stored row shape, its reserved columns, the domain-to-row mapping, and the
  decode fallback policy.
- `ledger-persistence`: the write pipeline — ingest, debounce, coalescing, transactional save, retry,
  the flush barrier — plus load, replay and tombstone semantics.

### Modified Capabilities

None. The `LedgerStore` contract added in `add-ledger-runtime` is implemented, not changed.

## Impact

- New code in `app/lib/persistence/`: schema, mappers, `DriftLedgerStore`, `VersionVector`.
- New tests in `app/test/persistence/`, running against in-memory SQLite.
- New dependencies on `app/`: `drift`, `sqlite3_flutter_libs`, `path_provider`, and `drift_dev` plus
  `build_runner` as dev dependencies.
- `packages/domain/` unchanged. The persistence row model is deliberately distinct from the domain
  model, so the domain never learns about storage.
- Four spots where a straight translation of the Swift would be wrong (`design.md`): the
  version-vector decode fallback, the `flushNow` early-return hole, the passive wait after a reported
  failure, and the `clear` banner state being reported before anything went wrong.
