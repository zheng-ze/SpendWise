## Context

See proposal.md for motivation and scope. This document covers the domain model only — how a
`Budget` is shaped, how its effective limit resolves for a given month, and what stays out of
`packages/domain` on purpose. No existing `Budget` concept exists anywhere in the codebase.

`RecurringPlan` is the closest existing pattern (`packages/domain/lib/src/recurring_plan.dart`,
`ledger_state_plans.dart`) and this design borrows from it in some places and deliberately departs
from it in others; both are called out below.

A `Budget` has six fields: `id` (uuid), `categoryID` (nullable, immutable after creation),
`limitEvents` (the append-only history described below), `rolloverMode` (immutable after creation),
`carryCap` (immutable after creation, set alongside `rolloverMode`), and `createdAtMonth` (the
month the budget was created, fixed at construction and never changed — the anchor the app-layer
rollover walk starts from). The rest of this document explains why each field is shaped the way it
is.

## Goals / Non-goals

**Goals:**
- Store a monthly spending limit per category (or one limit covering every category) that can
  change over time without rewriting a month whose limit already resolved.
- Let a user pin a single month to its own limit without disturbing the ongoing default.
- Keep the domain layer free of anything that needs entry data (spend totals, rollover math).

**Non-goals:**
- No UI. That is a separate, later change once this model is reviewed and merged.
- No spend aggregation, no rollover-adjusted limit, no notifications — all app-layer, and none of
  it is built in this change.
- No budget name or label. The UI shows the category (or "Overall") as the identifier.
- No multi-category budgets.
- No frequency other than monthly.
- No editing a budget's category or rollover mode after creation.

## Decisions

### A timeline of limit events, not a single mutable field

A budget's limit can't be one scalar field the user overwrites. Once overwritten, the old value is
gone, so a past month resolved today would pick up the new value by mistake — the requirement is
that editing the limit only ever changes months from that point forward. Avoiding that would mean
freezing every elapsed month into its own row the moment the default changes, which needs a
background process to do the freezing. This design has no such process (see "No resolution step"
below), so instead a `Budget` keeps an ordered, append-only list of `LimitEvent`s:

```
LimitEvent {
  effectiveFromMonth: YearMonth?  // null only on the very first event
  value: Decimal
  kind: enum { default, override }
}
```

Resolving a month's limit is a pure fold over this list, with no side effects and nothing written:

- If the list has an event for exactly that month with `kind: override`, use its value. If more
  than one override was ever written for that month, the one appended last — furthest along the
  list, not the earliest — wins. Writing a new override over an existing one is how a user changes
  their mind about a pinned month.
- Otherwise, use the value of the latest `default` event whose `effectiveFromMonth` is at or before
  that month.

Only the very first event a budget is ever created with has `effectiveFromMonth: null`, and that
first event is always `kind: default`. Every event appended afterward — `default` or `override`
alike — must name a real month; `addBudget` establishes the one unbounded event at construction,
and every mutator that appends to `limitEvents` after that rejects a null `effectiveFromMonth`. A
`LimitEvent` with a null `effectiveFromMonth` anywhere but the first position, or with
`kind: override` at all, is not a state the domain can produce.

An override always wins for its own month, permanently, no matter what gets written afterward. A
later default-kind edit — "the limit changes to $X from month M forward" — never reaches into a
month that already has its own override. The only way to change an overridden month is to write a
new override to that same month.

`default` and `override` are two scopes of the same underlying write, not two separate concepts.
Keeping them as one list, rather than a scalar default plus a separate override map, avoids
reintroducing the freezing problem for the default half.

### No resolution step

`RecurringPlan.resolvePlans(now)` mints entries lazily because a plan produces facts — real rows —
that have to exist somewhere. A budget's limit is pure configuration: resolving it is cheap enough
to recompute on every read, so there's nothing to mint and nothing to save automatically. A month
with no event of its own simply has no row at all; `effectiveLimit` computes it from the timeline
on demand. A row gets written only when a user actually edits something — an explicit action, never
a background job.

### Retroactive limit reaches back with no floor

A budget's first `LimitEvent` has `effectiveFromMonth: null`, meaning it applies to every month at
or before creation with no lower bound. An earlier design scanned existing entries at creation time
to anchor the first event to the earliest month with matching activity. That breaks if the user
later backfills an even-earlier entry: the anchor, having already been picked, would leave the
backfilled month with no budget coverage. Leaving the first event unbounded avoids the problem
outright — there is no anchor to get wrong, because nothing is scanned.

### Category is a single nullable field, not a set

`categoryID: String?` is fixed at creation. `null` means an overall budget covering every category;
at most one budget may have `categoryID: null` at a time, the same uniqueness rule that applies to
any other category value.

Categories already form a real parent/child hierarchy (`parentID` in `transaction_category.dart`),
and `category_detail_screen.dart` already rolls a parent's spend up across its children. A budget
placed on a parent category can use that same rollup at the app layer, which covers the case a
multi-category budget was meant to solve — a combined cap over, say, Fast Food and Restaurants is
just a budget on their shared Food parent. That removed the need for a multi-select category set
entirely.

This only covers categories that already share a parent. Two leaf categories under different
parents — Coffee under Food and Rideshare under Transport, say — can never be capped by one budget
under this design; each needs its own budget, or the user restructures the category tree so they
share a parent. This is a real, permanent limitation of dropping multi-select, not a temporary gap
(see Risks / trade-offs).

### Rollover mode and carry cap are fixed at creation

`rolloverMode: enum { none, positiveOnly, both }` and `carryCap: Decimal?` are both set once, at
creation, and cannot change afterward. `carryCap` bounds how much a budget's rollover carry can
accumulate — `null` means unlimited, and there is no fixed system default; the user picks a cap (or
no cap) per budget at creation. Changing a budget's category, rollover mode, or carry cap all
require deleting the budget and creating a new one; appending a new `default`-kind `LimitEvent` (an
"edit amount" write) is the only way an existing budget's limit changes after creation.

Rollover carry is computed at the app layer by walking every month from `createdAtMonth` forward
(see "What stays out of the domain" below). A mutable `rolloverMode` or `carryCap` with no history
of its own would mean a change today silently recomputes every past month's carry under the new
setting, which then leaks into today's effective limit — the same retroactive-rewrite problem the
`LimitEvent` timeline exists to prevent, but for these two fields instead of the limit. Giving them
their own parallel timelines would fix it, but making both fields immutable removes the problem
instead of tracking around it: there is nothing to retroactively recompute if the values never
change.

### Hard delete, no tombstone

`deleteBudget` removes the budget outright, the same as `deletePlan` does for a `RecurringPlan`
(`_plans.remove(id)`, no lifecycle field). `Category` and `Account` soft-delete because entries
reference them by ID and need a defined answer for a dangling reference. Nothing in the domain
references a `Budget` by ID, so there is no dangling reference to guard against, and a tombstone
would only add a lifecycle concept nothing else needs to check.

### Deleting a category cascades to its budget

When a category is deleted or tombstoned, any budget whose `categoryID` matches it is hard-deleted
in the same operation. This mirrors the existing `_removePlansCategorized` /
`_removePlansReferencing` cascade in `ledger_state_plans.dart`, which already removes a
`RecurringPlan` when the category, account, or pocket it names is deleted. Because a budget names
exactly one category, there is no partial-cascade case to define — the category going away always
takes the whole budget with it, the same as it does for a plan.

### What stays out of the domain

Spend aggregation, rollover-adjusted limits, and parent-category spend rollup all live at the app
layer, not in `packages/domain`.

Spend is already computed live at the app layer today — `category_detail_screen.dart`'s
`_CategoryTotals.compute` and `stats_screen.dart`'s `slices(...)` both sum entries per category
without any domain-level query. Keeping budget spend the same way was checked against every planned
feature that might need it as a domain fact instead — in-app budget alerts, a cross-screen budget
badge, a budget-vs-actual trend view, a warning when a recurring plan would push a category over
budget, and a frozen budget snapshot in an export. None of them need spend to be a domain concept:
an app-layer listener on the existing `EventBus` (from `add-ledger-runtime`) can react to entry
changes and compute budget status without any of that logic moving into the domain.

Because spend lives at the app layer, so does rollover math — it needs spend as an input, and the
domain has no access to it. The domain exposes only `effectiveLimit(budget, month)`, the configured
limit with no rollover applied. The app layer folds the rollover-adjusted limit forward from
`createdAtMonth`, and carry genuinely accumulates: an unused amount from two months ago is still
available today if nothing has spent it since, not just what the immediately preceding month left
over.

```
carry(M) = clamp(effectiveLimit(M-1) + carry(M-1) - spend(M-1), cap: carryCap)
```

where `clamp` depends on `rolloverMode` — `positiveOnly` floors carry at 0, so an overspent month
never reduces the next month's limit, and caps the top end at `carryCap` (unbounded if `carryCap`
is `null`); `both` allows carry to go negative with the same cap applied symmetrically at the low
end; `none` always yields a carry of 0, ignoring `carryCap` entirely. The chain starts at
`createdAtMonth` with carry 0, since rollover was not configured for any month before the budget
existed. Months before creation resolve independently through the unbounded-past `LimitEvent`, with
no carry chained between them.

Parent-category rollup follows the same reasoning: a budget's app-layer spend total is the sum of
entries in its own category plus every descendant category, matching how Stats already aggregates.
The domain stores only the one `categoryID` and knows nothing about hierarchy.

Tombstoning a child category does not remove its past entries — an entry keeps the categoryID it
was recorded with regardless of whether that category is later tombstoned. A parent-category
budget's historical rollup keeps counting a tombstoned child's past entries for whatever month they
fall in; only new entries can no longer be tagged to that child going forward. The cascade in
"Deleting a category cascades to its budget" only fires when the budget's own `categoryID` is
tombstoned, not when one of its descendants is — a parent-category budget survives a child's
tombstoning intact, with its rollup unchanged for history and simply narrower going forward.

### Creation validation

`addBudget` rejects a `categoryID` that does not reference an existing, active category — the same
check `addPlan`'s `_validatePlan` already runs for `RecurringPlan`. `null` (the overall budget) is
exempt, since it names no category. It also rejects a `categoryID` that collides with an existing
budget's, `null` included, rejects a non-positive initial amount, and rejects a non-null `carryCap`
that is not strictly positive — whether that's a negative value, `0`, or any `carryCap` at all when
`rolloverMode` is `none`. A cap of `0` under `positiveOnly` or `both` would clamp carry to `0` every
month, which is indistinguishable from `none`; rejecting it keeps one rule for "this cap does
nothing" instead of accepting the `none` case as degenerate but the `positiveOnly`/`both` case as
valid. `carryCap` is either `null` (unlimited) or a real, usable limit — never a value that can only
ever produce zero carry.

### Reviewed for edge cases before and after this document was written

The model went through a multi-model review pass before this document was written, aimed at edge
cases rather than general soundness. Two independent reviewers, prompted separately, both raised
the same two sharpest findings: the rollover-mode retroactive-rewrite problem (resolved by making
the field immutable, above) and the question of whether an override can ever be superseded
(resolved by the override-always-wins rule, above — a later override on the same month is how a
user changes it). Both also flagged that an empty or tombstoned category reference needed to be
rejected at creation, which the validation rule above covers.

The document itself went through a second review pass after it was written, checking the write-up
for internal consistency rather than the underlying model. That pass found and fixed four gaps in
the prose (an unstated `createdAtMonth` field, an inaccurate claim that an override can be
"cleared," an unaddressed interaction between child-category tombstoning and parent-category
rollup, and a missing limitation around cross-parent categories) and, on a follow-up pass over the
corrected text, found that the rollover carry formula itself was wrong — it read as a single-month
lookback rather than a genuine accumulating carry. Fixing that surfaced the need for a cap on how
much carry can accumulate, which is where `carryCap` came from.

## Risks / trade-offs

- **Changing rollover mode or carry cap requires delete and recreate.** → Accepted: the alternative
  (a parallel timeline for either field) adds a second timeline concept for fields expected to be
  set once and rarely revisited.
- **An override can never be "cleared" back to following the default, only overwritten with a new
  value.** → Accepted, but note this is not a true clear: an override pinned to the current default
  is a fixed snapshot, not a live link back to it. If the default later changes, an overridden
  month stays at its pinned value and does not follow. Un-pinning a month for good means writing a
  fresh override every time the default moves, not a one-time fix.
- **`effectiveLimit` is recomputed on every read rather than cached anywhere in the domain.** →
  Accepted for a personal-finance app's scale: a budget's timeline stays short (one event per edit,
  not per month), so the fold is cheap. Any batching or caching needed for the app-layer rollover
  walk is that layer's concern, not the domain's.
- **A budget on the exact category that later gets tombstoned is cascade-deleted, losing its
  `limitEvents` history.** → Accepted: matches how `RecurringPlan` already behaves when its category
  is deleted, and keeping a budget alive with no category to attach to would leave a record nothing
  can ever resolve spend against. Tombstoning a *descendant* of a parent-category budget's category
  does not trigger this cascade — only an exact match does (see "Deleting a category cascades to
  its budget").
- **A budget can only cover one category (or every category).** Two categories that don't share a
  parent can never be capped by a single budget, only by budgeting their shared ancestor when one
  exists, or by two separate budgets when it doesn't. → Accepted: this is the direct cost of
  dropping multi-select in favor of parent-category rollup (see "Category is a single nullable
  field, not a set"). A user who wants exactly this needs to restructure their categories so the
  two share a parent, or accept two budgets tracked separately.

## Migration plan

No existing data to migrate — no `Budget` concept exists anywhere in the codebase today. Rollout
is: land this domain model and its tests, then persistence (schema and mappers) picks it up in
whichever change covers storage for this feature, then UI in a further change after that. No
rollback concern beyond the project's usual gate: `dart format`, `dart analyze`, and `dart test`
green in `packages/domain` before merging.
