# 34. Transfer sign and color are scope-aware, not globally neutral

## Status

Accepted

## Context

The Swift app's later design work specified scope-aware transfer display — a transfer out of the
account currently being viewed should not read identically to a transfer into it — but that design
was never actually built; V1 shipped every transfer rendered neutrally regardless of viewing
context. This left a designed-but-missing capability on the table when the port reached the same
screens.

## Decision

A transfer's sign and color depend on the scope it is being viewed at, not on any global rule:
viewed from an account's own scope, a transfer leaving that account (or its pockets) reads as a
loss, one arriving reads as a gain, and a transfer entirely between the account and its own pockets
reads neutral, since it never left the user's control at that scope. Account scope specifically
includes the account's active pockets, so moving money into your own pocket is internal and neutral
rather than an artificial "expense."

Viewed at the pocket's own (narrower) scope, that same account-to-pocket transfer becomes a genuine
gain, since money moved into this specific pocket. Both readings are correct simultaneously; scope
is what changes, not the underlying transfer.

## Consequences

The same stored transfer can render with different sign and color depending on which screen or
scope it is viewed from — this is intentional and must not be "fixed" into a single global rendering
rule. Any future scope (a new grouping concept beyond account and pocket) that wants transfer
sign/color must define its own scope-membership rule, following the account-includes-its-pockets
precedent.
