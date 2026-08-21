# 7. Category resolution is a sealed class, not a nested optional

## Status

Accepted

## Context

Swift's `includedCategory` returns `UUID??` — a nested optional where `nil` means "excluded from
analysis entirely" and `.some(nil)` means "included, but Uncategorized". Dart cannot express a
nested optional: `String??` collapses to `String?`, so a naive translation would make "excluded"
and "Uncategorized" indistinguishable.

## Decision

Model the result as a sealed `CategoryResolution` with three cases: `Excluded`, `Uncategorized`,
and `InCategory(id)`. Every consumer switches over it exhaustively, so a fourth outcome cannot be
added without every call site failing to compile — the same exhaustiveness guarantee the
`LedgerChange`/`LedgerError` sealed hierarchies use.

This shape is reused beyond accounting: the stats screen's "uncategorized" bucket is modeled the
same way, as a real bucket rather than an absent optional, which is what keeps "uncategorized"
distinct from "no constraint" in scoping code.

## Consequences

Any future third state on category inclusion is a compile error everywhere it isn't handled, not a
silent fallthrough. The cost is one more type to reason about instead of a plain nullable string,
but that type is what makes "excluded" and "Uncategorized" reliably distinguishable in Dart, where
Swift got the distinction for free from a language feature Dart does not have.
