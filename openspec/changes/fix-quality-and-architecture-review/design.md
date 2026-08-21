## Context

Four independent fixes, bundled into one change because they came out of the same review pass.
Full detail on each is in `docs/reviews/2026-08-21-quality-and-architecture-review.md`; this
file covers only the technical decisions the review's fix descriptions left open.

## Goals / Non-Goals

**Goals:**
- Fix the `Accounting.totals` gating gap without changing its output shape or its callers'
  control flow beyond threading one new parameter.
- Make `Ledger` uniformly thin by relocating `categories(kind)`'s grouping logic, without
  changing `Ledger`'s public method signature.
- Remove the `_BudgetEntryList` / `_ScopedEntryList` duplication with one shared widget.
- Bring `category_detail_screen.dart` down from 676 lines by splitting out self-contained
  classes.

**Non-Goals:**
- Collapsing `Ledger`'s other ~25 one-line mutator wrappers into a generic `apply()` entry
  point (architecture review candidate 1). Explicitly deferred pending a decision on the
  IDE-autocomplete trade-off; not part of this change.
- Unifying `Accounting.totals` and `Accounting.classify` into one function. Their transfer-case
  output shapes differ (per-side signed items vs. one netted pair) and forcing one through the
  other is a larger change than the gating fix this proposal makes.
- Touching `daily_transactions_screen.dart`. Its sticky-header `CustomScrollView` rendering is a
  different shape from the `Column`-based duplication this change removes.

## Decisions

**`Accounting.totals` gains a `sourceIDs` parameter, mirroring `classify`'s existing signature.**
Both callers (`month_summaries.dart:136`, `day_sections.dart:82`) already have a `LedgerState`
in scope and can derive `ledger.moneySources.keys.toSet()` the same way `classify`'s callers do.
Alternative considered: compute the existence set inside `totals` itself from the `LedgerState`
parameter it already takes. Rejected — `classify` takes `sourceIDs` as an explicit parameter
specifically so callers can reuse one computed set across many calls in a loop
(`analysisItems` does this), and `totals`'s two callers are themselves called in a loop over
entries; each call recomputing the set would be needless repeated work and would also make the
two functions' signatures inconsistent for no reason.

**Grouping logic moves to `LedgerStateQueries`, not to a new file.** The extension already holds
comparable read-only queries (`activeAccounts`, `activePockets`, `sourceName`) that group,
filter, or sort ledger data the same way. A new method here follows the file's existing
convention rather than introducing a second query-extension file.

**`DaySectionedEntryList` lives in `app/lib/ui/transactions/`, next to `day_sections.dart`.**
The widget is a direct extension of `daySections`'s output (predicate in, `Column` of sections
out), and every other file that consumes `daySections` already lives under `transactions/`. This
places it with the helper it wraps rather than with either of its two call sites, since a third
call site is plausible later and neither `budgets/` nor `stats/` should own a shared widget the
other also needs.

**`_TrendCard` and the subcategory table classes move to sibling files under
`app/lib/ui/stats/`, not to a shared `charts/` or `widgets/` subdirectory.** Both are specific to
the category-detail screen's data shapes (`_CategoryTotals`, category-scoped entries) and aren't
reused elsewhere yet. Introducing a new subdirectory for two files not yet shared anywhere else
would be organizing for a reuse case that doesn't exist. If `budget_detail_screen.dart`'s
`_BudgetChart` later turns out to share enough fl_chart scaffolding with `_TrendCard` to justify
a common chart-shell abstraction (flagged as speculative in the review, not part of this change),
that's the point to introduce a shared location — not before.

**The month-tick label dedup rides inside the file-split task, not as its own task.** The two
implementations are five lines each and only worth deduplicating because the split already
creates a natural new home for one of them (`_TrendCard`'s new file). Where exactly the shared
function lands — the new trend-card file, or a small new `chart_helpers.dart` if it doesn't fit
naturally there — is decided at implementation time, not fixed here.

## Risks / Trade-offs

- **[Risk]** Threading `sourceIDs` through `totals` changes a public domain function's
  signature. → **Mitigation**: `totals` is called only from the two identified app-layer sites;
  `dart analyze`/`flutter analyze` at zero issues after the change confirms no other caller
  exists. Both are part-file-adjacent to `classify`'s existing callers, so the parameter shape to
  pass is already established.
- **[Risk]** Moving `categories(kind)`'s logic changes where a future contributor looks for it.
  → **Mitigation**: `Ledger.categories()` keeps its exact name and signature; the forward is a
  one-line, obviously-a-forward method, matching every other method on `Ledger`.
- **[Risk]** Extracting `DaySectionedEntryList` with a predicate parameter could tempt a future
  caller to stretch the predicate to cover a case the shared widget wasn't designed for (for
  example, a scope needing per-row secondary actions). → **Mitigation**: none needed now — the
  widget's contract is exactly what both current call sites need; a future mismatch is a
  future call's problem, not a reason to over-generalize the parameter now.

## Migration Plan

No data migration. No stored schema changes. Implementation order, per the review doc:

1. Fix 1 (`Accounting.totals` gating) — independent, domain-only.
2. Fix 5 (`Ledger.categories()` relocation) — independent, domain + one app-layer call site.
3. Fix 2 (`DaySectionedEntryList` extraction) — independent of 1 and 5.
4. Fix 3 + 4 (file split, carrying the month-tick dedup) — depends on Fix 2 landing first, since
   Fix 2 removes `_ScopedEntryList` from `category_detail_screen.dart` before the split.

Each fix is behavior-preserving except Fix 1's gating correction, so each can land and be
verified (`dart test`, `flutter analyze`) independently before the next starts.
