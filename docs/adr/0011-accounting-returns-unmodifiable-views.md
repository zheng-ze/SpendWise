# 11. `Accounting`'s collection returns are unmodifiable views, not copies

## Status

Accepted

## Context

`Accounting.analysisItems`, `filtered` and `rollUp` each built a fresh collection and handed it
back mutable, while `analysisItems`' own docstring invites callers to compute once and filter
cheaply. None of these ever aliased `LedgerState` directly, but a cached result is shared by
construction the moment more than one consumer holds it: one consumer sorting or clearing the
returned list would corrupt what another consumer is holding.

## Decision

Every collection `Accounting` returns is wrapped in `UnmodifiableListView` or
`UnmodifiableMapView`, matching the convention `LedgerState` already applies to its own four
tables.

**Alternative considered:** `List.unmodifiable`/`Map.unmodifiable`, which copy rather than wrap.
Rejected — copying adds an O(n) pass to exactly the compute-once-then-filter path the docstring
advertises, and buys nothing here: the backing collection is built inside the member and never
escapes by another path, so no other reference to it exists for the copy to protect against.

## Consequences

Chaining still works — `filtered` returns `List<AnalysisItem>`, which is what
`UnmodifiableListView` implements, so `filtered(...).filtered(...)` and `filtered(...).total(...)`
resolve unchanged. Since `AnalysisItem` is itself immutable with all-final fields, the view closes
the mutability hole completely rather than partially — there is no mutable element inside the list
that could still leak. Any new `Accounting` function returning a collection must wrap it the same
way; a caller that needs a genuinely separate mutable copy must copy explicitly at the call site.
