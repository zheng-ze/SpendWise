## Purpose

Governs the boundary between a `LedgerState` in memory and its stored form on disk: every value
that survives a round trip through storage must come back unchanged, and a state loaded from a
stored change stream must be as trustworthy as one built by mutators directly.

## ADDED Requirements

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
