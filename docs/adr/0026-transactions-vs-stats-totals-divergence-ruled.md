# 26. Transactions and Stats are allowed to disagree on totals, by ruling

## Status

Accepted

## Context

The Transactions screen and the Stats screen both show income/expense totals for a period, computed
two different ways: Transactions applies only entry-level analysis inclusion (`includeInAnalysis`),
while Stats additionally applies category-level include-gates and reclassifies treat-as-expense
transfers as spending. This divergence already existed in the Swift app. Two earlier phases
(transactions UI, stats UI) were each told to keep this decision open and route their totals through
a single call site, specifically so that whichever way the ruling eventually landed, fixing it would
be a one-line swap rather than a hunt through widgets — deciding it before both screens existed to
compare side by side would have been premature.

## Decision

The divergence is ruled as intentional, once both screens existed to compare: Transactions' totals
reflect entry-level inclusion only, and Stats' totals reflect the fuller analysis-gate treatment,
and the two are allowed to show different numbers for the same month. This is not resolved by
unifying the two calculations.

## Consequences

A user can see different income/expense figures on Transactions versus Stats for the same month, and
this is expected behavior, not a bug to file. Because both screens route their totals through a
single call site each (established by the earlier phases specifically for this reason), a future
decision to unify them is still a small, localized change rather than a search-and-replace across
widgets.
