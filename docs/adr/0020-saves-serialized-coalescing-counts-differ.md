# 20. Saves are serialized, and coalescing counts differ from applied counts on purpose

## Status

Accepted

## Context

At most one save cycle can be allowed to run at a time, even on a single-threaded Dart runtime,
because both the save itself and its backoff sleep are `await` points — a debounced save and an
explicit flush can interleave across those await points and apply the same pending prefix twice if
nothing serializes them.

Separately, at save time the pending buffer is coalesced down to the last change per target before
being applied, to avoid writing an object's earlier states when only its final state matters.

## Decision

A requested save awaits any save already in flight rather than running concurrently with it.

What gets *applied* to storage is the coalesced list (one entry per target); what gets *cleared*
from the pending buffer afterward is the raw, pre-coalesce count. Conflating the two would either
drop changes that were buffered during the save (if cleared count used the coalesced count) or
re-apply changes already durably written (if applied count were used to decide what stays pending).

## Consequences

A caller that requests a flush while a save is already running gets a save that reflects the state
at the time its own request was issued, not a partial interleaving of two saves. Any future change
to the save/coalesce pipeline must keep the "applied is coalesced, cleared is raw" distinction
intact; collapsing them into one count is the specific mistake this decision exists to prevent.
