# Domain invariants

Relevant when touching `packages/domain/lib/src/ledger_state*.dart` or anything that mutates
`LedgerState`. Not needed for UI-only or persistence-only work.

**Illegal states are unreachable; invariants only catch what slips.** `_checked` runs
`assertInvariants` inside `assert(() {...}())`, so every clause is debug-only. The state maps are
private behind `UnmodifiableMapView`, and `_detachAndTombstonePocket` is the sole remover of a
pocket row — those two are what make the bad states impossible rather than merely unlikely. Reject
rather than silently coerce: `addPocket` throws on a non-active parent, and a category's `kind` is
fixed at creation. A check that must hold in release needs a real throw, not an `assert`.

**Keep file scope small and single-purpose.** `LedgerState` is split by concern into `part` files.
Split by concern, not by symbol count.
