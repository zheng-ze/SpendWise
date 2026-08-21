# 44. Budgets is a third Stats segment, not a new shell navigation tab

## Status

Accepted

## Context

The app shell has a fixed four-value navigation enum (transactions/stats/accounts/settings), and the
Stats screen already has a top tab bar switching between Income and Expense, backed by the existing
category rollup and slicing computation. Adding a Budgets feature needed a place to live in the
navigation.

## Decision

Confirmed with the user: Budgets becomes a third segment on the existing Stats top tab bar
(Income/Expense/Budgets) rather than a fifth shell destination. The screen's internal state type
changes from a two-value `CategoryKind`-based selector to a three-value selector so the Budgets
branch can render a budgets list instead of the donut and legend, while every other site that reads
the selector stays guarded to the two original branches (tapping a category slice to open its detail
screen makes no sense for the Budgets branch, for instance). The existing Monthly/Annually range
toggle is hidden (or forced to Monthly) whenever the Budgets segment is active, since budgets have no
year-range concept to switch to.

## Consequences

No shell, navigation, or destination-enum change was needed to ship Budgets — the change is additive
to the Stats screen alone. Any future feature considered for its own shell tab should weigh this
precedent: a feature that fits naturally as a segment of an existing screen does not automatically
need a new top-level destination.
