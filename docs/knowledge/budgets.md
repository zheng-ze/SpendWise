# Budgets

Last reconciled: 2026-10-27

## Feature overview

A monthly spending cap the user sets against one category or, if unscoped, against every category.
A budget is configured as an append-only timeline of `LimitEvent`s rather than a single mutable
field, so its limit can change over time with a full history. Budgets are pure configuration; they
produce facts (entries) only indirectly, via the spend math the app layer runs against analysis.

## Key files

- `packages/domain/lib/src/budgets/budget.dart` - the `Budget` model: `categoryID`, an
  immutable `List<LimitEvent>`, and `createdAtMonth`.
- `packages/domain/lib/src/budgets/limit_event.dart` - `LimitEvent`, a `default` (changes the
  ongoing limit from a month forward) or an `override` (pins exactly one month).
- `packages/domain/lib/src/ledger_state/mutators/ledger_state_budgets.dart` - the budget mutators on
  `LedgerState`: create, update, delete, duplicate-guard, and the category sweep.
- `app/lib/ui/budgets/budget_list/` - budget list view model, form, card, and `budgets_flow.dart`.
- `app/lib/ui/budgets/budget_detail/` - detail and limit screens with their view models.
- `packages/domain/lib/src/budgets/budget_limits.dart` - `effectiveLimit(budget, month)`, the limit
  that applies to a month.
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

`AnalysisQueries.readBudgets(month:)` and `readBudgetDetail(budgetID:, displayedYear:,
selectedMonth:)` expose the two projections as memoised mixed reads (see
[ledger-runtime.md](ledger-runtime.md)). Their ids and dates are normalized before the memo identity
is formed. The budget screens do not yet consume these reads. The detail screen derives the selected
month's headline spend from `budgetCountedTotal(viewState.countedEntries)`; its twelve-month chart
uses `budgetSpend` over cached analysis items (`BudgetDetailViewState.spendSeries`,
`_BudgetDetailHeader`). `MoneyFlow` hosts `BudgetsFlow` in the Money Budgets segment
(`app/lib/ui/money/money_flow.dart`).

## Budget model

- **Uniqueness.** At most one budget per category, and at most one unscoped (no-category) budget at
  a time. Creating a budget on a category that already has one, or a second unscoped budget, is
  rejected with `CategoryAlreadyBudgeted`. (`ledger_state_budgets.dart` `_validateCategoryUniqueness`)
- **Starting limit.** `addBudget` seeds the budget with a single `defaultLimit` event whose
  `effectiveFromMonth` is null, so the starting limit applies retroactively to every past month for
  its category, with no earliest month enforced, so activity recorded before the budget existed
  still counts against it.
- **`LimitEvent` timeline.** `default` events change the ongoing limit from their month forward;
  `override` events pin exactly one month. The timeline is append-only; updates append a new event
  rather than rewriting history.
- **Category scope.** A budget names a single category or none (covers every category). A category's
  parent rollup and single-nullable scope are inherent to the model.

## Mutators - `ledger_state_budgets.dart`

All amounts are `Decimal`; all reject `<= 0` with `ZeroAmount`.

- **`addBudget(String? categoryID, Decimal initialAmount, {required DateTime now})`** - validates the
  category reference (`UnknownCategory` for missing, `InactiveReference` for inactive; null is the
  unscoped slot), then uniqueness (`CategoryAlreadyBudgeted` when a budget already exists for that
  category or the no-category slot). Builds a `Budget` whose first event is a `defaultLimit`
  `LimitEvent(effectiveFromMonth: null, value: initialAmount)` and returns `[UpsertBudget(budget)]`.
- **`updateBudgetAmount(String rawBudgetID, Decimal newAmount, YearMonth effectiveFromMonth)`** -
  throws `UnknownBudget` on a missing id, then appends a `defaultLimit` event
  (`LimitEvent(effectiveFromMonth: effectiveFromMonth, value: newAmount, kind: defaultLimit)`)
  and returns `[UpsertBudget(updated)]`.
- **`setBudgetMonthOverride(String rawBudgetID, YearMonth month, Decimal value)`** - throws
  `UnknownBudget`, then appends an `override` event and returns `[UpsertBudget(updated)]`.
- **`deleteBudget(String rawID)`** - hard delete, no tombstone: plans are regenerable config and so
  are budgets. Normalizes the id; a missing id returns `[]`, else `[DeleteBudget(id)]`.
- **`_removeBudgetCategorized(categoryID)`** - removes every budget for a category; wired only for a
  future category-delete cascade, not yet called.

**Append-only timeline.** `addBudget`/`updateBudgetAmount`/`setBudgetMonthOverride` append a new
`LimitEvent` via `_appendEvent`; no mutator rewrites an existing event. `LimitEvent`
(`budgets/limit_event.dart`) carries a `LimitEventKind` (`defaultLimit` / `override`, explicit
codes 0/1), a `Decimal value`, and a nullable `YearMonth? effectiveFromMonth` (null for the ongoing
`default`, a specific month for an `override`).

## Spend math (app layer)

`budgetCountsItem` is the shared predicate for analysis items that count against a budget for a month:
items dated in the month's half-open window whose kind is expense. An unscoped budget matches every
such item. A category budget matches items whose bucket is its category or a direct child of it.
`budgetItems` selects items with this predicate, `budgetSpend` sums them, and `monthExpenseSpend`
sums every expense item in the month. There is no rollover and no threshold logic in the spend math.
The budget form is create-only: the limit is edited by
appending events, not by editing an existing one in place.

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

`BudgetDetailNotifier` computes `countedEntries` from its current ledger state for the selected month
and rebuilds them when the ledger, analysis cache, selected month, or displayed year changes. The
headline spend is the fold of this same list, and remaining is the effective limit minus that spend.
The displayed entries and selected-month total therefore reconcile by construction, including
transfers treated as expenses. The twelve-month chart continues to use cached analysis items through
`budgetSpend`. (`budget_detail_view_model.dart`, `budget_detail_screen.dart`)

`BudgetCountedEntryList` groups rows by `startOfDayUtc(entry.date)` and displays days newest first.
Each day header shows the negative folded expense contribution for its rows. Individual `EntryRow`s
use the original transaction presentation, so a transfer can display its original positive amount
while contributing to a negative expense day total. (`budget_counted_entry_list.dart`,
`app/test/ui/budgets/budget_detail/budget_detail_rows_test.dart`)

## Provider and subscription lifetime

`budgetsListViewModelProvider` is a non-auto-disposing provider.
`budgetDetailViewModelProvider` and `budgetLimitViewModelProvider` are `autoDispose` families keyed
by budget id. (`budgets_list_view_model.dart`, `budget_detail_view_model.dart`,
`budget_limit_view_model.dart`)

`BudgetsFlow` opens manual subscriptions to the detail and limit providers before pushing
the detail route and retains them while the limit screen is above it. During normal detail closure, it waits for
`route.completed` before closing both subscriptions, keeping the providers alive through the exit
transition. It also closes subscriptions when the Flow is disposed or another budget is opened.
The completion callback checks subscription identity so completion of an older route cannot close
the current budget's subscriptions. (`budget_detail_view_model.dart`, `budget_limit_view_model.dart`,
`app/lib/ui/budgets/budget_list/budgets_flow.dart`,
`app/test/ui/budgets/budget_list/budgets_flow_test.dart`)

`budgetFormViewModelProvider` is an `autoDispose` family keyed by `BudgetDraftKey`, which uses object
identity equality. Each Add sheet receives a fresh key. The Flow subscribes to that draft before presenting the sheet and releases its subscription
when the sheet's returned Future completes, when another draft opens, or when the Flow is disposed.
The form watches the same key, so auto-disposal releases the draft after its listeners are gone.
The completion callback checks draft identity before releasing the subscription. Category-picker
results apply only while the initiating context is mounted and the same draft remains open.
(`budget_form.dart`, `budget_form_view_model.dart`,
`budgets_flow.dart:_openBudgetForm`, `_handleFormStep`)

## Step ownership

The list Step belongs to the list provider. `BudgetsFlow.handleStep` handles and clears it.
Detail and limit Steps belong to the open budget; form Steps and category-picker
continuations belong to the open `BudgetDraftKey`. (`budgets_flow.dart:handleStep`,
`_handleDetailStep`, `_handleLimitStep`, `_handleFormStep`,
`app/test/ui/budgets/budget_list/budgets_flow_test.dart`)

## Overview projection

`budgetsOverview` builds the Budgets overview for one month.

- **All spending cap.** If an unscoped budget exists, the cap is its effective limit for the month.
  Otherwise the cap is the sum of the effective limits of configured category budgets whose parent
  category has no configured budget. With neither, the cap is null.
- **Spent so far.** All expense items in the month, regardless of any budget scope.
- **Daily pace.** Remaining allowance (cap minus spent, floored at zero) divided by the number of
  calendar days after today, at a scale of 12 digits. It is null when there is no cap, when today is
  not in the selected month, or when no days remain after today.
- **Ranking.** Category budgets sort by exact spend/limit descending, compared by cross
  multiplication rather than a rounded ratio. Ties break by trimmed, lowercased category name, then by
  normalized budget id.
- **Failure.** A budget with no applicable limit event, a nonpositive limit, or a missing category
  makes the read fail rather than returning a partial overview.

## Budgets list

`BudgetsRoot` reads `budgetsListViewModelProvider`, which watches the current effective month,
`todayProvider`, chart-colour preference, and `AnalysisQueries.readBudgets`. The query result supplies
the `BudgetsOverview` and category card data; the list view model maps category names, spend, limits,
remaining amounts, and utilization into presentation rows. The summary and category cards therefore
reflect the same overview projection. A failed query uses the analysis cache failure when available,
otherwise it surfaces an exception from recomputing the overview. `BudgetListError` owns the visible
retry action, which calls `AnalysisQueries.retry`. (`budgets_list_view.dart`,
`budgets_list_view_model.dart`, `analysis_queries.dart`)

The list has an **All spending** tray followed by **Category budgets**, whose individual category
trays are ranked by the overview's spend-to-limit utilization order. An unscoped budget makes the All
spending summary tappable to open its detail; category trays open their matching budget details.
Category cards include their parent name when scoped to a child category. Open layout uses two
columns for multiple category trays and one column for a single tray; phone and desktop use one
column. When an Add sheet is already presented in the open layout, category trays return to one
column and the list hides its Add button. (`budgets_list_view.dart`,
`budgets_list_view_model.dart`, `budget_overview.dart`)

Add budget is available from the empty-state action, from a compact labelled floating button when
budgets exist on phone/open layouts, and from a button above the list on desktop. The list reserves
scroll space for the floating button. The former list swipe-to-delete action and `ExpandingFab` are
removed; budget deletion remains a domain mutator but has no action in this list. (`budgets_list_view.dart`,
`budgets_list_view_model.dart`; `app/lib/ui/common/navigation/expanding_fab.dart` was removed)

## Detail projection

`budgetDetail` returns twelve month slots for the displayed year. Each slot carries the month's spend,
effective limit, whether an override pins that month, the matching record count, and the period
completeness. The summary reports the selected month's spend and limit along with the budget's
category and creation month. An unknown budget id yields a detail with a null summary and no slots.

## Gotchas and invariants

- Budget spend math is deliberately outside the domain; a domain change must not introduce it.
- Deleting a budget removes the row entirely - no tombstone, no restore.
- There is no rollover in the budget model or the spend math.
- The overview cap counts a category budget only when its parent category has no budget of its own, so a parent and its child are never added together.

## Requirements

- At most one budget per category and one unscoped budget at a time; duplicates are rejected.
  (`ledger_state_budgets.dart`)
- A budget's starting limit applies to every past month for its category.
- Limit changes are append-only `LimitEvent`s; a `default` moves the ongoing limit forward and an
  `override` pins one month.
- Spend math stays in the app layer.
- Budget delete is a hard delete with no tombstone.
- `addBudget` rejects `CategoryAlreadyBudgeted`/`UnknownCategory`/`InactiveReference`/`ZeroAmount`;
  `updateBudgetAmount`/`setBudgetMonthOverride` throw `UnknownBudget`. (`ledger_state_budgets.dart`)
- The limit timeline is append-only; `defaultLimit` moves the ongoing limit, `override` pins one
  month. (`budgets/limit_event.dart`, `ledger_state_budgets.dart`)
