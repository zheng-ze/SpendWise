# 6. Archiving a holder freezes its plans; deleting one removes them

## Status

Accepted

## Context

A `RecurringPlan` names a holder (account, pocket) or a category. Both archival and deletion can
happen to the row a plan names, and the domain needs one rule for what happens to the plan in each
case. Treating them the same way — either always cascading or never cascading — was considered and
rejected, because the two operations mean different things to a user.

## Decision

Two different rules apply, deliberately:

- **`deleteAccount` hard-removes every plan naming the account or any of its pockets.** Archiving
  an account is a whole-holder retirement that takes its pockets with it, and deletion is
  permanent, so nothing is left for a plan to reference.
- **`deletePocket` and `deleteCategory` remove nothing.** The plan stays; its occurrences fail
  validation while the row is inactive, and `resolvePlans` reports those failures instead of
  throwing. Archiving a single pocket or category is routine tidying a user is expected to undo,
  and dropping the plan at archive time would make restore silently lossy — nothing would hold an
  archived plan to bring back once the row is restored.

Invariant clause 14 encodes the result: a plan may name an **archived** row, but never a
`referenceOnly` or `tombstoned` one. Every path that deletes a row outright (rather than archiving
it) must take the plans naming that row with it — the dereference sweep and the purge row helpers
all carry this responsibility.

## Consequences

A plan naming an archived pocket or category sits in a failing state until the row is restored,
and that failing state is visible through `resolvePlans`' `PlanFailure` reporting rather than a
thrown error — this is also the only way to reach `PlanFailure` through the public API. A future
change that adds a new way to remove a row must decide, explicitly, whether that removal is an
archival (plan survives, may fail) or a deletion (plan is cascaded away) — there is no default.
