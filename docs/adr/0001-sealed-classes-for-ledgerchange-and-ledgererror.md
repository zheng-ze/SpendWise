# 1. Sealed classes for LedgerChange and LedgerError

## Status

Accepted

## Context

The domain needs a closed vocabulary for what a mutation changed (`LedgerChange`) and why a
mutation was rejected (`LedgerError`), each with several cases and each case carrying its own
payload (an upserted object, an offending id). The change-emission tests compare whole change
lists by value, and callers need to switch over every case without a missing case compiling
silently.

## Decision

Both are modeled as a sealed base class with one final subclass per case, giving an exhaustive
`switch` and a distinct payload type per case. `LedgerError implements Exception` so it can be
thrown directly. Both hierarchies carry hand-written value `==`/`hashCode`, because tests compare
error values and whole change lists.

The `targetID` getter is declared abstract on the sealed base rather than implemented as a
`switch` in one place, so a missing case is a compile error at the point a new case is added.

`LedgerChange.upsertSource(MoneySource)` is a static factory that switches on the source variant,
standing in for Swift's `upsert(_:)` overload, which Dart cannot express.

**Alternative considered:** a single enum plus a dynamic payload field. Rejected — it loses
payload typing and makes exhaustiveness unenforceable; a new case could silently fall through a
`switch` with a default branch.

## Consequences

Every new `LedgerChange` or `LedgerError` case forces every exhaustive `switch` over it to be
updated, including `targetID`. This is the intended cost: a change or error the domain can produce
but a consumer doesn't handle is a compile error, not a runtime gap.
