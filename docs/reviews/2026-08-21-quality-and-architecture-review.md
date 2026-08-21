# Quality and architecture review — 2026-08-21

This review covers two passes over the whole codebase: a strict code-quality audit
(`thermo-nuclear-code-quality-review`) and a module-depth audit
(`improve-codebase-architecture`, Pocock methodology). Both ran for the first time on this repo.
This document is the fix brief for the five items selected to act on: Pocock candidates 1, 2, 3,
and 5, plus the `Accounting.totals`/`Accounting.classify` drift found by the quality audit. The
`SwipeToDeleteRow.itemName` finding the quality-audit subagent raised did not hold up on
inspection and is dropped.

## Fix 1 — Accounting.totals skips the applies() existence check

**File:** `packages/domain/lib/src/accounting.dart`

`Accounting.classify` (line 115) and `Accounting.totals` (line 179) both branch on
`entry.kind` to turn one `Entry` into its income/expense contribution, but their guard clauses
differ:

- `classify` requires `applies(entry, sourceIDs) && entry.includeInAnalysis`.
- `totals` requires only `entry.includeInAnalysis`.

`applies` (line 22) checks that an entry's source id, and its destination id if the entry is a
transfer, both still exist in the current money-source set. An id stops existing when its holder
is deleted (archiving does not remove it, only deletion does — see the doc comment on
`applies`). `totals` skipping this check means an entry referencing a deleted holder still
contributes to income/expense totals, while the same entry is correctly excluded from
`classify`'s per-bucket breakdown. The two numbers can disagree for the same window.

`totals` has two more callers that run it over unfiltered entry sets: `month_summaries.dart:136`
and `day_sections.dart:82`. Neither pre-filters with `applies` before calling `totals`, so the gap
is live, not theoretical.

**Fix:** add the same `applies` guard to `totals`, matching `classify`'s condition exactly. This
needs `sourceIDs` threaded into `totals`'s signature (currently it takes only `entry` and
`ledger`) — check both call sites can supply it from data they already have (`ledger.moneySources.keys.toSet()`,
the same expression `classify`'s callers use).

**Not in scope:** collapsing `totals` into a derivation of `classify`'s output. The two functions
compute genuinely different shapes on the transfer branch (`classify` treats each side of a
transfer as a separate signed `AnalysisItem`; `totals` nets both sides into one signed pair) and
forcing one through the other risks changing behavior beyond the bug fix. Fix the guard mismatch
only; note the deeper unification as a follow-up if it's still wanted after this lands.

## Fix 2 — Merge the duplicated scoped-entry-list widget

**Files:**
- `app/lib/ui/budgets/budget_detail_screen.dart:419-466` (`_BudgetEntryList`)
- `app/lib/ui/stats/category_detail_screen.dart:635-676` (`_ScopedEntryList`)
- `app/lib/ui/transactions/day_sections.dart` (existing shared helper, unchanged)

Correction to the original architecture-review finding: this is a two-way duplication, not
three-way. `daily_transactions_screen.dart` was also named in the first pass, but it renders
through `CustomScrollView` with `SliverPersistentHeader`/sticky day headers (`_DailyContent`,
`daily_transactions_screen.dart:255-300`), a materially different rendering strategy from the flat
`Column` the other two use. It stays out of this fix.

`_BudgetEntryList` and `_ScopedEntryList` are otherwise identical after filtering: both call
`daySections(matching, state, interval: window)`, both render the same empty state
(`Padding` + centered `'No entries in this period'`), and both build the same
`Column` of `DayHeader` + `EntryRow` per section. They differ only in the filter predicate
(`_BudgetEntryList` matches by `bucketIDs` against expense entries only; `_ScopedEntryList`
matches by `scopedBuckets` against any non-transfer entry) and the empty-state trigger.

**Fix:** extract a shared widget — for example `DaySectionedEntryList` — that takes the entry
predicate as a parameter and owns the `daySections` call, empty state, and `Column` build. Place
it in `app/lib/ui/transactions/`, next to `day_sections.dart`, since it extends that helper
directly. `budget_detail_screen.dart` and `category_detail_screen.dart` each keep only their own
filter predicate and pass it in.

## Fix 3 — Split category_detail_screen.dart before it grows further

**File:** `app/lib/ui/stats/category_detail_screen.dart` (676 lines)

The largest UI file in the app, holding six classes whose only relationship is sharing one
screen: `_CategoryDetailBody`/`_CategoryDetailBodyState`, `_CategoryTotals`,
`_SubcategoryRowData`/`_SubcategoryTable`/`_SubcategoryRow`, `_TrendCard`/`_TrendCardState`,
and `_ScopedEntryList` (removed under Fix 2). `_TrendCard` (lines 456-634, about 180 lines) is
the largest single piece and is self-contained: it takes its data through constructor
parameters and doesn't reference any sibling class in the file.

No file in the codebase currently crosses 1,000 lines, so this isn't an urgent violation of the
project's own size convention, but `category_detail_screen.dart` is the file closest to it and
this is the moment to split it before the next feature lands on top.

**Fix:**
- Extract `_TrendCard` and `_TrendCardState` into their own file (for example
  `app/lib/ui/stats/category_trend_card.dart`).
- Extract `_SubcategoryRowData`, `_SubcategoryTable`, and `_SubcategoryRow` into their own file
  (for example `app/lib/ui/stats/subcategory_table.dart`), since they form one cohesive
  unit (table + row + row's data class) separate from the rest of the screen.
- Leave `_CategoryDetailBody`/`_CategoryDetailBodyState` and `_CategoryTotals` in
  `category_detail_screen.dart` as the screen's own orchestration and computation.

This fix depends on Fix 2 landing first, since Fix 2 removes `_ScopedEntryList` from this file
entirely.

## Fix 4 (bundled with Fix 3) — Deduplicate the month-tick chart label

**Files:**
- `app/lib/ui/stats/category_detail_screen.dart:553-564` (`_monthTick`)
- `app/lib/ui/budgets/budget_detail_screen.dart:295-306` (`_monthLabel`)

Both are fl_chart `AxisTitles` label builders with identical bodies: bounds-check the rounded
index against `months.length`, return `SizedBox.shrink()` if out of range, otherwise render
`formatMonthLabel(months[index]).substring(0, 3)` in `labelSmall` style with the same
`Padding`. They differ only in how each obtains a `ThemeData` (one takes `theme` directly, the
other derives it from `context`).

This duplication is small enough on its own that extracting it wouldn't be worth a dedicated
pass, but Fix 3 already moves `_TrendCard` into its own file, and `_BudgetEntryList`'s chart in
`budget_detail_screen.dart` is a natural neighbor for a shared label builder. Do this only as
part of the Fix 3 file split, not as a standalone change.

**Fix:** add a shared function, for example `monthAxisTick(TextStyle? style, List<DateTime> months, double value)`,
in whichever file ends up holding the chart-shell code shared between `_TrendCard` and
`_BudgetEntryList`'s bar chart. If no such shared chart-shell code exists yet after Fix 3, place
the function in `app/lib/ui/stats/category_trend_card.dart` and import it from
`budget_detail_screen.dart`, or in a small shared `chart_helpers.dart` if that reads more
naturally once the split is done — leave the exact placement to implementation time.

## Fix 5 — Move category grouping out of Ledger and into the domain query layer

**Files:**
- `app/lib/ledger/ledger.dart:149-178` (`categories(CategoryKind kind)`, `_byName`)
- `packages/domain/lib/src/ledger_state_queries.dart` (target file, `LedgerStateQueries` extension
  on `LedgerState`)

`Ledger` (`app/lib/ledger/ledger.dart`) is a thin forwarding layer everywhere else: every other
public method is one line, `_mutate((state) => state.methodName(args))`, hiding only the
assert/publish/notify sequence in `_mutate`. `categories()` is the one method that breaks this
shape. It does real domain work with no dependency on mutation or notification: it reads
`_state.activeCategories` and `_state.categories`, groups by `parentID`, sorts each group by
name, and interleaves each root category with its own children. This logic runs today inside a
`ChangeNotifier`, which means it can only be tested by standing one up, and it duplicates the
kind of parent/child grouping the domain's own query layer should own.

`ledger_state_queries.dart` is a `part of 'ledger_state.dart'` extension file
(`extension LedgerStateQueries on LedgerState`) that already holds comparable read-only queries
(`activeAccounts`, `activePockets`, `sourceName`, and others) — no category-grouping query exists
there yet.

**Fix:**
- Add a new method to `LedgerStateQueries`, for example
  `List<TransactionCategory> categoriesGroupedByParent(CategoryKind kind)`, moving the body of
  `Ledger.categories()` (the active-set filter, the parent/child grouping, the two sort passes,
  the interleave) into it, plus the `_byName` comparator it needs.
- Replace `Ledger.categories(kind)` with a one-line forward:
  `List<TransactionCategory> categories(CategoryKind kind) => _state.categoriesGroupedByParent(kind);`,
  making `Ledger` uniformly thin again.
- This makes the grouping logic unit-testable directly against a `LedgerState`, with no
  `ChangeNotifier` in the loop, consistent with how the rest of `packages/domain` is tested.

**Not in scope:** collapsing `Ledger`'s ~25 other one-line mutator wrappers into a single generic
`apply()` entry point (the architecture review's candidate 1). That change trades away
IDE-autocomplete discoverability across 47 call sites for a smaller `Ledger` and needs its own
explicit sign-off before implementation — it is not bundled into this batch.

## Sequencing

Fix 5 and Fix 1 are independent of everything else and of each other — either can go first.
Fix 2 has no dependency on Fix 1 or Fix 5. Fix 3 depends on Fix 2 landing first (it removes
`_ScopedEntryList` from `category_detail_screen.dart` before the file split). Fix 4 is not a
standalone change — it rides along inside Fix 3's implementation.

Suggested order: Fix 1, Fix 5, Fix 2, Fix 3 (carrying Fix 4).

## Explicitly out of scope for this batch

- Pocock candidate 1 (`Ledger`'s wrapper collapse) — flagged under Fix 5 above, needs its own
  decision on the autocomplete trade-off.
- Any change to `daily_transactions_screen.dart` — its sticky-header rendering is a different
  shape from Fix 2's target, not a third copy of the same duplication.
- Deriving `Accounting.totals` from `Accounting.classify` — Fix 1 corrects the guard mismatch
  only; a full unification of the two functions is a larger, separate decision.
