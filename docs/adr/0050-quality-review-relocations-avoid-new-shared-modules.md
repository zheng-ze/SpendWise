# 50. Quality-review relocations join existing files rather than starting new shared modules

## Status

Accepted

## Context

A quality-and-architecture review pass surfaced four independent cleanups bundled into one change:
a gating gap in `Accounting.totals`, duplicated grouping logic that belonged on `Ledger`, duplicated
list-rendering widgets between two screens, and an oversized `category_detail_screen.dart`. Each
had more than one place its extracted piece could plausibly live, and the same reasoning pattern
applied to all four.

## Decision

In each case, the extracted or relocated piece was placed in the existing file or extension closest
to its actual current callers, rather than in a new shared module anticipating future reuse:

- `Accounting.totals` gained a `sourceIDs` parameter mirroring `classify`'s existing signature,
  computed by its two callers rather than internally — both callers already compute this set the
  same way `classify`'s callers do, and both call in a loop, so computing it once per caller and
  passing it in avoids repeated work `totals` doing it internally would add back.
- The category-grouping logic pulled out of `Ledger.categories(kind)` moved to
  `LedgerStateQueries`, the extension that already holds comparable read-only grouping queries,
  rather than a new query-extension file.
- The shared entry-list widget replacing two near-duplicate private widgets landed next to the
  `daySections` helper it directly extends, in the transactions UI directory both of its current
  call sites already depend on — not in a new shared `widgets/` directory, since a third call site
  is only plausible, not real yet.
- Two chart-adjacent classes split out of the oversized screen moved to sibling files in the same
  directory, not a new `charts/` subdirectory, since neither is reused anywhere else yet.

## Consequences

None of these four cleanups introduced a new shared directory or abstraction layer speculatively.
If a third consumer for any of these pieces materializes later, that is the point to introduce a
shared location — not before. This keeps the fixes minimal and reversible, at the cost of leaving
each piece slightly less discoverable than it would be in a dedicated shared module, if that reuse
ever actually arrives.
