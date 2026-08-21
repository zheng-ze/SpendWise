# 35. Stored English entry names stay as written; they are not retroactively localized

## Status

Accepted

## Context

"Opening balance" and "Balance adjustment" are entry **names** — free text stored as data on the
entry row, not UI chrome. Localization scaffolding, whenever it is built, can translate UI strings
going forward, but it cannot retroactively translate text that is already written into a user's
stored ledger data. The port's schema already marks these entries structurally (excluded from
analysis), which is what would let a future display-time naming scheme take over without needing to
rewrite any stored row.

## Decision

These two persisted strings stay exactly as they are; this phase does not rewrite them, and no
localization pass reaches into already-stored data to translate them.

## Consequences

A user's existing "Opening balance" and "Balance adjustment" entries display in English regardless
of the device's locale, indefinitely, unless a future change adds a structural marker plus
display-time naming that reads the marker instead of the stored string. Any future localization work
must treat these two entry kinds as a naming problem to solve at display time using the existing
structural marker, not as a migration that rewrites stored entry names.
