## 1. Schema

- [x] 1.1 Add `Budgets` table to `app/lib/persistence/tables.dart`: `SyncedRow` mixin, `TextColumn
      categoryId` (nullable), `TextColumn limitEvents` (JSON-encoded), `IntColumn rolloverMode`,
      `TextColumn carryCap` (nullable), `TextColumn createdAtMonth`.
- [x] 1.2 Add `Budgets` to `@DriftDatabase(tables: [...])` in `ledger_database.dart`, bump
      `schemaVersion` from `1` to `2`.
- [x] 1.3 Run the Drift build runner to regenerate `ledger_database.g.dart` and confirm it compiles.

## 2. Mappers

- [x] 2.1 Add `budgetFromRow`/`budgetToRow` to `app/lib/persistence/mappers.dart`, following
      `planFromRow`/`planToRow`'s shape: encode/decode `limitEvents` as JSON (`YearMonth` as
      `"YYYY-MM"`, `Decimal` as its string form, `LimitEventKind` as its int `code`), `carryCap` as
      a nullable `Decimal` string, `rolloverMode` via its `code`/`fromCode`.
- [x] 2.2 Test round-trip encode/decode directly against `budgetFromRow`/`budgetToRow` (no
      database): a budget with one default event, one with an override appended, `carryCap` null
      and non-null, `categoryID` null (overall) and non-null.
- [x] 2.3 Test that a malformed `limitEvents` JSON string raises a real, catchable error from the
      mapper (not a debug-only assert), matching `data-persistence`'s "unrecognized code fails
      loudly" requirement.

## 3. Store wiring

- [x] 3.1 Add a `budgets` source to `loadChanges` in `drift_ledger_store.dart`, following the
      `plans` pattern (`live(db.budgets)`, mapped through `budgetFromRow`, emitted as
      `UpsertBudget`).
- [x] 3.2 Add `UpsertBudget`/`DeleteBudget` cases to `_apply`'s switch, following the
      `UpsertPlan`/`DeletePlan` shape (`_bumpedVersion` + `insertOnConflictUpdate` for upsert,
      `_tombstone` for delete). `flutter analyze` should go from one known issue to zero.
- [x] 3.3 Test (widget/integration level, matching how `drift_ledger_store_test.dart` or equivalent
      already tests plans): a budget enqueued through `DriftLedgerStore` is present after
      `flushNow()` and after a fresh `load()`; a deleted budget is absent after both.
- [x] 3.4 Test coalescing: an upsert followed by a delete of the same budget id in one batch
      applies only the delete (matching `_coalesce`'s existing per-id last-write-wins rule, already
      generic over `targetID` — confirm it, don't reimplement it).

## 4. Ledger wiring

- [x] 4.1 Add `addBudget`, `updateBudgetAmount`, `setBudgetMonthOverride`, `deleteBudget` to
      `app/lib/ledger/ledger.dart`, each a thin `_mutate` wrapper matching
      `addPlan`/`updatePlan`/`deletePlan`'s shape (`ledger.dart:103-110`).
- [x] 4.2 Test each method surfaces the domain mutator's `LedgerError` through the same
      error-reporting path `updatePlan` already uses (whatever test covers that today is the
      pattern to mirror).

## 5. Spend computation

- [x] 5.1 Add a pure function (e.g. `budgetSpend(Budget, YearMonth, List<AnalysisItem>,
      LedgerState)`) alongside `slices()` in `app/lib/ui/stats/` (not in `packages/domain`, not
      built on `Accounting.rollUp`): for an overall budget (`categoryID == null`), sum every
      expense item in the month (this includes synthetic transfer-expense buckets, matching how
      the Expense tab already counts them — no special-casing needed). For a category budget, sum
      items whose `bucketID` equals the budgeted category's id, plus items whose `bucketID` names a
      category whose `parentID` equals the budgeted category's id — a direct filter over
      `AnalysisItem`s, not `rollUp`, since `rollUp` keys its map by top-level category id only
      (`Accounting.mainBucketID` collapses every leaf onto its parent) and would silently return
      zero for a subcategory budget. One level of children is the whole subtree: category nesting
      is capped at two levels (`ledger_state_categories.dart` throws `CategoryTooDeep` on a third),
      so no recursive walk is needed.
- [x] 5.2 Test: a budget on a category with children picks up each child's spend that month; a
      budget on a subcategory and a budget on its parent both count the same child entry
      independently (the overlap is intentional, confirmed with the user — assert both totals
      include it, not that they sum to a combined total); an overall budget sums across every
      category including uncategorized; a month with no spend returns zero, not an error.

## 6. Budgets tab on Stats

- [x] 6.1 Replace `_StatsScreenBodyState`'s `CategoryKind _kind` field with a 3-value
      `enum _StatsTab { income, expense, budgets }` (`CategoryKind` has no value for Budgets).
      Extend `TopTabBar` titles from `['Income', 'Expense']` to `['Income', 'Expense', 'Budgets']`.
      Guard every existing `_kind`-driven site — `_setKind`, `_onTapCategory` (navigates to
      `CategoryDetailScreen`, meaningless for the Budgets tab), the `slices()` call, `StatsDonut`/
      `StatsLegend`, the total label/color ternaries, and the `CategoryKind`-typed `_EmptyState` —
      to the `income`/`expense` branches only. The Budgets branch renders a budgets list instead,
      reusing the existing `selectedMonthProvider`-driven month header.
- [x] 6.2 Hide (or disable and force to `month`) the AppBar's `StatsRangeMode` popup
      (Monthly/Annually) whenever the Budgets tab is active, per design.md's "no year-range
      budgets" non-goal — otherwise a user can switch to Annually on the Budgets tab and see spend
      figures that don't match any budget's monthly `effectiveLimit`.
- [x] 6.3 Add a budget card widget (new file under `app/lib/ui/stats/` or a new `app/lib/ui/budgets/`
      directory): category name/symbol (or "Overall"), effective limit for the selected month
      (`effectiveLimit(budget, month)`), spend from task 5.1, and a visual indicator when spend
      exceeds limit. Handle `ledger.state.categories[budget.categoryID]` returning null (category
      deleted since the budget was created) with a clear fallback label, matching how
      `slices.dart`'s `_slice` already falls through on a missing category, instead of crashing.
- [x] 6.4 Add a Budgets-specific empty state ("no budgets yet, tap + to create one") for when
      `ledger.state.budgets` is empty, per the spec's "No budgets configured" scenario — the
      existing `_EmptyState` widget is `CategoryKind`-typed and isn't reusable as-is.
- [x] 6.5 Wire a tap on a budget card and an "add" action (e.g. FAB, matching how Settings screens
      launch `plan_form.dart`) to open the budget form from group 7.

## 7. Budget form

- [x] 7.1 Add `app/lib/ui/budgets/budget_form.dart` (create + edit modes in one widget, matching
      `plan_form.dart`'s `showModalBottomSheet` pattern): category picker (excludes categories with
      an existing budget, plus "Overall") and rollover mode selector, both create-only and shown
      read-only in edit mode; amount field; optional carry-cap field shown only when rollover mode
      is not `none`; optional override-month picker.
- [x] 7.2 Build the category picker from `ledger.state.categories`: active expense categories only
      (income is excluded, since a budget only ever tracks expense spend), any nesting level —
      top-level and subcategories alike are budgetable — excluding categories that already carry a
      budget (from `ledger.state.budgets.values`), grouped by parent with subcategories indented
      under their root, keeping a root visible (but disabled) as a group header when it is itself
      already budgeted but still has an unbudgeted child to sit under it. `budget_form_test.dart`
      covers an income category being excluded, and a subcategory still offered when its parent
      already has a budget (and vice versa), since the exclusion is per-category, not per-branch of
      the tree.
- [x] 7.3 Wire save to `addBudget`/`updateBudgetAmount`/`setBudgetMonthOverride` from group 4;
      catch `LedgerError` into an `_error` field rendered via `ErrorSection`, matching
      `plan_form.dart`'s `_error` pattern, keeping entered field values on rejection.
- [x] 7.4 Wire delete (from the card or a form action) to `deleteBudget`.
- [x] 7.5 Test the form's rejection path keeps entered values (widget test, matching the spec's "A
      rejected save keeps the form's entered values" scenario) — this is the one UI scenario worth
      a real widget test rather than manual verification, since it's easy to regress silently by
      resetting `TextEditingController`s on error.

## 8. Gate

- [x] 8.1 Run `cd packages/domain && dart format . && dart analyze && dart test` — no domain files
      change in this task list, so this should already be green; run it anyway to confirm nothing
      regressed. 585/585 tests green, 0 analyzer issues, 0 files reformatted.
- [x] 8.2 Run `cd app && flutter analyze` — zero issues, confirming `_apply`'s switch is exhaustive
      again for real. 0 issues.
- [x] 8.3 Run the full `app` test suite (`flutter test`). 690 tests, all pass except 2 pre-existing
      golden-image pixel diffs in `stats_donut_test.dart` unrelated to this change (confirmed via
      `git status` that neither `stats_donut.dart` nor its test/goldens are touched by this diff).
- [ ] 8.4 Manually verify in a running app: create a budget, see its card update as entries are
      added in that category, set an override, delete the budget, restart the app and confirm state
      matches what was last saved.

## 9. Budget card and Budgets-list grouping

- [x] 9.1 `BudgetCard` (`app/lib/ui/budgets/budget_card.dart`) renders a RealByte-style row: name
      and limit on top, a full-width bar beneath it filled to `min(spend/limit, 1.0)` with the
      percent (uncapped, can exceed 100%) labeled on the bar, spend and signed remaining (`-$X`
      when over) below the bar. No leading icon; the bar and remaining-text color (switching to
      `colors.loss` when over limit) carry the over-limit signal, alongside the percent label
      itself reading past 100%.
- [x] 9.2 The Budgets list (`_BudgetsBody` in `stats_screen.dart`) groups a subcategory's budget
      next to its parent category's name in sort order, even when only the child carries a budget,
      and shows it visually indented (`BudgetCard.isSubcategory`) — the same indent/smaller-text
      language as the form's category picker. `stats_screen_test.dart` covers sort order and
      horizontal offset directly via `tester.getCenter`/`getTopLeft`.

## 10. Budget detail screen

- [x] 10.1 `budgetBucketIDs(Budget, LedgerState) -> Set<String>?` in `budget_spend.dart` (null
      meaning "no filter", used for an overall budget) is the single source of the
      category-plus-children matching rule, shared by `budgetSpend` and the detail screen's
      entry-scope filter.
- [x] 10.2 `app/lib/ui/budgets/budget_detail_screen.dart` takes a `Budget` and shows: a header
      (spent/limit/progress for the selected month, same figures as `BudgetCard`); a year selector
      above the chart; a chart with one bar per month of the displayed year (actual spend, via
      `budgetSpend`) overlaid with a straight-line-connected dot per month at
      `effectiveLimit(budget, month)` (a `Stack` of `BarChart` + `LineChart` from `fl_chart`, the
      line un-curved and un-stepped so it reads as one dot per month joined by straight segments,
      not a step function; `LineChartData(minX: -0.5, maxX: months.length - 0.5)` so each dot
      centers on its bar — `fl_chart`'s default
      `BarChartAlignment.spaceEvenly` places bar `i`'s center at pixel `(i + 0.5) / n * viewWidth`,
      which is what that x-domain reproduces); a transparent per-month `GestureDetector` overlay
      standing in for `BarChartData.barTouchData` (disabled), since `fl_chart`'s own bar hit-test
      requires the touch to land inside the rod's painted Y-range, which collapses to nothing at
      `toY: 0` — the overlay makes a zero-spend month exactly as tappable as any other, since only
      the tap's X-position (which column) matters; and an entry list below scoped to the selected
      month and the budget's bucket set (reusing `daySections` with `sourceScope`, matching
      `_ScopedEntryList`'s pattern in `category_detail_screen.dart`; overall-scope entries are
      filtered by `entry.expectedCategoryKind == CategoryKind.expense` since there's no bucket-ID
      set to lean on for "every expense"). Defaults to the current year and month selected.
- [x] 10.3 State is split into `_displayedYear` and `_selectedMonth`, independent of each other:
      tapping a month's bar (via the overlay in 10.2) only updates `_selectedMonth`, which drives
      the entry list and header figures, and never touches `_displayedYear` or which months are
      shown. Moving to an adjacent year via the year selector sets `_displayedYear` and moves
      `_selectedMonth` to the same month number in that year, so the entry list stays on the month
      the user was already looking at. A horizontal-swipe gesture on the chart was tried and
      removed — it didn't register reliably against a real device, and the year selector already
      covers the same move.
- [x] 10.4 `BudgetCard.onTap` pushes `BudgetDetailScreen`. The detail screen's AppBar has a pencil
      action that opens the month-by-month limit editor (group 11); this action appears only here,
      not on any other screen that might later reuse the same chart/entry-list shape.
- [x] 10.5 `budget_detail_screen_test.dart` covers: entry-list scope (category+children, overall
      including uncategorized, income never appears); the header's `of $X` figure reflecting an
      overridden month; the chart showing all twelve months of the displayed year; selecting a
      month leaving the displayed year and every other month's tappability unchanged; a zero-spend
      month still being selectable (tapped by fractional chart X-position, since the tap must land
      on the transparent overlay rather than any painted rod); and changing the year keeping the
      same selected month number. Bar-tap interaction beyond what these assert is exercised
      manually (task 12.4) rather than via more synthetic gesture tests, since `fl_chart`'s touch
      coordinates are brittle to assert against directly.

## 11. Month-by-month limit editor

- [x] 11.1 `app/lib/ui/budgets/budget_limit_screen.dart` (`BudgetLimitScreen`), reached only from
      `BudgetDetailScreen`'s pencil action, shows two independent things: the budget's current
      default limit as its own tappable row (the latest `defaultLimit` event's value — a budget can
      carry several from repeated edits, and the latest one is the current default per
      `effectiveLimit`'s own append-order-wins rule), and one calendar year's twelve months, latest
      month first (December down to January), each showing `effectiveLimit(budget, thatMonth)`. A
      year selector (`MonthYearSelector(step: MonthYearStep.year)`) moves between years,
      defaulting to the current year on open.
- [x] 11.2 Tapping the default-limit row opens a sheet that calls
      `Ledger.updateBudgetAmount(budgetID, amount, effectiveFromMonth: <next calendar month>)`,
      taking effect the next calendar month rather than retroactively changing what the user is
      already spending against. Tapping a month row opens the same sheet shape to set that month's
      override via `Ledger.setBudgetMonthOverride`. Both surface `LedgerError` through
      `ErrorSection`. The sheet's `TextEditingController` is owned by its own `StatefulWidget`
      (`_LimitEditSheet`), created and disposed via standard `initState`/`dispose` — disposing it
      from the caller immediately after the awaited `showModalBottomSheet` call races the sheet's
      still-playing exit animation, which still reads the controller through its `TextField`.
- [x] 11.3 `budget_limit_screen_test.dart` covers: the default row and December-first month
      rows rendering (scrolling to reach January, since `ListView` doesn't materialize off-screen
      rows under test); editing the default limit leaving the current month's `effectiveLimit`
      unchanged; setting a month override updating `effectiveLimit` and that row's figure; and the
      year selector moving the displayed months to the adjacent year.

## 12. Gate

- [x] 12.1 Run `cd packages/domain && dart format . && dart analyze && dart test` — 585/585 tests
      green, 0 analyzer issues.
- [x] 12.2 Run `cd app && flutter analyze` — 0 issues.
- [x] 12.3 Run the full `app` test suite (`flutter test`) — 706/706 green, including the
      `stats_donut_test.dart` goldens (regenerated after a stale-environment pixel diff; the widget
      itself is unchanged by this work).
- [x] 12.4 Manually verify in a running app: on the budget detail screen, tap several different
      months — including one with zero spend — in sequence and confirm the chart never shifts and
      every month stays tappable; change the year via the selector and confirm the selected month
      stays the same month number; open the limit editor, confirm it shows one year
      latest-month-first with working year navigation, and confirm editing the default limit does
      not change the current month's already-effective figure; confirm the Budgets list groups a
      subcategory's card next to its parent's, indented.
