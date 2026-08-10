# Add the domain accounting layer

## Why

The domain can record money but cannot yet report on it. `LedgerState` holds accounts, pockets,
entries, categories and plans, and every mutator and invariant that governs them, but nothing derives
a balance, a net worth, or a spending breakdown from that data. Balances are never stored — the spec
requires them to be recomputed from the entry log — so until these functions exist there is no way to
answer what an account holds or where money went.

This is the whole remaining scope of Phase 2. Plans, the other half of that phase, already landed as
group 8 of `complete-domain-ledger-core`. Every UI phase reads balances or the analysis breakdown, so
this blocks Phase 3 runtime and everything above it.

## What Changes

- Add `Accounting` — a namespace class of pure static functions over `LedgerState`, no stored state.
- Add the gating primitive `applies(entry, sourceIDs)`: an entry counts only when its source is in
  the set, and a transfer only when **both** endpoints are. Callers pass the *existence* set (every
  `moneySources` key, archived rows included), not the active set — a tombstoned holder is what
  un-applies an entry.
- Add `balance(of:entries:sourceIDs:)` and `accountTotal(account, entries, sourceIDs, activePockets)`.
  Archived pockets stay in `subPocketIDs` for restore but drop out of the parent total.
- Add `NetWorth{asset, liability}` and `netWorth(ledger)`, splitting **by sign of the computed total,
  not by account type**, with liability carried as a positive magnitude.
- Add `AnalysisItem` and the single gated pass `analysisItems(ledger)`, plus `classify`. Amounts on
  analysis items are always positive; the item's `kind` is decided by the sign of the stored amount
  before the absolute value is taken.
- Add `CategoryResolution` — sealed `Excluded` / `Uncategorized` / `InCategory`, replacing Swift's
  `UUID??` double optional, which Dart cannot express and which the master doc rules out.
- Add the list helpers `filtered` / `total` over `List<AnalysisItem>`, the presentation helper
  `fraction`, and the roll-up pair `mainBucketID` / `rollUp`.
- Port the 33 Swift accounting scenarios (16 from `AccountingTests`, 17 from
  `AccountingAnalysisTests`), plus the half-open boundary test the port's window rule requires.

Not **BREAKING**: this is additive. No existing model, mutator, query or invariant changes.

## Capabilities

### New Capabilities

- `ledger-accounting`: derived money math over a ledger — the entry gate, holder balances, account
  totals, and net worth.
- `ledger-analysis`: classification of entries into analysis items, category resolution, and the
  filtering, totalling and roll-up performed on the result.

### Modified Capabilities

None. Nothing already promoted into `openspec/specs/` changes behavior.

## Impact

- New code in `packages/domain/lib/src/`: `accounting.dart`, `net_worth.dart`, `analysis_item.dart`,
  `category_resolution.dart`.
- New tests in `packages/domain/test/`: `accounting_test.dart`, `accounting_analysis_test.dart`.
- Export barrel `lib/domain.dart` gains the new types.
- No change to `app/`. No new dependencies — `decimal` and `meta` are already present.
- One sanctioned deviation from Swift: window filters are half-open `[start, end)`, where Foundation's
  `DateInterval.contains` was closed on both ends. See `design.md`.
