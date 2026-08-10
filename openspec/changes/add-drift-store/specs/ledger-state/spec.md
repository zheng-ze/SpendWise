# ledger-state Specification

## ADDED Requirements
### Requirement: Rebuild from a change stream

The ledger SHALL be constructible by replaying a list of changes into an empty state, writing each
change directly into the tables: an upsert stores its value under its id, and a deletion removes that
id.

Replay SHALL bypass validation, cascades and the invariant sweep. It reconstructs a state that was
already validated when it was first produced, so re-running the mutators would both cost time and
risk rejecting data that is legitimately stored.

The consequence SHALL be understood rather than patched: deleting a pocket during replay does not
remove it from its parent account's pocket links, because the mutation that originally emitted the
deletion also emitted the parent's upsert into the same stream. Replay trusts the stream to be
complete.

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
