# ledger-persistence Specification

## Purpose
Defines how committed changes reach disk and how stored data comes back: the queue that preserves
order, the debounce that batches a burst into one save, the transaction that makes a save all-or-
nothing, and the retry that survives a failing disk.

The durability contract is the point of the layer — a user who backgrounds the app must not lose the
edit they just made.

## ADDED Requirements
### Requirement: Ordered ingest

Batches SHALL be queued synchronously in arrival order, and drained into a pending buffer in that same
order. Two batches enqueued in sequence SHALL always be buffered in that sequence.

Order is what makes last-write-wins correct: without it, an older value could overwrite a newer one.

#### Scenario: Rapid conflicting writes

- **WHEN** many conflicting upserts of the same row are enqueued in rapid succession
- **THEN** the last one is what ends up stored

### Requirement: Debounced saving

Each newly buffered batch SHALL cancel the pending debounce timer and start a fresh one. A save SHALL
run when a timer fires uncancelled.

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

Coalescing SHALL affect only what is applied; bookkeeping of how much has been handled SHALL count raw
changes.

#### Scenario: Upsert then delete

- **WHEN** a row is upserted and then deleted within one debounce window
- **THEN** only the deletion is applied

### Requirement: Transactional save with retry

A save SHALL apply its coalesced changes inside a single transaction. A failure SHALL roll back
entirely, leaving nothing partially applied.

On failure the save SHALL be retried a bounded number of times with a short backoff, reporting that it
is retrying. After the final failed attempt it SHALL report that it will retry later and SHALL
schedule a timed re-flush rather than waiting passively for the next mutation.

The pending batch SHALL never be dropped, however many attempts fail.

Only changes buffered before the save began SHALL be cleared on success; anything buffered during the
save SHALL remain for the next one.

At most one save SHALL run at a time; a save requested while one is in flight SHALL await it.

#### Scenario: Failed save keeps its data

- **WHEN** every attempt to save fails
- **THEN** the pending changes are still held and a later retry is scheduled

#### Scenario: Edits during a save survive

- **WHEN** an edit is made while a save is in flight
- **THEN** it is not cleared by that save's success and is written by the next one

### Requirement: Flush barrier

An explicit flush SHALL guarantee that everything enqueued before the call is on disk when it returns.

It SHALL push a barrier through the same queue the batches ride, so that on resumption every earlier
batch is provably buffered. It SHALL cancel any armed debounce timer, await any in-flight save, and
then save repeatedly until nothing is pending.

The loop SHALL stop if a save cycle ends in a reported failure, so that a flush cannot spin forever
against a broken disk; the timed retry owns recovery from there.

A flush on an idle store SHALL return without touching the database and without reporting any state.

#### Scenario: Backgrounding is durable

- **WHEN** the app backgrounds with a debounced batch still pending
- **THEN** the flush returns only once that batch is on disk

#### Scenario: Flush on an idle store

- **WHEN** nothing is pending and no save is in flight
- **THEN** the flush is a no-op

### Requirement: Save state reporting

The store SHALL report its save state so the app can surface it. A clear state SHALL be reported only
after a non-clear state, so that a healthy app never flashes a banner for a problem it never had.

#### Scenario: No banner on a healthy save

- **WHEN** saves succeed from the start
- **THEN** no save state is ever reported

### Requirement: Tombstones and loading

A deletion SHALL never remove a row. It SHALL mark the row tombstoned and bump its version vector, so
the row remains as a deletion record for a future sync engine.

Loading SHALL return every row that is not tombstoned, and SHALL rebuild state by replaying upserts.
Archived and reference-only rows SHALL load normally — only tombstoned rows are invisible.

Storage errors during a load SHALL propagate, so that startup can offer a retry.

#### Scenario: Deleted row is hidden but present

- **WHEN** an entry is deleted
- **THEN** a load no longer returns it, while the row remains in storage marked tombstoned

#### Scenario: Archived rows still load

- **WHEN** a holder is archived
- **THEN** it is still returned by a load
