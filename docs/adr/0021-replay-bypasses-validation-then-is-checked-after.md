# 21. Replay bypasses mutator validation, but the rebuilt state is checked afterward

## Status

Accepted (amended)

## Context

Loading a stored ledger means replaying a persisted change stream back into a `LedgerState`. Two
questions: should replay run the same validation the mutators run, and if the result should be
checked at all, when and how?

Running every mutator's validation again on every load was rejected initially: the data was already
validated once, when it was first produced by a mutator, and re-validating unconditionally on
every load risks rejecting legitimately stored data if validation is ever tightened after that data
was written.

A later adversarial review found the gap this created: `LedgerStateReplay.apply` performed *zero*
validation on load, in release or debug, so a malformed or truncated change stream (partial write,
disk corruption, cross-version schema drift) could load into a state violating every invariant with
no error at all, since debug-only asserts are stripped from release builds regardless.

## Decision

Replay itself still writes directly into the state's maps — no mutators, no field validation, no
cascades, no invariant sweep during the replay loop itself. The load-bearing consequence of this
is understood and accepted: replaying a pocket deletion does not unlink it from its parent's pocket
list, because the original mutation that produced that deletion also emitted the parent's upsert
into the same stream, and replay trusts the stream to already be internally consistent.

What changed: after the replay loop completes, the call site that builds a `LedgerState` from a
replayed stream calls `assertInvariants()` directly — not through the debug-only `assert(() {...}())`
wrapper mutators use internally — and catches whatever it throws, surfacing a real, catchable,
user-visible load error. This reuses the same invariant-checking logic every mutator already relies
on internally, rather than writing a second, parallel check.

## Consequences

A malformed or corrupted change stream now fails loudly at load time in every build, not just in
debug. A stream that is internally consistent (every deletion accompanied by whatever upserts it
implies) still loads with no re-validation cost beyond the one invariant sweep at the end. Any
future persistence bug that could produce a stream inconsistent with the invariants is caught at
load time as a real error, rather than loading silently into a broken in-memory state.
