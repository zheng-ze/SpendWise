# 2. The account/pocket link stays on the parent, and the ledger's maps are closed

## Status

Accepted

## Context

A pocket needs to resolve to its owning account (for display names, cascades, and lifecycle
rules). Two shapes were available: `Account.subPocketIDs` (a list of child ids on the parent,
the shape this domain already had) or `SubPocket.parentID` (a pointer on the child, pointing the
other way). An investigation into an orphan-pocket defect — a pocket claimed by two accounts, or
surviving its parent's archival — asked whether inverting the link would remove the guard
machinery that defect required.

## Decision

Keep the link on the parent (`Account.subPocketIDs`); do not add `parentID` to `SubPocket`.

Inverting was rejected on engineering merit, not on porting-parity grounds:

- The guard does not disappear, it moves. A `parentID` on the child still needs the same
  ordered-lifecycle check `_willOutliveParentCategory` already performs for categories.
- Accounts and pockets share one id space and one table, so a bare `String parentID` on a pocket
  is not type-constrained to accounts — pocket-parented-to-pocket, self-parenting and cycles all
  become representable and would need a runtime validator, the same tax the category hierarchy
  already pays.
- `activePockets` and both lifecycle cascades are `O(children)` today under the parent-owned
  shape; inverting turns them into full table scans, and `netWorth` would go from `O(accounts)` to
  `O(accounts × sources)` unless every caller remembers to pre-group.
- There is no persistence layer yet, so this is the cheapest point at which to invert if it were
  ever going to happen — and the investigation still didn't recommend it.

The actual defect was not the link direction: it was that `_moneySources`, `_entries` and
`_categories` were handed out as mutable maps, so a direct write could bypass every guard on the
public API. All four public-API routes to an orphan active pocket were checked and found already
closed (`addPocket` onto an archived parent, `restorePocket` under one, `updatePocket` forcing
active, `updateAccount` dropping the link); only a direct map write produced one.

The fix is closing the maps: the ledger's tables are private, and the public getters return
`UnmodifiableMapView`. `_detachAndTombstonePocket` is the sole remover of a pocket row, so
detach-and-survive has no window to exist in.

## Consequences

`sourceName` still pays an `O(accounts)` scan per rendered row to build "Parent/Child" — inversion
would have made this `O(1)`, and that cost is accepted rather than solved, to be revisited only
with real measurements from the UI. "Pocket claimed by two accounts" stays representable in the
type system (a single `parentID` field could not hold two values, but two accounts can each list
the same pocket id) — it is made unreachable through the public API by the closed maps and the
sole remover, with invariant checks as the backstop, rather than made structurally impossible.
