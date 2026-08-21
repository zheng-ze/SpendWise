# 49. Edit mutators can never move a row's lifecycle state; only delete/restore/purge do

## Status

Accepted

## Context

An adversarial review found that `updateAccount`/`updatePocket`/`updateCategory` accepted a
caller-constructed row with a freely-settable `lifecycle` field, and the guard against this
(`_editableLifecycle`) only policed individual transitions case-by-case — it blocked resurrecting a
stored `referenceOnly` row and blocked a direct move to `tombstoned`, but left the
`active`/`archived` → `referenceOnly` direction completely open. `referenceOnly` is meant to be
reachable only through the purge path, which checks referencedness first; reaching it through a
plain edit bypassed that check entirely, and the only guard against the resulting state was a
debug-only `assert`, stripped from release builds. In practice: any caller setting
`lifecycle: LifecycleState.referenceOnly` on an unreferenced row via `updateAccount` produced a
silently orphaned row in release, invisible in the UI and never swept.

The real defect was edit accepting lifecycle as free-form input at all — `delete`/`purge`/`restore`
already own every legal lifecycle transition, each with its own precondition (referencedness for
purge, archived-only for restore, active-only for delete), and edit accepting lifecycle input
duplicated that authority in a second place, incorrectly.

## Decision

`_editableLifecycle` now always returns the row's currently-stored lifecycle value, unconditionally —
edit can no longer move lifecycle in any direction at all, not just the `referenceOnly` direction
the review originally flagged. This closes the gap without adding a new error type: edit silently
keeps the existing lifecycle, the same way it already handled the resurrect and tombstone cases,
just applied uniformly instead of case-by-case.

This also removed a second, real capability that had no legitimate caller: `updateAccount`/
`updatePocket`/`updateCategory` could previously toggle a row between `active` and `archived`
directly through edit. No UI form actually used this path — the one real caller always passed the
row's own existing lifecycle back unchanged — and `delete`/`restore` are the correct, narrower
mutators for that transition on separation-of-responsibility grounds (edit changes values;
lifecycle transitions are delete/restore/purge's job alone). Tests that depended on archive-via-edit
were removed or rewritten to use `deleteAccount` instead, since the behavior they proved is
intentionally gone, not merely relocated.

## Consequences

Every lifecycle transition in the domain now happens through exactly one of three purpose-built
mutators (`delete`, `restore`, `purge`), each with its own precondition — there is no fourth,
looser path through edit that a future caller could rediscover. A caller wanting to archive or
restore a row must call the dedicated mutator; passing a different lifecycle value into an edit
call is now silently ignored rather than silently honored.
