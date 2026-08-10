# Add parity gaps and the platform pass

## Why

Phases 1–5 reproduce what V1 shipped. This phase builds the things V1 promised and never finished,
plus the two commitments it made and never honored.

Three of these were deliberately deferred rather than forgotten. Treat-as-expense transfers currently
land in the uncategorized bucket, which the earlier phases were explicitly told not to "improve" —
bucketing them properly is a feature with locked sub-decisions, not a port detail. Accessibility and
localization were budgeted as real phases this time precisely because treating them as polish is how
V1 ended up with neither.

## What Changes

- Add treat-as-expense bucketing by destination **account type** rather than the current single
  uncategorized bucket, to the locked specification: two new account types appended so existing
  stored codes stay stable, an eligibility gate restricting which types may treat transfers as
  expenses, deterministic synthetic bucket ids per type, pocket destinations resolving to their parent
  account's type, expense-only classification, and slices that carry their own name and symbol and
  are not navigable.
- Resolve the totals divergence between the transactions and stats screens, which earlier phases were
  told to leave open and route through a single call site.
- Add scope-aware transfer sign and color: a transfer leaving the viewed scope reads as a loss, one
  entering it as a gain, and one wholly inside or viewed globally stays neutral. Pocket scope counts
  the account together with its active pockets.
- Add the accessibility pass: semantics on every custom widget, a text alternative for the donut,
  and labels or custom actions for the action button, the two-column picker and the swipe actions.
- Add localization scaffolding, routing every shared format through it.
- Add adaptive rail layout polish.

Not **BREAKING** for stored data: the new account types are appended so existing codes keep their
meanings. Analysis output does change — treat-as-expense transfers move out of the uncategorized
bucket into per-type buckets, which is the point.

## Capabilities

### New Capabilities

- `treat-as-expense-buckets`: the eligibility gate, the synthetic per-type buckets, and how those
  slices present.
- `transfer-scope-display`: how a transfer's sign and color depend on the scope being viewed.
- `accessibility-and-localization`: the semantics contract for custom widgets and the localization
  routing for shared formats.

### Modified Capabilities

- `ledger-analysis`: treat-as-expense transfers gain a bucket instead of falling into uncategorized.
- `transactions-screen`: its totals adopt whichever side of the divergence ruling is taken.

## Impact

- Changes in `packages/domain/`: the account type enum gains two appended cases, and analysis
  classification gains the bucketing rule.
- Changes in `app/lib/ui/`: stats slice presentation, transaction row coloring, semantics throughout,
  and formats routed through localization.
- New dependency on `app/`: `flutter_localizations` alongside the existing `intl`.
- Existing tests change where analysis output changes; that is expected and each change should be
  visible in review rather than absorbed silently.
- The locked sub-decisions come from the V2 handover document, which the master doc records as
  authoritative for decisions while its descriptions of shipped surfaces are stale.
