# 25. The save-state banner is a persistent overlay, not a snackbar

## Status

Accepted

## Context

The app needs to surface the persistence layer's save state (saving, retrying, failed) to the user.
A snackbar was the obvious off-the-shelf Flutter widget for a status message, but a snackbar is
inherently transient — it appears and dismisses itself. The save state it would represent is an
ongoing condition (a save is currently failing and retrying) that should stay visible for as long as
that condition holds, not for a fixed few seconds.

## Decision

The save-state indicator is a root-level overlay layer, driven directly by the persistence layer's
reported save-banner state, staying visible for exactly as long as that state is non-clear.

## Consequences

A user backgrounding the app mid-retry, then returning, still sees the retry state reflected
accurately — nothing timed it out while they were away. Any future save-state UI must continue
reading directly from the store's reported state rather than any timed or dismiss-on-tap widget
pattern; a snackbar-style widget would silently reintroduce the "message disappears while the
underlying problem is still happening" gap this decision closes.
