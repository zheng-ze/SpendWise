# 3. Models are immutable with hand-written value equality; no `equatable`

## Status

Accepted

## Context

Change-emission tests compare a list of `LedgerChange`s (each carrying a stored domain object) by
value, both immediately after a mutation and later in the test. If a model were mutable, a
mutator could edit an object already emitted in a change, and the test would then compare that
object to itself — passing regardless of whether the emitted value was ever correct.

## Decision

Every domain model is immutable, with a hand-written `==`/`hashCode` comparing every field.
`equatable` is deliberately not used: its `props` list is a silent-failure surface for exactly
this kind of test — a field left out of `props` still compiles, and the emission test would then
report false equality on two objects that actually differ in that field.

## Consequences

Every model needs its own written `==`/`hashCode`, so adding a field means remembering to add it
to both. In exchange, a stored object can be captured in a change payload and compared later with
confidence that neither the mutator nor anything else silently mutated it out from under the
comparison — the emission tests are checking what was actually emitted, not a live reference.
