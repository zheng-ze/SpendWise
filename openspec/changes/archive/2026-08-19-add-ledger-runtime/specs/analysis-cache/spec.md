# analysis-cache Specification

## Purpose
Defines the cached analysis pass that stats surfaces read, so that a full-ledger classification scan
does not run per frame.

The cache is driven by the event bus rather than polled, and guards against an older computation
overwriting a newer one.

## ADDED Requirements
### Requirement: Bus-driven invalidation

The cache SHALL increment an input counter once per delivered batch — counting batches, not the
changes within them. Subscribing SHALL be idempotent: starting the cache twice SHALL still produce
one increment per batch.

The cache SHALL release its subscription when disposed.

#### Scenario: One batch, one increment

- **WHEN** a batch containing several changes is delivered
- **THEN** the input counter rises by exactly one

#### Scenario: Starting twice

- **WHEN** the cache is started a second time
- **THEN** it does not subscribe twice, and batches are still counted once each

### Requirement: Refresh generation guard

A refresh SHALL do nothing when no new batch has arrived since the last refresh began. Otherwise it
SHALL claim the current counter value **before** starting the computation, so that refreshes
re-entered during an in-flight computation are no-ops unless new input arrived.

When a computation finishes, its result SHALL be discarded if a newer refresh has since claimed a
higher generation. Cached items SHALL therefore only ever move forward.

The items counter SHALL increment only when a result is accepted, never when one is discarded.

#### Scenario: No input, no work

- **WHEN** refresh is called twice with no batch in between
- **THEN** the computation runs once

#### Scenario: Overtaken result is discarded

- **WHEN** a computation completes after a newer refresh has claimed a higher generation
- **THEN** its result is thrown away and the items counter does not move

#### Scenario: First refresh always computes

- **WHEN** the cache refreshes for the first time, before any batch has arrived
- **THEN** it still computes, so state loaded at boot gets an initial analysis pass

### Requirement: Snapshot isolation of the computation

The computation SHALL operate on a consistent snapshot of ledger state, so that a mutation landing
mid-computation cannot corrupt the result.

Where the platform provides isolates, the computation SHALL run off the main thread and the snapshot
SHALL be the copy the isolate receives. Where it does not, the computation SHALL run synchronously,
which is itself consistent because nothing can interleave within a synchronous call.

Cache fields SHALL be touched only from the main event loop; the off-main computation SHALL receive a
copy and return a value, never share the cache.

#### Scenario: Mutation during computation

- **WHEN** the ledger is mutated while a computation is in flight
- **THEN** the in-flight computation is unaffected, and the resulting batch triggers a later refresh
