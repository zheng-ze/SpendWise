# ledger-state Specification

## Purpose
Holds the whole ledger in memory — money sources, entries and categories — and exposes the read-only
queries a surface needs to list, name and count them, plus the change and error vocabulary every
mutation communicates through.
## Requirements
### Requirement: Ledger container

The ledger SHALL hold money sources, entries and categories in three id-keyed tables, each defaulting
to empty. Rows whose lifecycle is no longer active SHALL remain in their table so that entries
referencing them still resolve; the queries, not the tables, decide what a surface shows.

Money sources are accounts and pockets sharing a single id space.

#### Scenario: Empty ledger

- **WHEN** a ledger is constructed with no arguments
- **THEN** all three tables are empty

#### Scenario: Archived rows are retained

- **WHEN** a holder is archived and an entry still references it
- **THEN** the holder remains in the money-source table and the entry still resolves its name

### Requirement: Change vocabulary

Every mutation SHALL report what it changed as an ordered list of changes drawn from exactly seven
cases: upsert of an account, a pocket, a category or an entry, and deletion of a money source, a
category or an entry. Deletion of a money source covers both accounts and pockets because they share
an id space.

An upsert SHALL carry the stored object — the value after validation, normalization and any field
forcing — so that a subscriber can mirror the ledger from the change stream alone.

Two changes SHALL be equal when their case and their payload value are equal.

Every change SHALL expose the id of the row it targets, for all seven cases without exception, because
downstream consumers coalesce changes by that id.

A change SHALL be constructible from a money source without the caller knowing whether it is an
account or a pocket, dispatching to the matching upsert case.

#### Scenario: Upsert carries the stored value

- **WHEN** a mutation normalizes or overrides a field of the object it was given
- **THEN** the emitted upsert carries the normalized stored object, not the caller's argument

#### Scenario: Target id is total

- **WHEN** the target id of any of the seven change cases is read
- **THEN** it yields that row's id, and no case is unsupported

#### Scenario: Value equality

- **WHEN** two changes of the same case carry payloads with equal field values
- **THEN** the changes compare equal

#### Scenario: Dispatch from a money source

- **WHEN** a change is built from a money source
- **THEN** an account yields an account upsert and a pocket yields a pocket upsert

### Requirement: Error vocabulary

A rejected mutation SHALL throw one of ten errors, each identifying the reason for rejection: id
collision, unknown account, unknown holder, unknown category, unknown entry, zero amount, self
transfer, category nested too deep, category kind mismatch, and inactive reference.

Errors that identify an offending row SHALL carry that row's id. Errors SHALL compare equal by case
and payload so that callers can assert on the exact rejection.

Errors SHALL be throwable as exceptions.

#### Scenario: Payload identifies the offending row

- **WHEN** a mutation is rejected because an id is unknown or already taken
- **THEN** the thrown error carries that id

#### Scenario: Errors compare by case and payload

- **WHEN** two errors of the same case carry the same id
- **THEN** they compare equal, and errors of different cases never compare equal

### Requirement: Active and binned row queries

The ledger SHALL report the ids of active money sources, active categories, archived money sources and
archived categories. The archived sets are what a recycle-bin surface lists.

#### Scenario: Active set excludes non-active rows

- **WHEN** a ledger holds active, archived and reference-only rows
- **THEN** the active set contains only the active ids and the binned set only the archived ids

### Requirement: Account and pocket listing queries

The ledger SHALL list active accounts sorted by name ascending, and SHALL list a given account's
pockets — resolved through that account's pocket links, active only, sorted by name ascending.

#### Scenario: Accounts are name-sorted

- **WHEN** active accounts are listed
- **THEN** they come back sorted by name ascending, with archived accounts absent

#### Scenario: Pockets resolve through the parent's links

- **WHEN** an account's pockets are listed
- **THEN** only its own active pockets appear, sorted by name ascending

### Requirement: Source name query

The ledger SHALL resolve a money-source id to a display name: an account yields its own name; a pocket
yields its parent account's name and its own name joined by a forward slash, or its bare name when no
owning account exists. A null or unknown id SHALL yield null.

#### Scenario: Pocket name is parent-qualified

- **WHEN** the name of a pocket owned by an account is requested
- **THEN** the result is the parent name and the pocket name joined by a slash

#### Scenario: Missing id

- **WHEN** the name of a null or unknown id is requested
- **THEN** the result is null

### Requirement: Reference-count queries

The ledger SHALL count the entries that reference a given holder as source or destination, the entries
that touch any holder in a given set, and the entries carrying a given category id. These counts are
what the purge and dereference rules consult.

#### Scenario: Holder count spans both endpoints

- **WHEN** entries reference a holder as source and others as destination
- **THEN** the holder's reference count includes both

#### Scenario: Set count is a union

- **WHEN** entries are counted against a set of holder ids
- **THEN** an entry touching more than one id in the set is counted once

### Requirement: Rebuild from a change stream

The ledger SHALL be constructible by replaying a list of changes into an empty state, writing each
change directly into the tables: an upsert stores its value under its id, and a deletion removes
that id.

Replay SHALL bypass validation, cascades and the invariant sweep. It reconstructs a state that was
already validated when it was first produced, so re-running the mutators would both cost time and
risk rejecting data that is legitimately stored.

The consequence SHALL be understood rather than patched: deleting a pocket during replay does not
remove it from its parent account's pocket links, because the mutation that originally emitted the
deletion also emitted the parent's upsert into the same stream. Replay trusts the stream to be
complete. See ADR-0021 for how a replayed state is checked afterward, and ADR-0002 for why the
parent-owned pocket link makes this consequence possible.

#### Scenario: Round trip through a change stream

- **WHEN** a state is serialized to upsert changes and replayed into an empty ledger
- **THEN** the rebuilt ledger equals the original

#### Scenario: Replay does not cascade

- **WHEN** a stream deletes a pocket without a corresponding parent upsert
- **THEN** replay removes the pocket and leaves the parent's links untouched, rather than repairing
  them

#### Scenario: Replayed state can still be checked

- **WHEN** a debug build finishes rebuilding a state from storage
- **THEN** the invariant check may be run against it on demand, since replay itself never runs it

