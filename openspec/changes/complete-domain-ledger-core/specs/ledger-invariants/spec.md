## Purpose

States the structural properties that must hold of any reachable ledger state, so that a mutation which
corrupts the ledger fails loudly in development instead of persisting the corruption to disk.

## ADDED Requirements

### Requirement: Invariant checking

The ledger SHALL expose an invariant check that verifies every clause below and fails when any is
violated. It SHALL run after every mutation in debug builds only, so release builds pay no cost, and
SHALL also be callable on demand so that tests can assert a state directly.

#### Scenario: Debug-only execution

- **WHEN** the ledger runs in a release build
- **THEN** the invariant check does not execute

#### Scenario: On-demand check

- **WHEN** a test invokes the check directly on a ledger state
- **THEN** it verifies every clause and fails on the first violation

### Requirement: Structural invariants

The following SHALL hold of every reachable ledger state:

1. In each table, every key equals the stored value's own id.
2. Every id in an account's pocket links resolves to a pocket in the money-source table, and no pocket
   id appears in two accounts' links. Archived and reference-only pockets stay linked; only tombstoned
   ones leave.
3. Every pocket in the money-source table appears in exactly one account's links.
4. Every entry's source, and its destination when present, resolves in the money-source table in any
   lifecycle.
5. A category with a stored parent has a parent that itself has no parent, and its kind equals its
   parent's kind.
6. For every entry whose category resolves, the entry is not a transfer and the category's kind equals
   the kind implied by the entry's sign. The category's lifecycle is irrelevant.
7. Every stored plan's template source, its destination when present, and its category when present
   resolve in their tables.
8. Every stored plan with an end date has a cursor strictly before that end date. Stated against the
   plan's own cursor rather than a clock, since the domain has none.
9. Every stored entry is active.
10. No holder or category stored in any table is tombstoned.
11. Every reference-only category is carried by at least one entry. Every reference-only pocket has at
    least one referencing entry. Every reference-only account has at least one referencing entry or at
    least one pocket still present in its links.

#### Scenario: Archived holders with retained entries are legal

- **WHEN** an active entry references an archived holder
- **THEN** every invariant holds

#### Scenario: Orphaned pocket is caught

- **WHEN** a pocket exists in the money-source table but no account links to it
- **THEN** the invariant check fails

#### Scenario: Account reference-only via a surviving pocket is legal

- **WHEN** a reference-only account has no referencing entries but still links a surviving pocket
- **THEN** every invariant holds

#### Scenario: Plan referencing a removed holder is caught

- **WHEN** a stored plan's template names a holder that is no longer in the money-source table
- **THEN** the invariant check fails

#### Scenario: Exhausted plan left in the table is caught

- **WHEN** a stored plan's cursor has reached or passed its end date
- **THEN** the invariant check fails
