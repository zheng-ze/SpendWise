# ledger-runtime Specification

## Purpose
Defines the single object allowed to hold and mutate ledger state, and the fixed pipeline every
mutation passes through.

Concentrating mutation in one hub is what makes the event stream trustworthy: if any other object
could change state, a change could reach storage or the screen without ever being announced.

## ADDED Requirements
### Requirement: Sole ownership of state

The runtime SHALL be the only object that holds a mutable ledger state. State SHALL be readable by
other layers but mutable only through the hub's own API.

#### Scenario: Reading without mutating

- **WHEN** a screen needs ledger data
- **THEN** it reads through the hub rather than holding a mutable state reference

### Requirement: Mutation pipeline

Every mutation SHALL run the domain mutator, then check invariants in debug builds only, then
publish the resulting changes as one batch, then notify listeners — in that order.

The order is load-bearing: invariants are checked against committed state, and nothing is announced
before it holds.

#### Scenario: Successful mutation announces once

- **WHEN** a mutation succeeds and produces several changes
- **THEN** they are published as a single batch after the state is committed

#### Scenario: Invariant checking is debug-only

- **WHEN** the app runs in a release build
- **THEN** the invariant sweep does not execute

### Requirement: Rejected mutations are silent

When a domain mutator rejects a mutation, the runtime SHALL leave state unchanged, SHALL NOT check
invariants, SHALL NOT publish anything, SHALL NOT notify listeners, and SHALL propagate the error to
the caller.

#### Scenario: Validation failure

- **WHEN** a mutation is rejected by domain validation
- **THEN** no batch is published and the caller receives the error

### Requirement: Mutation surface

The hub SHALL expose one method per domain mutator and SHALL NOT invent operations the domain does
not provide. In particular there SHALL be no restore or purge for entries, and none for plans, since
entries are not independently restorable and plans hard-delete.

#### Scenario: Delete means archive

- **WHEN** an account is deleted through the hub
- **THEN** it is archived into the recycle bin and its entries are retained

### Requirement: Active category ordering

The hub SHALL expose active categories of a given kind ordered as roots sorted by name, each root
immediately followed by its own children sorted by name. A child whose parent is absent from the
filtered set SHALL be omitted.

Ordering SHALL use ordinal string comparison rather than locale-aware collation, so that the order is
identical on every platform.

#### Scenario: Children follow their parent

- **WHEN** categories are listed for a kind
- **THEN** each root is immediately followed by its own children, both alphabetically ordered

#### Scenario: Orphaned child is omitted

- **WHEN** a child's parent is not in the active set for that kind
- **THEN** the child does not appear

### Requirement: Plan resolution reporting

Resolving plans SHALL commit and publish every occurrence that succeeded, even when others failed.
Failures SHALL NOT abort the mutation, and SHALL be reported through an error callback only after the
successful changes are committed and published.

Resolution SHALL always use a fixed UTC calendar rather than the device calendar, so that occurrence
identity does not vary by timezone.

#### Scenario: Partial failure still commits

- **WHEN** some due occurrences fail validation and others succeed
- **THEN** the successful ones are committed and published, and the failures are reported afterwards

#### Scenario: Plan reaching its end date is not a failure

- **WHEN** a plan stops producing occurrences because it passed its end date
- **THEN** nothing is reported as an error
