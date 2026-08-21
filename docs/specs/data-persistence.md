# data-persistence Specification

## Purpose

Governs the boundary between a `LedgerState` in memory and its stored form on disk: every value
that survives a round trip through storage must come back unchanged, and a state loaded from a
stored change stream must be as trustworthy as one built by mutators directly.

## Requirements

### Requirement: Enum codes round-trip

A value persisted through an int-coded enum SHALL decode back to the exact value it was encoded
from. A code with no known mapping SHALL raise a loud, catchable error rather than silently
substituting a different value of the same enum.

This applies to every int-coded enum the row mappers read and write, including account type.

#### Scenario: Every account type round-trips

- **WHEN** an account of any `AccountType` value is stored and reloaded
- **THEN** its type is unchanged

#### Scenario: An unrecognized code fails loudly

- **WHEN** a stored row carries a code with no defined mapping for its enum
- **THEN** loading raises an error naming the bad code rather than defaulting to a different value

### Requirement: Loaded state is validated

A `LedgerState` built by replaying a stored change stream SHALL be checked against the same
invariants a mutator-built state must satisfy before it becomes the app's live state. A stream
that produces a state violating an invariant SHALL raise a catchable, user-visible error rather
than loading silently.

This check SHALL run in release builds, not only in debug — a corrupt or truncated store is
exactly the situation a debug-only assertion cannot help with.

#### Scenario: A malformed change stream is rejected

- **WHEN** replaying a stored change stream produces a state that violates an invariant
- **THEN** loading raises an error instead of returning the broken state

#### Scenario: A well-formed change stream loads normally

- **WHEN** replaying a stored change stream produces a state satisfying every invariant
- **THEN** loading succeeds and returns that state

### Requirement: Row tables

Storage SHALL keep accounts, pockets, categories, entries and plans in their own tables, plus a
metadata table holding the device identity and the seeding flag.

A plan's entry template SHALL be flattened into columns on the plan row rather than stored as a
nested structure.

#### Scenario: Plan template is columnar

- **WHEN** a plan is stored
- **THEN** its template fields occupy columns on the plan row

### Requirement: Universal row columns

Every stored row SHALL carry an encoded version vector and a lifecycle code.

Money SHALL be stored as text, never as a floating-point column, so that stored amounts round-trip
exactly.

#### Scenario: Money round-trips exactly

- **WHEN** an amount with many decimal places is stored and reloaded
- **THEN** it is unchanged

### Requirement: Reserved columns

The schema SHALL reserve, from its first version, a note column on entries and a marker column
identifying system-generated entries. Neither is written by this change.

They are reserved because adding a column later costs a migration, while reserving one now costs
nothing.

#### Scenario: Reserved columns exist unused

- **WHEN** the first schema version is created
- **THEN** both reserved columns are present and unwritten

### Requirement: Version vectors

Each row SHALL carry a vector counting writes per device. Every applied write SHALL bump the
target row's vector exactly once — upserts and tombstones alike, since a deletion is a write that
must be orderable against others.

The vector SHALL support asking whether it dominates another and whether two are concurrent.
Merging SHALL NOT be implemented here; it belongs to the future sync engine.

Bumps SHALL happen inside the save transaction, so that a rolled-back save leaves the stored
vector untouched.

A version vector that fails to decode SHALL be an error, NOT an empty vector, at the point the row
is next written. An empty vector would silently erase a row's causal history, which becomes data
loss once changes are merged across devices. Loading a stored ledger SHALL NOT decode any row's
version vector; the check applies only when that row is next bumped. See ADR-0018.

#### Scenario: Tombstone bumps the vector

- **WHEN** a row is tombstoned
- **THEN** its version vector is bumped

#### Scenario: Rolled-back save leaves vectors alone

- **WHEN** a save fails and rolls back
- **THEN** stored vectors are unchanged, and the retry re-bumps from the stored value

#### Scenario: Corrupt version vector surfaces on next write

- **WHEN** a row's stored version vector cannot be decoded and that row is next upserted or
  tombstoned
- **THEN** the write fails loudly rather than resetting that row's history

#### Scenario: Loading does not touch version vectors

- **WHEN** a stored ledger is loaded
- **THEN** loading succeeds regardless of whether any row's version vector is corrupt

### Requirement: Ordered ingest

Batches SHALL be queued synchronously in arrival order, and drained into a pending buffer in that
same order. Two batches enqueued in sequence SHALL always be buffered in that sequence.

Order is what makes last-write-wins correct: without it, an older value could overwrite a newer
one.

#### Scenario: Rapid conflicting writes

- **WHEN** many conflicting upserts of the same row are enqueued in rapid succession
- **THEN** the last one is what ends up stored

### Requirement: Debounced saving

Each newly buffered batch SHALL cancel the pending debounce timer and start a fresh one. A save
SHALL run when a timer fires uncancelled.

A burst of edits therefore produces one save shortly after the last edit, rather than one save per
edit.

#### Scenario: Burst collapses to one save

- **WHEN** several edits are made in quick succession
- **THEN** one save runs after the last of them

### Requirement: Coalescing

At save time the pending buffer SHALL be reduced to the last change per target, preserving the
relative order of the survivors. Coalescing SHALL span everything currently pending, not just one
enqueued batch.

Upserts and deletions SHALL coalesce in the same keyspace: an upsert followed by a deletion of the
same id applies only the deletion, and a deletion followed by an upsert applies only the upsert.

Coalescing SHALL affect only what is applied; bookkeeping of how much has been handled SHALL count
raw changes.

#### Scenario: Upsert then delete

- **WHEN** a row is upserted and then deleted within one debounce window
- **THEN** only the deletion is applied

### Requirement: Transactional save with retry

A save SHALL apply its coalesced changes inside a single transaction. A failure SHALL roll back
entirely, leaving nothing partially applied.

On failure the save SHALL be retried a bounded number of times with a short backoff, reporting
that it is retrying. After the final failed attempt it SHALL report that it will retry later and
SHALL schedule a timed re-flush rather than waiting passively for the next mutation.

The pending batch SHALL never be dropped, however many attempts fail.

Only changes buffered before the save began SHALL be cleared on success; anything buffered during
the save SHALL remain for the next one.

At most one save SHALL run at a time; a save requested while one is in flight SHALL await it.

#### Scenario: Failed save keeps its data

- **WHEN** every attempt to save fails
- **THEN** the pending changes are still held and a later retry is scheduled

#### Scenario: Edits during a save survive

- **WHEN** an edit is made while a save is in flight
- **THEN** it is not cleared by that save's success and is written by the next one

### Requirement: Flush barrier

An explicit flush SHALL guarantee that everything enqueued before the call is on disk when it
returns.

It SHALL push a barrier through the same queue the batches ride, so that on resumption every
earlier batch is provably buffered. It SHALL cancel any armed debounce timer, await any in-flight
save, and then save repeatedly until nothing is pending.

The loop SHALL stop if a save cycle ends in a reported failure, so that a flush cannot spin
forever against a broken disk; the timed retry owns recovery from there.

A flush on an idle store SHALL return without touching the database and without reporting any
state.

#### Scenario: Backgrounding is durable

- **WHEN** the app backgrounds with a debounced batch still pending
- **THEN** the flush returns only once that batch is on disk

#### Scenario: Flush on an idle store

- **WHEN** nothing is pending and no save is in flight
- **THEN** the flush is a no-op

### Requirement: Save state reporting

The store SHALL report its save state so the app can surface it. A clear state SHALL be reported
only after a non-clear state, so that a healthy app never flashes a banner for a problem it never
had.

#### Scenario: No banner on a healthy save

- **WHEN** saves succeed from the start
- **THEN** no save state is ever reported

### Requirement: Tombstones and loading

A deletion SHALL never remove a row. It SHALL mark the row tombstoned and bump its version
vector, so the row remains as a deletion record for a future sync engine.

Loading SHALL return every row that is not tombstoned, and SHALL rebuild state by replaying
upserts. Archived and reference-only rows SHALL load normally — only tombstoned rows are
invisible.

Storage errors during a load SHALL propagate, so that startup can offer a retry.

#### Scenario: Deleted row is hidden but present

- **WHEN** an entry is deleted
- **THEN** a load no longer returns it, while the row remains in storage marked tombstoned

#### Scenario: Archived rows still load

- **WHEN** a holder is archived
- **THEN** it is still returned by a load
