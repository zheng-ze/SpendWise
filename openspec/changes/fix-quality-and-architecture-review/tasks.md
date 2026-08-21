## 1. Fix Accounting.totals entry gating

- [ ] 1.1 Write a domain test in `packages/domain/test/` proving the current bug: build an entry
      whose source (or transfer destination) holder has been removed from the ledger, call
      `Accounting.totals`, and assert it currently returns a nonzero contribution. Run it against
      the unfixed code and confirm it goes red for the right reason (the gate is missing, not an
      unrelated setup mistake).
- [ ] 1.2 Add a `Set<String> sourceIDs` parameter to `Accounting.totals` and gate its body with
      `applies(entry, sourceIDs)`, matching `Accounting.classify`'s existing guard exactly
      (`packages/domain/lib/src/accounting.dart:22` and `:115`).
- [ ] 1.3 Update `Accounting.totals`'s two callers to pass the existence set:
      `app/lib/ui/transactions/month_summaries.dart:136` and
      `app/lib/ui/transactions/day_sections.dart:82`.
- [ ] 1.4 Watch the test from 1.1 go green. Run `cd packages/domain && dart format . && dart
      analyze && dart test` and `cd app && flutter analyze` clean.

## 2. Relocate Ledger.categories() grouping logic

- [ ] 2.1 Write a domain test in `packages/domain/test/` for the new
      `LedgerStateQueries` method directly against a `LedgerState` (no `Ledger`/`ChangeNotifier`
      involved), covering: parent categories sorted by name, each parent's children sorted by
      name and interleaved directly after it, and archived categories excluded. Confirm this test
      cannot pass yet, since the method doesn't exist.
- [ ] 2.2 Add `categoriesGroupedByParent(CategoryKind kind)` to `LedgerStateQueries`
      (`packages/domain/lib/src/ledger_state_queries.dart`), moving the body of
      `Ledger.categories()` (`app/lib/ledger/ledger.dart:149-178`, including the `_byName`
      comparator) into it unchanged.
- [ ] 2.3 Replace `Ledger.categories(kind)`'s body with a one-line forward to
      `_state.categoriesGroupedByParent(kind)`; delete the now-unused `_byName` from `ledger.dart`.
- [ ] 2.4 Watch the test from 2.1 go green. Confirm no existing app-layer test asserting
      `Ledger.categories()`'s output changes behavior — run the existing `Ledger` test suite and
      confirm it still passes unmodified, since the public method's contract didn't change.
- [ ] 2.5 Run `cd packages/domain && dart format . && dart analyze && dart test` and
      `cd app && flutter analyze` clean.

## 3. Extract shared DaySectionedEntryList widget

- [ ] 3.1 Create `app/lib/ui/transactions/day_sectioned_entry_list.dart` with a
      `DaySectionedEntryList` widget taking `ledger`, `state`, `window`, and an entry-matching
      predicate (`bool Function(Entry)` or `Iterable<Entry> Function(LedgerState)`, whichever
      composes more directly with both call sites' existing filter expressions). Body: call
      `daySections`, render the shared empty state, then the shared `Column` of `DayHeader` +
      `EntryRow` per section — moved verbatim from `_BudgetEntryList`
      (`app/lib/ui/budgets/budget_detail_screen.dart:419-466`) and `_ScopedEntryList`
      (`app/lib/ui/stats/category_detail_screen.dart:635-676`), which are byte-identical past the
      filter step.
- [ ] 3.2 Replace `_BudgetEntryList` in `budget_detail_screen.dart` with
      `DaySectionedEntryList`, passing its existing `bucketIDs`-based predicate
      (including the `Accounting.includedInAnalysis` check and the transfer/expense-kind checks
      it currently runs inline).
- [ ] 3.3 Replace `_ScopedEntryList` in `category_detail_screen.dart` with
      `DaySectionedEntryList`, passing its existing `scopedBuckets`-based predicate.
- [ ] 3.4 Run the existing widget tests for both screens; confirm no behavior change (same
      rendered output for the same input, since this is pure extraction). Run
      `cd app && flutter analyze` clean.

## 4. Split category_detail_screen.dart

- [ ] 4.1 Extract `_TrendCard` and `_TrendCardState`
      (`app/lib/ui/stats/category_detail_screen.dart:456-634`, current line numbers — reconfirm
      after Task 3 removes `_ScopedEntryList` from this file) into
      `app/lib/ui/stats/category_trend_card.dart`, unchanged apart from adding needed imports.
- [ ] 4.2 Extract `_SubcategoryRowData`, `_SubcategoryTable`, and `_SubcategoryRow` into
      `app/lib/ui/stats/subcategory_table.dart`, unchanged apart from adding needed imports.
- [ ] 4.3 Confirm `category_detail_screen.dart` now holds only `_CategoryDetailBody`,
      `_CategoryDetailBodyState`, and `_CategoryTotals`, and check its resulting line count.
- [ ] 4.4 Deduplicate the month-tick axis label builder: replace `_monthTick`
      (now in `category_trend_card.dart`) and `_monthLabel`
      (`app/lib/ui/budgets/budget_detail_screen.dart:295-306`) with one shared function —
      place it in `category_trend_card.dart` if `budget_detail_screen.dart` can reasonably import
      from it, otherwise in a new small `app/lib/ui/stats/chart_helpers.dart` — taking the
      resolved `TextStyle`/theme value each call site already has, since one call site derives it
      from `theme` directly and the other from `context`.
- [ ] 4.5 Run the existing widget/golden tests for `category_detail_screen.dart` and
      `budget_detail_screen.dart`; confirm no rendering change. Run
      `cd app && flutter analyze` clean.

## 5. Final verification

- [ ] 5.1 Run the full gate: `cd packages/domain && dart format . && dart analyze && dart test`,
      then `cd app && flutter analyze`. Both at zero issues.
- [ ] 5.2 Confirm `docs/reviews/2026-08-21-quality-and-architecture-review.md`'s five fixes are
      all accounted for above (Fix 1 = Task 1, Fix 5 = Task 2, Fix 2 = Task 3, Fix 3+4 = Task 4).
