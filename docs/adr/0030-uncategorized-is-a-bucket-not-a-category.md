# 30. Uncategorized is modeled as a real bucket, not an absent category

## Status

Accepted

## Context

The stats screen needs to render a slice for spending with no category. Modeling "uncategorized" as
simply the absence of a category id (a null that means "no constraint" everywhere else it appears)
would conflate two different meanings of null in the same scoping code: "this item has no category"
versus "this filter has no category constraint."

## Decision

Uncategorized is modeled as an explicit member of the same `CategoryResolution` sealed class the
domain's category-resolution decision already introduced, not as a bare null. It has no id, so it
has nothing to drill into — its row in the stats screen is deliberately not navigable, and it also
absorbs treat-as-expense transfers, which genuinely have no category to belong to.

## Consequences

Scoping and filtering code can distinguish "explicitly uncategorized" from "no category filter
applied" without a special-cased null check at every call site — the sealed class's exhaustive
`switch` handles both as distinct cases. Any future code that filters or scopes by category must
route through `CategoryResolution` rather than reintroducing a bare nullable category id, or the two
meanings of null risk being conflated again.
