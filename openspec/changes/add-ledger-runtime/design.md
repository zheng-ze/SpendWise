# Design — ledger runtime

## Layout

`app/lib/ledger/` holds `Ledger`, `EventBus`, `AnalysisCache`. `app/lib/persistence/` holds the
`LedgerStore` contract, `InMemoryLedgerStore` and `PersistenceProcessor` — the Drift implementation
arrives in Phase 4 behind the same contract. `app/lib/boot/` holds the phase machine, seeding and
banner state.

`packages/domain/` gains nothing. Everything here is Flutter-side by definition, and the domain's
purity is what keeps it testable.

## Decisions

### The bus is a synchronous broadcast stream

Swift needed a mutex-protected map of continuations with unbounded buffers to defeat Task
reordering — two rapid publishes could otherwise reach persistence out of order and apply an old
upsert over a new one. Dart's single-threaded event loop gives ordering for free, and
`sync: true` makes delivery happen inside `publish`, matching Swift's synchronous yield.

**Accepted difference:** Swift buffered between `subscribe()` and the first `await`; a Dart broadcast
stream delivers only to attached listeners. The lossless-before-consumption property only ever
mattered for Swift's `for await` startup latency, which Dart does not have. What replaces it is the
boot order — every runtime subscriber attaches before the `Ledger` exists, so there is no window in
which a batch can be published unheard.

### Sync delivery creates a reentrancy hazard

With `sync: true` a subscriber's handler runs inside `mutate`. A handler that mutated would reenter
a mutation in progress; Dart's sync controller throws on reentrant `add` anyway. Neither ported
subscriber does this — handlers enqueue or bump a counter and nothing else. Stated in the spec so it
stays that way.

### The isolate copy is the snapshot

Swift got a free snapshot: `LedgerState` is a struct, so the detached task computed on a value copy.
Dart's `LedgerState` is a mutable class, so a naive off-main compute would read state a concurrent
mutation is editing.

`Isolate.run` deep-copies the captured state on send — that copy *is* the snapshot. A mutation
landing mid-compute cannot corrupt the computation; its batch bumps the revision, and the follow-up
refresh recomputes while the generation guard discards the overtaken result.

Web has no isolates, so it computes synchronously. That is still a consistent snapshot: nothing can
interleave within a synchronous call on a single-threaded runtime, and the guard then trivially
passes. Gate on the platform behind an injected runner so tests can force either path.

### The generation guard claims before computing

`lastComputed = target` is assigned synchronously *before* the async compute starts. Claiming after
would let a re-entrant refresh start a second compute for the same generation. The initial values are
deliberately mismatched (`revision = 0`, `lastComputed = -1`) so the first refresh computes even
though no bus event has arrived — that is how boot-loaded state gets its first analysis pass.

### Plans resolve on entering ready — a flagged deviation

iOS fires an initial activation that races the async boot and is usually swallowed by the ready
guard, so V1 frequently did *not* resolve plans on a cold start; occurrences materialized on the next
foregrounding. Flutter does not fire a resume for the initial launch at all.

Resolving once explicitly on entering ready fixes that latent race. Strictly more reliable than the
Swift behavior, and deliberate rather than incidental.

### Resolution always uses a fixed UTC calendar

Never the device calendar — at boot, on resume, or after creating a plan from the entry form. A
device-local calendar would re-create exactly the timezone-dependent occurrence ids the domain's
UUIDv5 decision exists to eliminate.

## Test approach

`EventDrivenTests` is the parity target for the bus and processor. The ordering guarantee is pinned
by publishing two batches at the same target and asserting the later one wins downstream —
`laterUpsertWinsWhenBatchesArriveInOrder` is the Swift test that exists for this reason.

The cache's guard needs interleaving tests, not just unit tests: a compute in flight when a newer
refresh claims a higher generation must have its result discarded, and the items counter must not
move. Force both compute paths through the injected runner.

Mutation-test the pipeline order in `mutate`: publish before committing state, or notify before
publishing, and confirm a test dies. Restore from a file copy, not `git checkout`.
