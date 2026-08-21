# 31. Subcategory-table fractions are relative to the category, not the period

## Status

Accepted

## Context

Inside a category's detail view, each child subcategory shows what fraction of spending it
represents. Two candidate denominators: the whole period's total spending (matching the donut
chart's own fractions, which are period-relative), or the parent category's own total spending.
Using the period as the denominator here would make the subcategory table's percentages sum to
whatever fraction the parent category itself is of the period — an arbitrary, hard-to-interpret
number for a table that is specifically about how one category's spending breaks down internally.

## Decision

Fractions inside the subcategory table are relative to the category's own total, not the period's
total. A child holding half its parent category's spend reads 50%, regardless of what fraction the
parent category itself is of the whole month.

## Consequences

The subcategory table's percentages always sum to 100% (modulo the direct-spend row's own
threshold rule), which is the readable, self-consistent framing for a screen about one category's
internal breakdown. Any future per-category breakdown view must use the category's own total as its
fraction denominator, not the period total the top-level donut chart uses — the two are answering
different questions and should not share a denominator.
