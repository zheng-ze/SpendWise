# 38. A budget's limit is an append-only timeline of events, not a mutable field

## Status

Accepted

## Context

A budget needs a monthly spending limit that can change over time without corrupting the past: if a
limit is simply overwritten, resolving an already-elapsed month's limit today would pick up the new
value by mistake, since the old value is simply gone. Freezing every elapsed month into its own row
the instant the default changes would fix this, but that needs a background process to do the
freezing — and this design deliberately has no such process (see the no-resolution-step decision).

A user also needs to pin a single month to its own limit without disturbing the ongoing default —
"cap December at $200 specifically, but the general limit is still $500."

## Decision

A `Budget` keeps an ordered, append-only list of `LimitEvent`s, each either `kind: default`
(changes the ongoing limit from that month forward) or `kind: override` (pins exactly one month).
Resolving a month's effective limit is a pure fold over this list with no side effects and nothing
written: an override for that exact month wins if one exists (the last-appended override for that
month, if more than one was ever written), otherwise the latest `default` event at or before that
month applies. Only the very first event a budget is ever created with may have a null
`effectiveFromMonth` (meaning "applies to every month at or before creation, unbounded"), and it is
always `kind: default`; every event appended after that must name a real month.

An override always wins for its own month permanently, no matter what `default` edit is written
afterward — a later default-kind change never reaches into a month that already has its own
override. The only way to change an already-overridden month is to write a new override to that
same month.

## Consequences

Resolving any month's limit is cheap (a short list fold, since a budget's timeline typically has one
event per edit, not one per elapsed month), with nothing cached or recomputed in the background. An
override can never be "cleared" back to following the default — only overwritten with a new value —
which was accepted explicitly: an override pinned to the current default is a fixed snapshot at the
moment it was written, not a live link back to the default, and un-pinning a month for good means
writing a fresh override every time the default moves, not a one-time fix.
