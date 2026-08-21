# 8. Window filters are half-open `[start, end)` everywhere

## Status

Accepted

## Context

Swift's `DateInterval.contains` is closed at both ends. An item timestamped exactly on a month
boundary would count in both the month that ends there and the month that begins there — a latent
double-count that real entries essentially never trigger, since entries are never timestamped
exactly on an instant boundary, but which is still wrong if it ever happened.

An early pre-implementation review flagged that two parts of the plan pinned opposite semantics —
one section wanted half-open windows everywhere, another (following Swift literally) wanted
end-inclusive intervals to match `DateInterval.contains` — and a mixed implementation (analysis
half-open, day-sections inclusive) would have widened the already-tracked Transactions-vs-Stats
totals divergence.

## Decision

Every window filter in the port — analysis item filtering, day/week/month sectioning, plan
occurrence windows — uses half-open `[start, end)` semantics, deviating from Swift's closed
interval. This is a sanctioned deviation, not an oversight: it is the module where the project's
general half-open-windows rule first meets a Swift closed interval, and a boundary test is
required wherever a window filter is implemented, asserting that an item on the shared instant
appears in exactly one window rather than zero or two.

## Consequences

An item timestamped exactly at a period boundary belongs unambiguously to the period that begins
there, never the one that ends there — this cannot be observed as a difference from Swift in
practice, since Swift's own boundary case never occurs with real data, but it closes the latent gap
rather than porting it forward. Every new window filter added anywhere in the codebase must use
`[start, end)` and carry a boundary test; there is no case where an inclusive end is the correct
choice in this codebase.
