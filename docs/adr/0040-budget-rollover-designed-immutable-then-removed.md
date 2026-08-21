# 40. Budget rollover mode and carry cap: designed immutable, later removed entirely

## Status

Superseded

## Context

The original budget design gave every budget a `rolloverMode` (`none`/`positiveOnly`/`both`) and a
`carryCap`, both fixed at creation and never editable afterward. The reasoning at the time: a
mutable rollover mode or carry cap, with no history of its own, would mean changing either setting
today would silently recompute every past month's carry under the new setting — the same
retroactive-rewrite problem the `LimitEvent` timeline exists to prevent for the limit itself, but
for these two fields instead. Making both fields immutable removed the problem outright rather than
tracking around it with a second parallel timeline.

A later review of the actual shipped app found that the form's edit path for these fields was
unreachable, and — more fundamentally — that no rollover carry-forward math had ever actually been
implemented anywhere. The fields existed in the model with no consumer computing anything from them.

## Decision

`RolloverMode` and `carryCap` were removed from `Budget` entirely, rather than finished. A budget's
effective limit is exactly `effectiveLimit(budget, month)` with no rollover adjustment layered on
top anywhere.

## Consequences

There is currently no way for an unspent amount in one month to carry forward and raise a later
month's effective limit — every month's limit is exactly what its `LimitEvent` timeline resolves to,
full stop. If rollover carry is wanted in the future, it needs a fresh design pass rather than
resurrecting these two fields as they were specified here; this ADR is kept as the record of why the
fields existed and why they were removed, not as a design to revive unmodified.
