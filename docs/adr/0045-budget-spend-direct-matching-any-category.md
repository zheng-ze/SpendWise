# 45. Budget spend is computed by direct matching; any active category can be budgeted

## Status

Accepted (reverses an earlier top-level-only restriction)

## Context

An earlier pass restricted budgets to top-level categories only, because the obvious way to compute
a budget's spend — `Accounting.rollUp` — keys its result by `Accounting.mainBucketID`, which
collapses every leaf (subcategory) onto its parent's id. Using `rollUp` directly for a subcategory
budget would always resolve to zero spend, since `rollUp`'s map never carries a leaf category's own
id as a key. Forbidding subcategory budgets was the workaround at the time.

Reopened and reversed with the user: a budget should be settable on any active category, top-level
or subcategory, with a subcategory's spend counting toward both its own budget and its parent's
budget independently — the two totals are allowed to overlap, since they represent two separate
limits a user is deliberately tracking, not one number double-counted by accident.

## Decision

`budgetSpend` filters `AnalysisItem`s directly against `state.categories`, without going through
`rollUp`: an overall budget sums every expense item in the month; a category budget sums items whose
bucket is the budgeted category's own id, plus items whose bucket names a category whose parent is
the budgeted category (its direct children). Because category nesting is capped at two levels
domain-wide, "direct children" already covers the whole subtree — no recursive walk is needed. No
new domain function was added; the domain still computes only `effectiveLimit`, unchanged from the
original ruling that spend math lives at the app layer.

## Consequences

A parent-category budget and one of its children's own budget can now both report spend against the
very same entry, and their two totals are not meant to sum to anything meaningful together — each
budget card shows only its own limit and its own spend, with no combined-total UI implying otherwise.
A test asserts this overlap is real (a child's entry counts toward both budgets independently) so a
later "fix" doesn't quietly introduce double-counting prevention where none was wanted.
