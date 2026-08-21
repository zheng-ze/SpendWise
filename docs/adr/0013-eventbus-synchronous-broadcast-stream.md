# 13. EventBus is a synchronous broadcast stream

## Status

Accepted

## Context

Swift needed a mutex-protected map of continuations with unbounded buffers to defeat `Task`
reordering — without it, two rapid publishes could reach persistence out of order and apply an
old upsert over a newer one. Dart's single-threaded event loop gives ordering for free without
that machinery.

## Decision

The bus is a Dart broadcast `Stream` constructed with `sync: true`, so delivery happens
synchronously inside `publish`, matching Swift's synchronous yield.

**Accepted difference:** Swift buffered events published between a subscriber's `subscribe()` call
and its first `await`; a Dart broadcast stream delivers only to listeners already attached. This
loses nothing in practice because every runtime subscriber attaches before the `Ledger` exists —
the boot order is what neutralizes the gap, not a buffering mechanism.

Synchronous delivery creates a reentrancy hazard: a subscriber's handler runs inside `mutate`
itself, so a handler that tried to mutate would reenter a mutation in progress, and Dart's sync
controller throws on a reentrant `add` regardless. Neither ported subscriber does this — both
enqueue or bump a counter and nothing else — and this constraint is stated in the spec so it stays
true as the bus grows more subscribers.

## Consequences

Any future bus subscriber must not mutate the ledger from inside its handler; doing so throws at
runtime rather than deadlocking or silently reordering. A future refactor from `sync: true` to
`sync: false` would silently remove the ordering guarantee this decision relies on — that
guarantee is an implicit property of the `StreamController` configuration, not something asserted
anywhere else in the code, so it is easy to lose by a change made for an unrelated reason.
