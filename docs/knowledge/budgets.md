# Budgets

Last reconciled: 2026-10-31

## Feature overview

A monthly spending cap the user sets against one category or, if unscoped, against every category.
A budget has exactly one `Decimal` limit that applies to every month, past, current and future.
Editing the limit replaces it. Budgets are pure configuration; they produce facts (entries) only
indirectly, via the spend math the app layer runs against analysis.

## Key files

- `packages/domain/lib/src/budgets/budget.dart` - the `Budget` model: `id`, nullable `categoryID`
  and the single `Decimal limit`.
- `packages/domain/lib/src/ledger_state/mutators/ledger_state_budgets.dart` - the budget mutators on
  `LedgerState`: create, update the limit, delete, duplicate-guard, and the category sweep.
- `app/lib/ui/budgets/budget_list/` - budget list view model, form, card, and `budgets_flow.dart`.
- `app/lib/ui/budgets/budget_detail/` - the detail screen, pane, view model, and
  `budget_limit_edit_sheet.dart`, the limit editor.
- `app/lib/ledger/analysis/budgets/budget_spend.dart` - the app-layer spend math: `budgetItems`,
  `budgetSpend`, `monthExpenseSpend`, and the shared `budgetCountsItem` predicate.
- `app/lib/ledger/analysis/budgets/budget_counted_entries.dart` - `BudgetCountedEntry`,
  `budgetCountedEntries`, and `budgetCountedTotal` associate counted expense contributions with
  their original entries.
- `app/lib/ui/budgets/budget_detail/budget_counted_entry_list.dart` - the day-grouped list of
  counted entries and its expense day totals.
- `app/lib/ledger/analysis/budgets/budget_overview.dart` - pure `budgetsOverview` projection (All
  spending cap, daily pace, ranked category budgets).
- `app/lib/ledger/analysis/budgets/budget_detail.dart` - pure `budgetDetail` projection with twelve
  month slots.
- `app/lib/ledger/analysis_queries.dart`, `analysis_queries_mixed_reads.dart` - `readBudgets` and
  `readBudgetDetail`.

## Module interactions

Budgets live in the domain as config and are mutated through `Ledger` like any other row, so they
participate in the normal change stream and persistence. Spend math is **not** in the domain; it
lives in the app layer under `app/lib/ledger/analysis/budgets/`, as pure functions over `LedgerState`
and `AnalysisItem`s.

`AnalysisQueries.readBudgets(month:)` supplies the Budgets overview, and
`readBudgetDetail(budgetID:, displayedYear:, selectedMonth:)` supplies the detail projection. Both are
memoised mixed reads (see [ledger-runtime.md](ledger-runtime.md)). The list view model consumes
`readBudgets`. `BudgetDetailNotifier` (`budget_detail_view_model.dart`) consumes `readBudgetDetail`
and computes the counted entries itself from the live ledger.

`MoneyFlow` hosts `BudgetsFlow` in the Money Budgets segment (`app/lib/ui/money/money_flow.dart`).
`selectedBudgetProvider` (`app/lib/ui/budgets/budget_list/budget_selection.dart`) is the single
selected-budget state, a nullable budget ID. The list writes it on a tap, `MoneyFlow` reads it to
supply the active open/desktop pane, and `BudgetsFlow` reconciles one phone detail page against it.

## Budget model

- **Uniqueness.** At most one budget per category, and at most one unscoped (no-category) budget at
  a time. Creating a budget on a category that already has one, or a second unscoped budget, is
  rejected with `CategoryAlreadyBudgeted`. (`ledger_state_budgets.dart` `_validateCategoryUniqueness`)
- **One limit.** A `Budget` holds `id`, `categoryID` and one `Decimal limit`. The limit applies to
  every month, so activity recorded before the budget existed counts against it and a changed limit
  applies to past and future months alike. No creation month, month-specific value or record of past limits
  exists.
- **Category scope.** A budget names a single category or none (covers every category). A category's
  parent rollup and single-nullable scope are inherent to the model.

## Mutators - `ledger_state_budgets.dart`

All amounts are `Decimal`; both mutators reject a limit `<= 0` with `ZeroAmount`.

- **`addBudget(String? categoryID, Decimal limit)`** - validates the category reference
  (`UnknownCategory` for missing, `InactiveReference` for inactive; null is the unscoped slot), then
  uniqueness (`CategoryAlreadyBudgeted` when a budget already exists for that category or the
  no-category slot), then the limit (`ZeroAmount`). Returns `[UpsertBudget(budget)]`.
- **`updateBudgetLimit(String rawBudgetID, Decimal limit)`** - normalizes the id, throws
  `UnknownBudget` on a missing id, then `ZeroAmount`, then replaces the limit and returns
  `[UpsertBudget(updated)]`. It always upserts.
- **`deleteBudget(String rawID)`** - hard delete, no tombstone: plans are regenerable config and so
  are budgets. Normalizes the id; a missing id returns `[]`, else `[DeleteBudget(id)]`.
- **`_removeBudgetCategorized(categoryID)`** - removes every budget for a category; wired only for a
  future category-delete cascade, not yet called.

**Invariant.** Clause 16 requires every budget's category to resolve. Clause 17
(`_assertBudgetLimitPositive`, `ledger_state_invariants_budgets.dart`) requires every stored budget to
have `limit > 0` and fails with "budget <id> has a nonpositive limit". `LedgerState.replaying` and
`Ledger.applySyncBatch` run the invariants, so load and sync apply reject a nonpositive limit.

## Spend math (app layer)

`budgetCountsItem` is the shared predicate for analysis items that count against a budget for a month:
items dated in the month's half-open window whose kind is expense. An unscoped budget matches every
such item. A category budget matches items whose bucket is its category or a direct child of it.
`budgetItems` selects items with this predicate, `budgetSpend` sums them, and `monthExpenseSpend`
sums every expense item in the month. There is no carry-over between months and no threshold logic in the spend math.
The budget form is create-only: an existing limit is edited from the budget detail through the
limit editor.

`budgetCountedEntries(budget, month, state)` calls `Accounting.classify` once for each ledger entry,
using all money-source ids. It filters the resulting items through `budgetCountsItem`, omits entries
with no matching items, and returns one `BudgetCountedEntry` per contributing entry. Each row holds
the original entry and the sum of its matching expense contributions as a `Decimal`.
`budgetCountedTotal` folds those row amounts. Classification supplies the analysis inclusion gates
and transfer reclassification; the budget projection shares the same month and category predicate
as `budgetSpend`. (`app/lib/ledger/analysis/budgets/budget_counted_entries.dart`, `budget_spend.dart`)

Transfers treated as expenses count toward an unscoped budget through their uncategorized expense
items. A transfer that produces only income contributes no row; a transfer between two flagged
accounts appears once with its expense contribution. Category-scoped budgets exclude these
uncategorized transfer items. (`app/test/ledger/analysis_budget_counted_entries_test.dart`)

## Detail rows and totals

`BudgetDetailNotifier.build` recomputes `countedEntries` synchronously from the live ledger on every
build, using `budgetCountedEntries` for the selected month. The headline spend is
`budgetCountedTotal` over those same rows, and remaining is the selected limit minus that spend, so
rows and totals reconcile by construction, including transfers treated as expenses. Rows are never
retained.

Only the asynchronous projection (the twelve month slots and the budget's one limit) is retained. While a refresh is pending or has failed, the detail keeps the last accepted projection
for the same budget, month and displayed year, and the chart may briefly lag the rows.
`BudgetDetailProjection.belongsTo` discards a retained projection when the displayed month or year
changes or the ledger instance is replaced.

The chart draws one dashed horizontal line at the budget's limit and the selected-month summary
compares spend against the same value (`BudgetDetailProjection.limit`, `_ChartTray` in
`budget_detail_content.dart`). The limit does not depend on the displayed year or the selected month.
The detail shows no limit-changes row and no chart caption.

The detail always shows the summary, the year selector and the chart. When no counted entry falls in
the selected month, only the entries section shows the empty copy, whether the budget has entries in
other months or none at all (`budgetDetailPresentation`, `budget_detail_presentation.dart`). There is
no whole-budget fresh state.

`BudgetCountedEntryList` groups rows by `startOfDayUtc(entry.date)` and displays days newest first.
Each day header shows the negative folded expense contribution for its rows. It builds its own rows
the way History does: `TransactionCell.register` inside a `SwipeRow`, with a tap that opens the entry
form for that entry id and a swipe that deletes through the live ledger. A row whose entry no longer
exists in the live state is skipped. The shared `EntryRow` is not involved. Rows use the original
transaction presentation, so a transfer can display its original positive amount while contributing
to a negative expense day total. (`budget_counted_entry_list.dart`,
`app/test/ui/budgets/budget_detail/budget_detail_rows_test.dart`)

## Provider and subscription lifetime

`budgetsListViewModelProvider` is non-autoDispose. `selectedBudgetProvider` is a non-autoDispose
notifier holding the selected budget ID or null. It watches no query. `select` sets the ID and `clear`
removes it. `budgetDetailContextProvider(budgetID)` and `budgetDetailViewModelProvider(budgetID)`
are autoDispose families.

**Selection and presentation.** A tray tap always sets `selectedBudgetProvider`. Open and desktop
present the selected budget as a pane; only phone uses a managed root detail page. Selection survives
fold and unfold. `BudgetsFlow` schedules post-frame reconciliation on selection, mode and installed
AppSheet occupancy changes, on mount and when the destination becomes active again.

`_reconcilePage` reads the current selection and mode and compares the desired phone budget with the
tracked route. An existing matching phone page remains in place when a sheet opens. Otherwise it
removes the old managed page as a presentation-only change, then pushes a new phone page only while
the Flow is active, its navigator context exists and no AppSheet remains installed or exiting.
The shared controller's last-sheet completion notification schedules reconciliation, which re-reads
selection, mode and activity before pushing. Folding therefore cannot put a new phone page above a
live sheet. Unfolding removes only the managed phone page and preserves selection.
(`app/lib/ui/budgets/budget_list/budgets_flow.dart`: `_scheduleReconcile`, `_reconcilePage`)

`_clearSelectionWhenPopped` waits for the managed route's completion. `_flowRemovedPages` exempts
Flow-owned presentation removals; a user-popped page clears selection only when the selected budget
still matches that page's budget ID. A completed old route cannot clear a different selection. Back
or swipe-back on the phone page, empty-space pane dismissal, pane Back and replacement of the ledger
instance clear selection. Flow disposal removes its tracked page after the frame and preserves
selection for a later mount. (`budgets_flow.dart`: `_removePage`, `_clearSelectionWhenPopped`,
`_removePageAfterFrame`)

**Owners.** While a selection exists, `BudgetsFlow` holds two subscriptions for that budget: the
context and the detail view model (its Steps). They open when the
selection is set, are replaced when it changes to another budget, and close when it clears. Fold and
unfold preserve them within the retained Flow. Disposal closes them, and a later Flow mount reopens
them from the retained selection. The detail view model is therefore alive for as long as a
budget is shown, and the context (month and year) survives conversion. The pane title and subtitle come
from `budgetPaneHeaderProvider` (`budget_pane.dart`), which reads the ledger and the context only;
`MoneyFlow` does not watch the detail view model. `BudgetPaneBody` is the pane's consumer of detail
state.

The pane has no Close button. Tapping empty Budgets list space outside every category and All
spending tray clears selection on open or desktop while no AppSheet is installed or exiting. The
complete tray, including padding and the All spending title, handles selection; Add actions retain
their own behavior. System Back
clears selection through a `PopScope` in `MoneyFlow` only while the destination and Budgets segment
are active on open or desktop. Covering routes pop first. Phone retains page Back.

A limit editor result applies only when the Flow is mounted, the same budget is still shown and the
ledger instance captured before the editor opened is unchanged. The single-flight `_limitEditorOpen`
flag blocks a second editor while one is open, because ledger notifications can re-emit a retained
limit Step. The flag is set only after the live limit is read, and a `try`/`finally` resets it
immediately after the editor closes, before the post-await guards, so a dropped result never leaves it
set. The editor is not tracked or removed on conversion or ledger replacement.
(`app/lib/ui/budgets/budget_list/budgets_flow.dart`, `app/lib/ui/money/money_flow.dart`,
`app/test/ui/budgets/budget_list/budgets_pane_test.dart`)

## Step ownership

The list Step belongs to the list provider. `BudgetsFlow.handleStep` handles and clears form steps.
Opening a detail is no longer a Step: a tap selects the budget, and reconciliation presents it. Detail
Steps are handled by the Flow only for the shown budget and only while the Budgets destination is
active. Pending list and detail Steps are reconsidered once when Budgets becomes active again.

`BudgetLimitEditRequested` carries no payload, so a retained Step never holds a stale limit.
`BudgetDetailNotifier.requestLimitEdit` emits it only when the budget exists. When the Flow handles
it, `_handleDetailStep` checks, in order, that the destination is active, the budget is the shown
one and a navigator context exists; if any check fails the Step stays retained. It then clears the
Step, drops it when `_limitEditorOpen` is set, and reads `liveLimit` from the live ledger at open
time, returning when the budget no longer exists. A Step retained while the destination was inactive
therefore opens the editor prefilled with the limit current when Budgets returns, not the limit at
request time. After the editor closes, the Flow calls `BudgetDetailViewModel.applyLimit`, which
ignores a null or nonpositive amount, a missing budget and an unmounted notifier, and otherwise calls
`ledger.updateBudgetLimit`. Form Steps and category-picker continuations belong to the open
`BudgetDraftKey`.
(`budgets_flow.dart:handleStep`, `_handleDetailStep`, `_handleFormStep`,
`app/test/ui/budgets/budget_list/budgets_flow_test.dart`)

## Overview projection

`budgetsOverview` builds the Budgets overview for one month.

- **All spending cap.** If an unscoped budget exists, the cap is its limit. Otherwise the cap is
  the sum of the limits of configured category budgets whose parent category has no configured
  budget. With neither, the cap is null.
- **Spent so far.** All expense items in the month, regardless of any budget scope.
- **Daily pace.** Remaining allowance (cap minus spent, floored at zero) divided by the number of
  calendar days after today, at a scale of 12 digits. It is null when there is no cap, when today is
  not in the selected month, or when no days remain after today.
- **Ranking.** Category budgets sort by exact spend/limit descending, compared by cross
  multiplication rather than a rounded ratio. Ties break by trimmed, lowercased category name, then by
  normalized budget id.
- **Failure.** A budget with a missing category makes the read fail rather than returning a partial
  overview. A nonpositive limit cannot occur because invariant clause 17 rejects it at load and
  sync apply.

## Budgets list

`BudgetsRoot` reads `budgetsListViewModelProvider`, which watches the current effective month,
`todayProvider`, chart-colour preference, and `AnalysisQueries.readBudgets`. The query result supplies
the `BudgetsOverview` and category card data; the list view model maps category names, spend, limits,
remaining amounts, and utilization into presentation rows. The summary and category cards therefore
reflect the same overview projection. A failed query surfaces `AnalysisQueryResult.failure`. `BudgetListError` owns the visible
retry action, which calls `AnalysisQueries.retry`. (`budgets_list_view.dart`,
`budgets_list_view_model.dart`, `analysis_queries.dart`)

The list has an **All spending** tray followed by **Category budgets**, whose category trays are
ranked by the overview's utilization order. Tapping the All spending tray (when an unscoped budget
exists) or a category tray selects that budget through `selectedBudgetProvider`. The selected tray uses
the selected border and fill. In open layout with a selection, the list uses one column. Otherwise open
layout uses two columns for multiple category trays, and phone and desktop use one column. While
any AppSheet is installed or exiting, the list hides its floating Add action in every mode, and in
open layout category trays use one column. This occupancy is exposed by `ShellPaneScope.sheetPresented`
name and includes nested pickers. (`budgets_list_view.dart`, `budgets_list_view_model.dart`, `budget_overview.dart`)

Add budget is available from the empty-state action, from a compact labelled floating button when
budgets exist on phone/open layouts, and from a button above the list on desktop. The list reserves
scroll space for the floating button. The former list swipe-to-delete action and `ExpandingFab` are
removed; budget deletion remains a domain mutator but has no action in this list. (`budgets_list_view.dart`,
`budgets_list_view_model.dart`; `app/lib/ui/common/navigation/expanding_fab.dart` was removed)

## Detail projection

`budgetDetail` returns twelve month slots for the displayed year. Each slot carries the month's spend,
the matching record count, and the period completeness. The summary reports the selected month's
spend and the budget's limit along with its category. An unknown budget id yields a detail with a null summary and no slots.

## Detail page and pane

In open and desktop layouts the selected budget appears in the shell's right pane. `MoneyFlow`
supplies a `ShellDetail` whose title is the budget's category name or Overall, whose subtitle is the selected
month (both from `budgetPaneHeaderProvider`), whose only header action is Edit, and whose body is
`BudgetPaneBody`, the shared `BudgetDetailContent` in one `ListView` without a second app bar. Empty list space closes the pane; the pane has no Close
control. `ShellDetail.onClose` is optional, and callers that supply it retain their Close control.
Phone shows the same content as a managed page, with its own app bar and an Edit action
with the tooltip "Edit limit". Failed detail reads show the actual reason from `AnalysisQueryResult.failure`; the detail view model
has no local fallback re-evaluation. Both Edit actions call
`requestLimitEdit`, which opens the limit editor (`showBudgetLimitEditSheet`), a modal bottom sheet
titled "Change limit" and prefilled with the current limit; saving replaces the limit. The editor is
a legacy `showModalBottomSheet`, not an `AppSheet`, until #425 replaces the Edit action with the
action sheet. The deleted-budget frame remains the "Budget deleted" text until #425. (`budget_detail_content.dart`,
`budget_detail_screen.dart`, `app/lib/ui/money/money_flow.dart`)

## Sheet coverage

`ShellPaneHost` shifts the current budget detail into the left column whenever a shell-covering
AppSheet is installed or exiting on open or desktop. Its stable page isolation wrappers hide the
list from focus, semantics and pointers while retaining Money, Budgets and Accounts Flows and their
Navigators. The detail keeps its keyed State through shifting. Clearing selection removes that
detail and exposes the list; restoring selection shifts the current detail, including a different
budget, while the sheet and draft remain. Inactive Money segments supply no budget pane.
(`app/lib/ui/shell/shell_pane_host.dart`, `app/lib/ui/money/money_flow.dart`)

`ShellSheetOccupancy` distinguishes any installed/exiting sheet from shell coverage.
Each route records its predecessor through `didChangePrevious` and
`nearestNonSheetPredecessor` skips nested AppSheets. Registration lasts from installation through
`route.completed`; frame-coalesced occupancy restores the layout on the next build. Desktop
sheets always dock like open, using the route's own `MediaQuery` and the shared geometry after the
sidebar and safe insets; desktop presentation and input behavior remain desktop.
(`app/lib/ui/common/sheets/app_sheet_route.dart`,
`app/lib/ui/shell/shell_sheet_occupancy.dart`, `app/lib/ui/shell/shell_pane_geometry.dart`)

The limit editor is a modal bottom sheet over the shell, so it does not use `ShellSheetOccupancy` and
does not shift the pane. A sheet over a foreground root page leaves the shell unshifted, which
`app/test/ui/shell/shell_sheet_occupancy_test.dart` covers independently of Budgets. Future #425 sheets
must dismiss through their mounted route context or captured exact route, because the retained
Flow's `navigatorContext` can target another Navigator. For an action-sheet-to-editor sequence,
install the next loading route from the previous route's completion continuation before awaiting
initialization. The shared controller coalesces layout updates; it adds no timer or pane ownership to
hide an asynchronous gap. (`budgets_flow.dart`: `_handleDetailStep`, `_handleFormStep`,
`app/lib/ui/common/sheets/app_sheet_route.dart`: `showAppSheet`, `AppSheetRoute`)

## Gotchas and invariants

- Budget spend math is deliberately outside the domain; a domain change must not introduce it.
- Deleting a budget removes the row entirely - no tombstone, no restore.
- Each month stands alone: spend compares to the one limit with no carry-over between months.
- The overview cap counts a category budget only when its parent category has no budget of its own, so a parent and its child are never added together.

## Requirements

- At most one budget per category and one unscoped budget at a time; duplicates are rejected.
  (`ledger_state_budgets.dart`)
- A budget has one limit that applies to every month, past, current and future; editing it replaces
  the value.
- Spend math stays in the app layer.
- Budget delete is a hard delete with no tombstone.
- `addBudget` rejects `CategoryAlreadyBudgeted`/`UnknownCategory`/`InactiveReference`/`ZeroAmount`;
  `updateBudgetLimit` throws `UnknownBudget` or `ZeroAmount`. (`ledger_state_budgets.dart`)
- Invariant clause 17: every stored budget has `limit > 0`.
  (`ledger_state_invariants_budgets.dart`)
- `BudgetLimitEditRequested` is payload-free and `BudgetsFlow` reads `liveLimit` when it opens the
  editor, with a single-flight `_limitEditorOpen` flag reset in a `finally`.
  (`budgets_flow.dart:_handleDetailStep`)
