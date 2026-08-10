# persistence-schema Specification

## Purpose
Defines what a stored ledger looks like on disk: the tables, the columns every row carries, how domain
values map to and from them, and what happens when stored data cannot be understood.

The storage model is deliberately separate from the domain model, so that the domain never acquires a
dependency on how it is persisted.

## ADDED Requirements
### Requirement: Row tables

Storage SHALL keep accounts, pockets, categories, entries and plans in their own tables, plus a
metadata table holding the device identity and the seeding flag.

A plan's entry template SHALL be flattened into columns on the plan row rather than stored as a nested
structure.

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

### Requirement: Decode fallback policy

An unrecognized enum code SHALL fall back to a documented default rather than failing the load, so
that a row written by a newer version stays readable.

A version vector that fails to decode SHALL be an error, NOT an empty vector. An empty vector would
silently erase a row's causal history, which becomes data loss once changes are merged across
devices.

#### Scenario: Unknown enum code

- **WHEN** a row holds an enum code this version does not recognize
- **THEN** it loads as the documented default for that enum

#### Scenario: Corrupt version vector

- **WHEN** a row's version vector cannot be decoded
- **THEN** the load fails loudly rather than resetting that row's history

### Requirement: Version vectors

Each row SHALL carry a vector counting writes per device. Every applied write SHALL bump the target
row's vector exactly once — upserts and tombstones alike, since a deletion is a write that must be
orderable against others.

The vector SHALL support asking whether it dominates another and whether two are concurrent. Merging
SHALL NOT be implemented here; it belongs to the future sync engine.

Bumps SHALL happen inside the save transaction, so that a rolled-back save leaves the stored vector
untouched.

#### Scenario: Tombstone bumps the vector

- **WHEN** a row is tombstoned
- **THEN** its version vector is bumped

#### Scenario: Rolled-back save leaves vectors alone

- **WHEN** a save fails and rolls back
- **THEN** stored vectors are unchanged, and the retry re-bumps from the stored value
