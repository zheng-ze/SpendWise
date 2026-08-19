## MODIFIED Requirements

### Requirement: Lifecycle machine

A money source or category SHALL move through the lifecycle states active, archived, reference-only and
tombstoned under these rules:

- Deleting a holder or category archives it. Nothing is removed and entries are always retained; only
  entries hard-delete.
- Restoring an archived row returns it to active.
- Purging an archived row forks: a referenced row becomes reference-only, an unreferenced row is
  tombstoned, meaning its row is removed from its table.
- Reference-only is terminal but one: there is no restore from it, and its only exit is tombstoning by
  the dereference sweep when the last referencing entry is deleted or retargeted away.
- Every stored entry is active; an entry is either present or gone.

Reference-only SHALL be reachable only through the purge path above. A plain update to a holder or
category SHALL reject any attempt to set its lifecycle to reference-only directly, with a real error
that holds in release builds — this is the same terminal state a mutator must never grant to a row
the purge path hasn't already determined is referenced.

#### Scenario: Delete never removes a holder

- **WHEN** an account with entries is deleted
- **THEN** the account is archived, its row remains, and every entry is retained

#### Scenario: Reference-only has no restore

- **WHEN** a restore is attempted on a reference-only row
- **THEN** it is a no-op returning no changes

#### Scenario: A plain update cannot grant reference-only

- **WHEN** an update names reference-only as the lifecycle for a holder or category that a purge has
  not already put there
- **THEN** the mutation throws and the ledger is unchanged, in both debug and release builds
