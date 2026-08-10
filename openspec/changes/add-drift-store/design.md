# Design — Drift store

## Layout

`app/lib/persistence/` gains the schema, the mappers, `DriftLedgerStore` and `VersionVector`, all
behind the `LedgerStore` contract added in Phase 3. `InMemoryLedgerStore` stays — it is the double the
runtime tests use, and keeping both honest against one contract is what makes those tests meaningful.

Replay is the exception: it lands in `packages/domain/` on `LedgerState`, because three consumers need
it (`load()`, the in-memory store, and seeding) and duplicating it would let them drift apart. It is
pure Dart with no storage dependency, so the domain's purity holds.

## Decisions

### The row model is not the domain model

The tables mirror the SwiftData rows one-for-one, not the Dart domain types. They are a separate model
with its own shape — flattened plan templates, integer lifecycle codes, text money, an encoded version
vector blob. The mappers are the only place the two meet.

This is what keeps `packages/domain/` free of persistence concerns, and it is why the schema can carry
sync machinery the domain knows nothing about.

### A failed vector decode is an error — corrected from Swift

Swift's mapper decoded a version vector with `?? VersionVector()`, so a corrupt blob silently became an
empty vector. That reads as harmless today, because nothing consumes vectors yet.

It is not harmless. An empty vector claims the row has no write history, so once the sync engine
exists that row loses every causal relationship it had and merges as though it were brand new — silent
data loss, discoverable only after the fact. Unknown *enum* codes still fall back to defaults, since a
forward-compatible enum is a real scenario and the fallback is lossless. A corrupt vector is not.

### `flushNow` loops — corrected from Swift

Swift ran a single trailing flush that could early-return while the buffer still held work, so a
backgrounding app could return from its durability barrier with data unwritten. The port loops until
pending is empty.

The loop terminates on a reported failure rather than spinning against a broken disk; the timed retry
owns recovery from there. Without that exit the barrier would hang the backgrounding path.

### A reported failure schedules its own retry — corrected from Swift

Swift reported `failedWillRetry` and then waited passively for the next mutation to trigger another
attempt. An app that fails to save and is then left alone never retries — the data sits in memory until
the process dies.

The port schedules a timed re-flush when it reports the failure.

### `clear` is reported only after a non-clear state — corrected from Swift

Reporting `clear` unconditionally makes a healthy app emit banner-state transitions for a problem it
never had. The store tracks whether it has reported a non-clear state and stays silent otherwise.

### Saves are serialized

At most one save cycle runs at a time, and a requested save awaits an in-flight one. This matters even
on a single-threaded runtime: the save and the backoff sleep are both awaits, so a debounced save and
an explicit flush can otherwise interleave and apply the same pending prefix twice.

### Coalescing counts differ deliberately

What gets *applied* is the coalesced list; what gets *cleared from pending* is the raw pre-coalesce
count. Conflating them would either drop changes buffered during the save or re-apply ones already
written.

### Replay bypasses validation, by design

Replay writes straight into the state's maps — no mutators, no validation, no cascades, no invariant
sweep. The data was validated when it was first produced, and re-validating on every load would risk
rejecting legitimately stored data on a future validation tightening.

The load-bearing consequence: replaying a pocket deletion does not unlink it from its parent, because
the original mutation emitted the parent's upsert into the same stream. Replay trusts the stream to be
complete. A debug build may sweep invariants once after boot — that is the runtime's call, not the
store's, and it is the check that would catch a stream that was *not* complete.

## Test approach

`PersistenceTests` is the parity target, run against real in-memory SQLite rather than a fake — the
transaction and rollback behavior is the thing under test, and a fake would not have it.

The four corrected behaviors each need a test that would fail against the Swift semantics: a corrupt
vector blob raising rather than emptying, a `flushNow` that returns with a non-empty buffer, a reported
failure with no subsequent mutation still retrying, and a healthy run reporting no banner state at all.

Round-trip is the schema's real test: build a state through the mutation API, store it, load it, and
compare. Mutation-test the coalescing keyspace by making deletions coalesce into a separate keyspace
from upserts and confirming the upsert-then-delete test dies.
