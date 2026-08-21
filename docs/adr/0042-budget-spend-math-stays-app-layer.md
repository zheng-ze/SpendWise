# 42. Spend aggregation and rollup math for budgets stay out of the domain

## Status

Accepted

## Context

A budget is meaningless without knowing how much has actually been spent against it, but computing
that spend requires scanning entries — which every planned budget-adjacent feature (in-app alerts, a
cross-screen badge, a budget-vs-actual trend view, a warning when a recurring plan would push a
category over budget, a frozen budget snapshot in an export) was checked against before deciding
where this logic belongs.

## Decision

`packages/domain` exposes only `effectiveLimit(budget, month)` — the configured limit, with nothing
about actual spend folded in. Spend aggregation, and any rollover-adjusted limit math, live entirely
at the app layer. This matches how spend is already computed today elsewhere in the app: the
category-detail screen and the stats screen both sum entries per category live, with no domain-level
"total spend" query backing either of them.

Every feature that was checked as a candidate reason to promote spend into the domain turned out not
to need it there — an app-layer listener on the existing event bus can react to entry changes and
compute budget status without moving any of that logic into `packages/domain`.

## Consequences

The domain package never needs a dependency on "what has been spent," keeping its surface area
small and its tests independent of entry volume. Any future budget feature that needs spend data
computes it at the app layer by scanning entries (as `category_detail_screen.dart` and
`stats_screen.dart` already do), rather than asking the domain for a new aggregate query.
