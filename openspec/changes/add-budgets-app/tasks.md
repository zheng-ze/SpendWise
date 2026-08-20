## 1. Schema

- [ ] 1.1 Add `Budgets` table to `app/lib/persistence/tables.dart`: `SyncedRow` mixin, `TextColumn
      categoryId` (nullable), `TextColumn limitEvents` (JSON-encoded), `IntColumn rolloverMode`,
      `TextColumn carryCap` (nullable), `TextColumn createdAtMonth`.
- [ ] 1.2 Add `Budgets` to `@DriftDatabase(tables: [...])` in `ledger_database.dart`, bump
      `schemaVersion` from `1` to `2`.
- [ ] 1.3 Run the Drift build runner to regenerate `ledger_database.g.dart` and confirm it compiles.

## 2. Mappers

- [ ] 2.1 Add `budgetFromRow`/`budgetToRow` to `app/lib/persistence/mappers.dart`, following
      `planFromRow`/`planToRow`'s shape: encode/decode `limitEvents` as JSON (`YearMonth` as
      `"YYYY-MM"`, `Decimal` as its string form, `LimitEventKind` as its int `code`), `carryCap` as
      a nullable `Decimal` string, `rolloverMode` via its `code`/`fromCode`.
- [ ] 2.2 Test round-trip encode/decode directly against `budgetFromRow`/`budgetToRow` (no
      database): a budget with one default event, one with an override appended, `carryCap` null
      and non-null, `categoryID` null (overall) and non-null.
- [ ] 2.3 Test that a malformed `limitEvents` JSON string raises a real, catchable error from the
      mapper (not a debug-only assert), matching `data-persistence`'s "unrecognized code fails
      loudly" requirement.

## 3. Store wiring

- [ ] 3.1 Add a `budgets` source to `loadChanges` in `drift_ledger_store.dart`, following the
      `plans` pattern (`live(db.budgets)`, mapped through `budgetFromRow`, emitted as
      `UpsertBudget`).
- [ ] 3.2 Add `UpsertBudget`/`DeleteBudget` cases to `_apply`'s switch, following the
      `UpsertPlan`/`DeletePlan` shape (`_bumpedVersion` + `insertOnConflictUpdate` for upsert,
      `_tombstone` for delete). `flutter analyze` should go from one known issue to zero.
- [ ] 3.3 Test (widget/integration level, matching how `drift_ledger_store_test.dart` or equivalent
      already tests plans): a budget enqueued through `DriftLedgerStore` is present after
      `flushNow()` and after a fresh `load()`; a deleted budget is absent after both.
- [ ] 3.4 Test coalescing: an upsert followed by a delete of the same budget id in one batch
      applies only the delete (matching `_coalesce`'s existing per-id last-write-wins rule, already
      generic over `targetID` — confirm it, don't reimplement it).

## 4. Ledger wiring

- [ ] 4.1 Add `addBudget`, `updateBudgetAmount`, `setBudgetMonthOverride`, `deleteBudget` to
      `app/lib/ledger/ledger.dart`, each a thin `_mutate` wrapper matching
      `addPlan`/`updatePlan`/`deletePlan`'s shape (`ledger.dart:103-110`).
- [ ] 4.2 Test each method surfaces the domain mutator's `LedgerError` through the same
      error-reporting path `updatePlan` already uses (whatever test covers that today is the
      pattern to mirror).

## 5. Spend computation

- [ ] 5.1 Add a pure function (e.g. `budgetSpend(Budget, YearMonth, List<AnalysisItem>,
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
- [ ] 5.2 Test: a budget on a category with children picks up each child's spend that month; a
      budget on a subcategory and a budget on its parent both count the same child entry
      independently (the overlap is intentional, confirmed with the user — assert both totals
      include it, not that they sum to a combined total); an overall budget sums across every
      category including uncategorized; a month with no spend returns zero, not an error.

## 6. Budgets tab on Stats

- [ ] 6.1 Replace `_StatsScreenBodyState`'s `CategoryKind _kind` field with a 3-value
      `enum _StatsTab { income, expense, budgets }` (`CategoryKind` has no value for Budgets).
      Extend `TopTabBar` titles from `['Income', 'Expense']` to `['Income', 'Expense', 'Budgets']`.
      Guard every existing `_kind`-driven site — `_setKind`, `_onTapCategory` (navigates to
      `CategoryDetailScreen`, meaningless for the Budgets tab), the `slices()` call, `StatsDonut`/
      `StatsLegend`, the total label/color ternaries, and the `CategoryKind`-typed `_EmptyState` —
      to the `income`/`expense` branches only. The Budgets branch renders a budgets list instead,
      reusing the existing `selectedMonthProvider`-driven month header.
- [ ] 6.2 Hide (or disable and force to `month`) the AppBar's `StatsRangeMode` popup
      (Monthly/Annually) whenever the Budgets tab is active, per design.md's "no year-range
      budgets" non-goal — otherwise a user can switch to Annually on the Budgets tab and see spend
      figures that don't match any budget's monthly `effectiveLimit`.
- [ ] 6.3 Add a budget card widget (new file under `app/lib/ui/stats/` or a new `app/lib/ui/budgets/`
      directory): category name/symbol (or "Overall"), effective limit for the selected month
      (`effectiveLimit(budget, month)`), spend from task 5.1, and a visual indicator when spend
      exceeds limit. Handle `ledger.state.categories[budget.categoryID]` returning null (category
      deleted since the budget was created) with a clear fallback label, matching how
      `slices.dart`'s `_slice` already falls through on a missing category, instead of crashing.
- [ ] 6.4 Add a Budgets-specific empty state ("no budgets yet, tap + to create one") for when
      `ledger.state.budgets` is empty, per the spec's "No budgets configured" scenario — the
      existing `_EmptyState` widget is `CategoryKind`-typed and isn't reusable as-is.
- [ ] 6.5 Wire a tap on a budget card and an "add" action (e.g. FAB, matching how Settings screens
      launch `plan_form.dart`) to open the budget form from group 7.

## 7. Budget form

- [ ] 7.1 Add `app/lib/ui/budgets/budget_form.dart` (create + edit modes in one widget, matching
      `plan_form.dart`'s `showModalBottomSheet` pattern): category picker (excludes categories with
      an existing budget, plus "Overall") and rollover mode selector, both create-only and shown
      read-only in edit mode; amount field; optional carry-cap field shown only when rollover mode
      is not `none`; optional override-month picker.
- [ ] 7.2 Build the category picker from `ledger.state.categories` (active, any nesting level —
      top-level and subcategories alike are budgetable), excluding categories that already carry a
      budget (from `ledger.state.budgets.values`).
- [ ] 7.3 Wire save to `addBudget`/`updateBudgetAmount`/`setBudgetMonthOverride` from group 4;
      catch `LedgerError` into an `_error` field rendered via `ErrorSection`, matching
      `plan_form.dart`'s `_error` pattern, keeping entered field values on rejection.
- [ ] 7.4 Wire delete (from the card or a form action) to `deleteBudget`.
- [ ] 7.5 Test the form's rejection path keeps entered values (widget test, matching the spec's "A
      rejected save keeps the form's entered values" scenario) — this is the one UI scenario worth
      a real widget test rather than manual verification, since it's easy to regress silently by
      resetting `TextEditingController`s on error.
- [ ] 7.6 Test the category picker excludes only already-budgeted categories, and still offers a
      subcategory even when its parent already has a budget (and vice versa) — the exclusion is
      per-category, not per-branch of the tree.

## 8. Gate

- [ ] 8.1 Run `cd packages/domain && dart format . && dart analyze && dart test` — no domain files
      change in this task list, so this should already be green; run it anyway to confirm nothing
      regressed.
- [ ] 8.2 Run `cd app && flutter analyze` — zero issues, confirming `_apply`'s switch is exhaustive
      again for real.
- [ ] 8.3 Run the full `app` test suite (`flutter test`).
- [ ] 8.4 Manually verify in a running app: create a budget, see its card update as entries are
      added in that category, set an override, delete the budget, restart the app and confirm state
      matches what was last saved.
