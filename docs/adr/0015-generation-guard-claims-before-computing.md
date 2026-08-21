# 15. The analysis cache's generation guard claims before it computes

## Status

Accepted

## Context

The analysis cache must discard a stale recompute when a newer one has since been requested,
without letting two recomputes for the same generation run concurrently.

## Decision

`lastComputed = target` is assigned synchronously, before the async compute for that generation
starts. Claiming the generation only after the compute finished (or after it started) would leave
a window where a re-entrant refresh call could start a second compute for the same generation.

The cache's initial values are deliberately mismatched: `revision` starts at 0 and `lastComputed`
starts at -1. This mismatch is what makes the very first refresh compute even though no bus event
has arrived yet — it is how state loaded at boot gets its first analysis pass, without needing a
synthetic "boot" event to trigger it.

## Consequences

A refresh call is idempotent per generation: calling it twice for the same revision only ever
launches one compute, because the second call sees the generation already claimed. Any future
change to the cache's refresh entry point must preserve claim-then-compute ordering; computing
first and claiming afterward would reopen the double-compute window this decision closes.
