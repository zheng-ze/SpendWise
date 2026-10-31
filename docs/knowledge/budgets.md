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
- `app/lib/ui/budgets/budget_list/` - budget list view model, `budget_form.dart` and its view model,
  `budget_category_picker.dart`, `budget_scope_options.dart`, card, and `budgets_flow.dart`.
- `app/lib/ui/budgets/budget_detail/` - the detail screen, pane, view model,
  `budget_edit_actions_sheet.dart`, `budget_limit_edit_sheet.dart` with
  `budget_limit_editor_view_model.dart`, and `budget_delete_confirmation.dart`.
- `app/lib/ui/budgets/budget_amount_input.dart`, `budget_sheet_presentation.dart` - the amount input
  shared by both amount sheets and the layout-mode to `AppSheetPresentation` mapping.
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
no whole-budget fresh state. The entries section always shows the selected month's label (for example
"OCT 2026 ENTRIES"), including above the empty copy, so the selected month stays visible when the
month has no entries. A month with no data draws no bar in the chart, selected or not, and the
invisible tap overlay still selects it; the month label above the empty copy is the selection cue.

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

The Edit flow is owned by one `_EditSession` (see "Edit flow and sheets"). Showing another budget or
clearing selection, replacing the ledger instance and disposing the Flow all retire the session and
remove its current sheet route.
(`app/lib/ui/budgets/budget_list/budgets_flow.dart`: `_showBudget`, `_retireEditSession`,
`app/lib/ui/money/money_flow.dart`, `app/test/ui/budgets/budget_list/budgets_pane_test.dart`)

## Step ownership

The list Step belongs to the list provider. `BudgetsFlow.handleStep` handles and clears form steps.
Opening a detail is no longer a Step: a tap selects the budget, and reconciliation presents it. Detail
Steps are handled by the Flow only for the shown budget and only while the Budgets destination is
active. Pending list and detail Steps are reconsidered once when Budgets becomes active again.

`BudgetEditRequested` replaces the former `BudgetLimitEditRequested`. It carries no payload, so a
retained Step never holds a stale limit. `BudgetDetailNotifier.requestEdit` emits it only when the
budget exists. When the Flow handles it, `_handleDetailStep` checks, in order, that the destination
is active, the budget is the shown one and a navigator context exists; if any check fails the Step
stays retained. It then clears the Step, drops it when an `_EditSession` is already open, and
returns when the live limit or the ledger is missing. A Step retained while the destination was
inactive therefore opens the Edit sheet when Budgets returns, and the limit editor reads the limit
current at that moment. The list-level `handleStep` ignores `BudgetEditRequested`,
`PickCategoryRequested`, `BudgetFormSaved` and `BudgetLimitSaved`; only `BudgetFormRequested` opens
the Add form. `BudgetsListViewModel.deleteBudget` and the former `applyLimit` hook no longer exist;
the limit editor and the detail view model write to the ledger directly. Form Steps and
category-picker continuations belong to the open `_FormSession`.
(`budgets_steps.dart`, `budgets_flow.dart`: `handleStep`, `_handleDetailStep`, `_handleFormStep`,
`app/test/ui/budgets/budget_list/budgets_flow_test.dart`)

## Add form and category picker

The Add budget form (`showBudgetFormSheet`) and the category picker (`showBudgetCategoryPickerSheet`)
are `AppSheet`s presented through `showAppSheet` with `budgetSheetPresentation`, which maps the shell
layout mode to `AppSheetPresentation.phone`, `open` or `desktop` and re-resolves it live. The form
is `AppSheetVariant.form` with `dragToDismiss` and no Cancel button.

`BudgetFormNotifier` is an autoDispose `AsyncNotifier` family keyed by `BudgetDraftKey`, a
new-identity object created per open. It builds from the live ledger and preselects
`AllSpendingChosen` unless an unscoped budget exists, in which case the scope is empty and the
Category row shows "Choose". `canSave` requires a scope and a positive parsed amount. `save` calls
`ledger.addBudget`, then emits `BudgetFormSaved`; a `LedgerError` is kept in the state. The form has
three visible states:

- **Loading** - a spinner and "Loading" while the notifier builds.
- **Load error** - an error alert with the reason and a "Try again" primary button, which calls
  `retry` (`ref.invalidateSelf`). The provider's own auto-retry is disabled.
- **Save failure** - the loaded form stays open with an error alert built from
  `friendlyLedgerErrorMessage`.

`BudgetScopeChoice` is a sealed type with `AllSpendingChosen` (category ID null) and
`CategoryChosen(categoryID)`; both define value equality. `budgetScopeOptions(LedgerState)` lists
All spending first, then active expense categories as roots sorted by name, each followed by its
active children. An option is disabled when a budget already covers that scope, which mirrors the
domain uniqueness rule. The picker returns the chosen `BudgetScopeChoice`, and the Flow applies it
with `applyPickedScope`.

`BudgetAmountInput` shows the limit with the label "Monthly limit / SGD". When `usesBudgetAmountPad`
is true (any presentation except desktop) it renders a read-only display and the sheet passes a
`BudgetAmountPad` (`NumberPad`) as the `inputSurface`; on desktop it renders an `AmountField` with
autofocus and no pad. The limit editor uses the same input.

`_FormSession` (in `budgets_flow.dart`) holds the `BudgetDraftKey`, the form's exact
`AppSheetRoute` and the Step subscription. `_openBudgetForm` returns immediately when a session
exists, so Add is single-flight. The session ends at `route.completed`, which closes the
subscription and clears the field, so the Flow does not accept a second Add during the exit
animation. `BudgetFormSaved` dismisses the exact form route: `pop` when the route is current,
`removeRoute` when the picker covers it, so the picker is never closed in its place. After the
picker returns, the choice applies only when the Flow is mounted, the session is still current and
the form route is still active. Flow disposal closes the subscription and drops the session.
(`budgets_flow.dart`: `_openBudgetForm`, `_handleFormStep`, `_pickScope`, `_dismissSheetRoute`,
`_endFormSession`; `budget_form.dart`, `budget_form_view_model.dart`, `budget_scope_options.dart`,
`budget_amount_input.dart`)

## Edit flow and sheets

The detail Edit action calls `requestEdit`, which opens the Edit actions sheet before anything else.
`showBudgetEditActionsSheet` is an `AppPickerSheet` titled "Edit budget" with two rows, "Change
limit" and "Delete budget", and returns a `BudgetEditAction`. Dismissing it returns null.

`_EditSession` holds the budget ID, the ledger instance captured at start, the current sheet route,
the editor subscription and a `retired` flag. `_handleDetailStep` creates it, so the session is
single-flight, and ends it in a `finally`. `_editStillValid` runs at two points: after the action
sheet returns an action, and after the delete dialog returns. It requires the Flow to be mounted, the
session not retired, the destination active, the same budget shown, the ledger instance unchanged
and the live limit still present. The change-limit path has no recheck after its await, because the
limit editor writes through its own view model. The Flow pushes the next surface (the limit editor
sheet or the delete confirmation) in the same continuation that receives the action, before any
further await, so there is no gap in which the shell uncovers the pane.

- **Change limit.** `_openLimitEditor` builds a `BudgetLimitDraftKey` (budget ID and initial limit
  read from the live ledger) and listens to `budgetLimitEditorViewModelProvider(draftKey)`. The
  sheet is an `AppSheetVariant.form` titled "Change limit" with a "Save" button and the shared
  `BudgetAmountInput`. `BudgetLimitEditorNotifier` formats the initial limit as plain text,
  `canSave` requires a positive amount, and `save` calls `ledger.updateBudgetLimit` and emits
  `BudgetLimitSaved`; a `LedgerError` stays in the state as an alert. On `BudgetLimitSaved` the Flow
  dismisses the session's exact route and clears the Step. The session ends when that route
  completes.
- **Delete.** Ownership of deletion is `BudgetDetailViewModel.deleteBudget`, which does nothing
  when the notifier is unmounted or the budget is missing and otherwise calls
  `ledger.deleteBudget`. `_confirmDelete` reads the retained title from the detail state and shows
  `showBudgetDeleteConfirmation`, an `AlertDialog` titled "Delete the <title> budget?" with the
  body "Your entries stay as they are. Only the limit is removed." and Cancel and a destructive
  Delete button. It presents through `showShellConfirmation`, a plain modal route on the root
  Navigator that `ShellSheetOccupancy` does not track, so the pane does not shift for it. After
  confirmation and a final `_editStillValid` check, the Flow calls `deleteBudget`, clears
  `selectedBudgetProvider` and reconciles the page, so a local delete leaves the detail directly.

`_retireEditSession` marks the session retired, closes the editor subscription and removes the
current sheet route after the frame ends, so removal never runs inside a provider notification or
tree finalization. It runs on a ledger instance change, when the shown budget changes or clears,
and on disposal.
(`budgets_flow.dart`: `_handleDetailStep`, `_editStillValid`, `_openLimitEditor`, `_confirmDelete`,
`_retireEditSession`; `budget_edit_actions_sheet.dart`, `budget_limit_edit_sheet.dart`,
`budget_limit_editor_view_model.dart`, `budget_delete_confirmation.dart`,
`budget_detail_view_model.dart`)

## Deleted-elsewhere state

When the shown budget disappears from the ledger without a local delete (another screen or device),
`BudgetDetailNotifier` returns `BudgetDetailPhase.deleted`. It keeps the last ready title in
`_lastTitle`, so the phone app bar and the pane header (`budgetPaneHeaderProvider`) still show the
budget's name. The body is an `EmptyState` titled "This budget was deleted" with the text "It was
removed on another screen or device." and a "Back to Budgets" action, which calls `closeDeleted`
and clears selection. The phone screen and the pane hide Edit in this state. A local delete never
renders it. `showBudgetDeleteConfirmation` returns only after the dialog route has finished its exit
animation: it awaits the dialog route's `completed`. The Navigator cannot dispose the detail page
route while the dialog above it is still popping, so awaiting that exit is required for this
ordering. `_confirmDelete` then calls `deleteBudget()`, clears selection and removes the page in the
same synchronous turn, so the detail page is gone before it can rebuild into the deleted phase.
(`budget_detail_view_model.dart`: `closeDeleted`, `BudgetDetailPhase`; `budget_detail_content.dart`,
`budget_detail_screen.dart`, `budget_pane.dart`)

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
removed; `BudgetsListViewModel.deleteBudget` was removed and budget deletion is reached only from the
detail Edit sheet. (`budgets_list_view.dart`,
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
with the tooltip "Edit". Failed detail reads show the actual reason from `AnalysisQueryResult.failure`; the detail view model
has no local fallback re-evaluation. Both Edit actions call
`requestEdit`, which opens the Edit actions sheet (see "Edit flow and sheets"). A budget removed
elsewhere shows the deleted-elsewhere state. (`budget_detail_content.dart`,
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

The Add form, category picker, Edit actions sheet and limit editor are all `AppSheet`s, so they
register with `ShellSheetOccupancy` and shift the pane. The delete confirmation is a plain modal
route and is not tracked. A sheet over a foreground root page leaves the shell unshifted, which
`app/test/ui/shell/shell_sheet_occupancy_test.dart` covers independently of Budgets. Budget sheets
dismiss through their captured exact route, because the retained Flow's `navigatorContext` can
target another Navigator. The Edit flow pushes the next surface from the action sheet's
pop-result continuation, before that route's `completed` fires, so shell occupancy stays continuous.
The shared controller adds no timer or pane ownership to hide an asynchronous gap. (`budgets_flow.dart`: `_handleDetailStep`, `_dismissSheetRoute`,
`app/lib/ui/common/sheets/app_sheet_route.dart`: `showAppSheet`, `AppSheetRoute`)

## Gotchas and invariants

- Budget spend math is deliberately outside the domain; a domain change must not introduce it.
- Deleting a budget removes the row entirely - no tombstone, no restore.
- Each month stands alone: spend compares to the one limit with no carry-over between months.
- The overview cap counts a category budget only when its parent category has no budget of its own, so a parent and its child are never added together.
- A delete confirmation dialog that is open when the ledger is replaced or the shown budget changes is not dismissed by session retirement. Its Delete then does nothing, because `_editStillValid` fails after the dialog returns. Nothing in the app can change the ledger while the dialog blocks the screen, since sync runs only on explicit calls today. Revisit this if sync becomes constant live updates.

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
- `BudgetEditRequested` is payload-free. `BudgetsFlow` runs one `_EditSession` at a time, rechecks
  `_editStillValid` after the action sheet and after the delete dialog return, and retires the
  session on budget change, ledger replacement and disposal. (`budgets_flow.dart:_handleDetailStep`)
- The Add form uses one `_FormSession` that ends at `route.completed` and dismisses its exact route.
  (`budgets_flow.dart:_openBudgetForm`)
- Budget deletion is owned by `BudgetDetailViewModel.deleteBudget` behind the budget-specific
  confirmation; the list view model has no delete.
  (`budget_detail_view_model.dart`, `budget_delete_confirmation.dart`)
