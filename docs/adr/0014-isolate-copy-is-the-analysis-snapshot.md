# 14. The isolate's deep copy is the analysis cache's consistency snapshot

## Status

Accepted

## Context

Swift's off-main analysis recompute got a free, safe snapshot because its `LedgerState` is a value
struct — a detached task captured a copy automatically, and a concurrent mutation on the main
actor could never corrupt a computation already in flight. Dart's `LedgerState` is a mutable class
by design (see the mutator-contract convention), so a naive off-main compute reading the live
object could observe a state a concurrent mutation is actively editing.

## Decision

`Isolate.run` deep-copies the captured state on send, and that copy is treated as the
consistency-snapshot mechanism: a mutation landing mid-compute cannot corrupt the computation
already running, because that computation is working over its own copy. A mutation that lands
mid-compute instead bumps the cache's revision counter, and the follow-up refresh recomputes while
a generation guard discards any now-stale result still in flight.

Web has no isolates, so the cache computes synchronously there instead. This is still a
consistent snapshot for a different reason: nothing can interleave within a single synchronous
call on a single-threaded runtime, so the generation guard trivially passes. The platform choice
is gated behind an injected runner so tests can force either path deterministically.

## Consequences

Every analysis recompute on non-web platforms pays the cost of a full state deep-copy per
`Isolate.run` call — accepted as the price of a correct snapshot without reintroducing Swift's
value-type semantics into a class-based state. Any future change to how the cache dispatches work
off the main isolate must preserve this snapshot property; reading the live `LedgerState` directly
from another isolate would silently reintroduce the corruption risk this decision closes.
