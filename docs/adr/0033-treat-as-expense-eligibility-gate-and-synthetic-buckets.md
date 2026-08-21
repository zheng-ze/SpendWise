# 33. Treat-as-expense eligibility is gated and forced on save; bucket ids are derived

## Status

Accepted

## Context

The treat-as-expense flag lets a transfer into certain account types count as spending in analysis
(the account represents money genuinely leaving the user's control — a loan payoff, an overdraft
draw). But not every account type makes sense for this: cash, checking, card and prepaid accounts
are everyday spending holders, and a transfer into one of those is moving money, not spending it —
counting it as an expense would double-count the eventual real purchase. Separately, spending
buckets for these reclassified transfers need an id, and inventing a stored row for something that
isn't a real category was rejected as unnecessary persisted state.

## Decision

Three linked decisions:

- **Eligibility is a gate**, not a UI-only restriction. Only account types representing money
  leaving the user's control may set the treat-as-expense flag. The flag is forced off — not merely
  hidden in the form — the moment an ineligible type is saved, because hiding the control would
  leave a stale `true` value on a holder that later becomes ineligible, and analysis would keep
  honoring a flag the UI no longer shows.
- **Bucket ids for these reclassified transfers are derived deterministically, not stored.** Each
  eligible account type gets a synthetic id computed from the type itself, so there is no migration,
  no row to keep in sync, and the same id is produced on every device without any coordination —
  which matters once ledgers sync. These synthetic buckets are not categories: they have no backing
  row, so their slices carry their own self-supplied name and symbol and are not drillable into a
  detail screen.
- **A pocket destination resolves to its parent account's type** for this gate, since a pocket has
  no type of its own. This is the only answer that keeps two transfers into the same account — one
  direct, one to its pocket — landing in the same bucket.

## Consequences

Saving an account as an ineligible type silently and permanently clears any treat-as-expense flag it
had, even if the user never touched that field in this edit — this is intentional, not a bug to
"fix" by preserving the stale flag. A future new account type must be explicitly added to the
eligibility gate; it defaults to ineligible until someone makes that call, rather than inheriting
eligibility from a similar-looking type by accident.
