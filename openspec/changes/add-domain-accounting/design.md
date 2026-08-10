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

## Test approach

Test-first against the 33 Swift scenarios, which are the parity target. The coverage audit in
`tasks.md` records how each maps to a Dart test; no existing domain test covers any accounting
behavior, so all 33 are genuinely new.

Guards get mutation-tested: delete or invert the guard, run the suite, restore **from a file copy**
rather than `git checkout`, which reaches past the mutation to the last commit. A mutation that kills
no test is either a coverage gap or an equivalent mutant, and which one it is has to be decided before
moving on.
