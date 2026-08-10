# Design — domain accounting

## Placement

`Accounting` is a namespace class of static functions in `packages/domain/lib/src/accounting.dart`,
not extension methods on `LedgerState`. Two reasons: the functions take id sets and entry lists that
callers assemble once and reuse across many calls (`analysisItems` gates every entry against one
`sourceIDs` set), and the Swift original is an `enum Accounting` namespace, so parity is free.

`NetWorth`, `AnalysisItem` and `CategoryResolution` are separate files, matching the one-type-per-file
convention the domain already follows.

## Decisions

### Category resolution replaces a double optional

Swift returns `UUID??` from `includedCategory`, where `nil` means "excluded from analysis" and
`.some(nil)` means "Uncategorized". Dart cannot express a nested optional — `String??` collapses to
`String?` — so the two outcomes would be indistinguishable.

Modelled as a sealed `CategoryResolution` with `Excluded`, `Uncategorized` and `InCategory(id)`. This
is the master doc's ruled approach for the port, and the switch over it is exhaustive, so a fourth
outcome cannot be added without every call site failing to compile.

### Window filters are half-open

**Sanctioned deviation.** Foundation's `DateInterval.contains` is closed at both ends, so an item
timestamped exactly on a month boundary counts in both the month that ends there and the month that
begins there. Real entries never land on an exact boundary instant, so the double-count was latent in
Swift rather than observed.

The port rules all window filters half-open `[start, end)`, and this is the module where that rule
first meets a Swift closed interval. A boundary test is required, not optional: an item on the shared
instant must appear in exactly one window.

### The gate takes the existence set, not the active set

`applies` is called with every key of `moneySources`, archived and reference-only rows included. This
is easy to get wrong in the direction of "archived things shouldn't count", which would be a real
behavior change: archiving an account would silently rewrite the *counterparty's* transfer history,
because a transfer only counts when both endpoints are in the set.

Archiving is filtered at the net worth level instead — the active-lifecycle gate lives there, on the
accounts being summed, not in the entry gate underneath. The two `deleted…UnappliesTransferToSurvivor`
scenarios pin the other half: a holder removed from the map entirely *does* un-apply its transfers.

Distinct from this, `accountTotal` takes a separate `activePockets` set precisely because pockets are
gated on lifecycle where entries are not.

### Net worth splits by sign, not by type

An overdrawn debit account is a liability; a credit card in credit is an asset. The account type is
never consulted. A zero total contributes nothing either way — it is grouped with the asset branch,
which is arithmetically identical to skipping it.

### `fraction` returns `double`, deliberately

`double` in `packages/domain/lib/` is a defect for money — but `fraction` is not money. It returns a
pie-slice ratio consumed by presentation code, and the domain money values feeding it stay `Decimal`
throughout. The conversion happens once, at the end, on a dimensionless ratio.

The guard is `over <= 0 → 0.0`, which covers both an empty total and a pathological negative one.
Anything else would divide by zero or return a negative slice.

### Kind is decided before the absolute value

`classify` reads the sign of the entry's **stored** amount to pick income versus expense, then stores
`abs(amount)` on the item. Taking the absolute value first would make every item income. The two
steps are ordered and the ordering is the whole content of the rule.

### Self-transfers are legal and the treat-as-expense flag is symmetric

**Deliberate behavior change, made during Phase 2 at the user's ruling.** Not a port bug, and not
Phase 6 parity work.

The motivating transaction is a Singapore PayNow to yourself: it deducts from an account and credits
the same account, appears on the bank statement, and so has to be recordable. Two defects blocked it.

1. `_validated` threw `selfTransfer` when `destinationID == sourceID`. That throw is removed and the
   `SelfTransfer` error case is deleted outright. Its `_case` string only ever fed `toString()`, so
   nothing persists it and Phase 4 is unaffected.
2. `classify` read `incomingTransfersAsExpenses` off the **destination only** and emitted at most one
   expense item. The outgoing leg did not exist. The user's ruling states the flag symmetrically: a
   transfer **in** to a flagged holder is an expense, a transfer **out of** one is income. Each leg
   reads the flag off its own end, so both, one or neither may fire.

The symmetry is what makes a self-transfer net to zero in analysis, matching the zero it already nets
in `balance`. There is deliberately **no** `sourceID == destinationID` branch; adding one would be
redundant and would break the flagged-to-flagged case below.

`classify` returns `List<AnalysisItem>` rather than `AnalysisItem?` because of that flagged-to-flagged
case: a transfer between two flagged holders emits an expense on the destination and an income on the
source, two genuine items on two different holders. A nullable single item cannot express it, and
collapsing them would silently drop both. Every case that previously returned `null` now returns an
empty list; the sole caller `analysisItems` changed from a null-aware spread to a plain spread.

Account-type bucketing for treat-as-expense transfers stays deferred to Phase 6. `bucketID` remains
`null` on both legs.

### Public `Accounting` entry points canonicalize caller-supplied ids

Every public query in `ledger_state_queries.dart` already canonicalizes its `raw…ID` parameter, and
`Accounting` was the outlier. The failure mode is silent rather than loud: a non-canonical id misses
the map or the set, and the miss reads as a legitimate answer. `mainBucketID` returned `null`, which
is the Uncategorized bucket, so `rollUp` filed real money under Uncategorized instead of its parent.
`balance` returned zero for a holder that has entries. `filtered` and `total` matched nothing where
they should have matched the bucket. Nothing upstream repairs it, because `AnalysisItem` does not
canonicalize its `bucketID`.

The rule is therefore: a raw id crossing into `Accounting` from a caller is canonicalized at the
boundary, and any id `Accounting` returns is canonical. `mainBucketID` returns `category.parentID ??
category.id` rather than the parameter so the result comes off a stored row either way.

`buckets` on `filtered` is `Set<String?>?` where `null` is a real member, the Uncategorized bucket,
so the mapping uses `canonicalOptionalID` and `null` survives it. `total` delegates to `filtered` and
needs nothing of its own.

Three raw-id parameters are deliberately **not** canonicalized: `sourceIDs` and `activePockets` on
`accountTotal` and `netWorth`, and the `of` that `accountTotal` passes down. Each is built from
`ledger.moneySources.keys` or `ledger.activeSources`, which are canonical by construction because
every model canonicalizes its own ids. Re-canonicalizing them would mean a `toLowerCase` per member
per call on the net-worth path, which walks every account and every pocket. The `of` parameter of
`balance` is still canonicalized, since `balance` is public and callers reach it directly.

### Every `Accounting` collection return is an unmodifiable view

`analysisItems`, `filtered` and `rollUp` each built a fresh collection and handed it back mutable,
while the `analysisItems` docstring invites callers to compute once and filter cheaply. None of the
three aliases `LedgerState`, so the ledger was never reachable through them, but a cached result is
shared by construction: one consumer sorting or clearing it corrupts what another is holding.

The rule is that any collection `Accounting` returns is unmodifiable. This matches the idiom
`LedgerState` already sets with `UnmodifiableMapView` on its four tables, so callers meet one
convention across the domain rather than having to remember which returns are safe to keep.

`UnmodifiableListView`/`UnmodifiableMapView` wrap; `List.unmodifiable`/`Map.unmodifiable` copy. The
wrapping forms are used because the copying forms would add an O(n) pass to exactly the
compute-once-then-filter path the docstring advertises, and the copy would buy nothing: the backing
collection is built inside the member and never escapes, so no other reference to it exists.

The views close the hole completely rather than half of it, because `AnalysisItem` is `@immutable`
with all-final fields over `String?`, `Decimal`, `DateTime` and an enum. An unmodifiable list of
mutable elements would still leak, but there is no such element here.

Chaining survives. `filtered` returns `List<AnalysisItem>`, which is what `UnmodifiableListView`
implements and what the `AnalysisItemList` extension is declared `on`, so `filtered(...).filtered(...)`
and `filtered(...).total(...)` still resolve. `total` folds without mutating, and `rollUp` iterates its
argument read-only, so both accept a view unchanged.

## Test approach

Test-first against the 33 Swift scenarios, which are the parity target. The coverage audit in
`tasks.md` records how each maps to a Dart test; no existing domain test covers any accounting
behavior, so all 33 are genuinely new.

Guards get mutation-tested: delete or invert the guard, run the suite, restore **from a file copy**
rather than `git checkout`, which reaches past the mutation to the last commit. A mutation that kills
no test is either a coverage gap or an equivalent mutant, and which one it is has to be decided before
moving on.
