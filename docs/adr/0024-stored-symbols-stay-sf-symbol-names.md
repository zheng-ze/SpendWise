# 24. Categories keep storing SF Symbol names; the icon map is presentation-only

## Status

Accepted

## Context

Categories store their icon as an SF Symbol name (a naming convention from Apple's icon system).
Flutter renders Material icons, not SF Symbols, so something has to map one to the other. Rewriting
stored category rows to hold Material icon names directly was considered implicitly and rejected:
it would break round-tripping with the native Swift app, which still reads the same on-disk data
and expects SF Symbol names.

## Decision

Categories continue to store SF Symbol names. A map from SF Symbol name to Material icon is a
presentation-layer concern only, applied at render time, and never written back to storage.

An unknown symbol name resolves to a fallback icon rather than throwing, because imported or synced
data can carry names this build has never seen in its map. A test asserts the entire known catalog
resolves to a real icon, so a missing mapping is caught at build time rather than surfacing as a
silent fallback icon in the shipped UI.

## Consequences

The stored data format for a category's icon never needs a migration when the icon catalog grows or
changes on the Flutter side — only the presentation-layer map does. Any newly added category-icon
option must be added to the SF-Symbol-to-Material map and covered by the catalog-resolves test, or
it silently falls back to the generic icon in the running app despite compiling and testing green
everywhere else.
