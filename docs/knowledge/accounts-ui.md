# Accounts UI

Last reconciled: e9e21fdb

## Feature overview

The Accounts screen, hosted by the Accounts segment of Money, and its account/pocket forms.
The screen groups active accounts by type with pockets nested under their parent, shows card accounts as payable/outstanding two columns, and derives net
worth from `Accounting.netWorth`. Tapping an account row pushes the Transactions screen scoped to
that account and its pockets. Forms exist for creating accounts and pockets and for editing a source,
including posting a balance-adjustment delta entry.

## Money host

`MoneyFlow` hosts Budgets, Accounts and Plans in that order and mounts only the visible segment.
`moneySegmentProvider` is an autoDispose provider that defaults to Accounts and that `MoneyFlow`
keeps alive while it is mounted. Switching segments, or leaving the Money destination, unmounts the
previous segment and resets its state; Money opens at Accounts again after the destination is left.
`MoneyFlow` passes a `MoneyHeader` to the segment root, and each segment renders it at the top of
its own root page (`HeaderedPage`), so the header is part of the segment and a route pushed over the
root, such as a scoped Transactions screen, covers it and owns its own heading. The header shows
Money and one segmented control; only Budgets shows the month selector. Accounts supplies Add
account; Plans supplies no header action and no floating action. On open and desktop, `MoneyFlow`
resolves one `ShellPane` from the visible segment only: `budgetPaneProvider` for Budgets,
`planPaneProvider` for Plans, and none for Accounts. It passes that pane to `ShellPaneHost`, and a
`PopScope` closes it on system Back, so a segment that supplies no pane never intercepts Back.
(`app/lib/ui/money/money_flow.dart`, `app/lib/ui/money/money_header.dart`,
`app/lib/ui/money/money_segment.dart`, `app/lib/ui/budgets/budget_detail/budget_pane.dart`,
`app/lib/ui/plans/plan_detail/plan_pane.dart`, `app/lib/ui/shell/shell_pane_host.dart`, `accounts_flow.dart`,
`accounts_screen.dart`)

The Budgets month choice (`budgetsMonthChoiceProvider`) is an autoDispose provider watched only by
Budgets views and the Budgets month selector in the header. It falls back to the month of today and
resets when Budgets is unmounted, that is, when another segment or destination is selected. Plans
has one presentation owner in Money; Settings has no recurring-plan entry.

## Plans segment

`PlansFlow` (`app/lib/ui/plans/plan_list/plans_flow.dart`) hosts the Plans segment. Its root is a "Next up"
tray of plans sorted by next occurrence, with a count aside and one `MedallionRow` per plan whose
leading `DateBadge` shows the next date (`plans_list_view.dart`, `plan_list_view_model.dart`). The
root has no Add plan control, no Edit/Done toggle and no swipe delete: plans are created only from
Repeat in Add entry. The empty state and the load error (Try again invalidates the provider) use the
shared `EmptyState` and `AsyncValueView`.

A row tap calls `selectPlan`, which sets `selectedPlanProvider` (`plan_selection.dart`, an autoDispose
`IdSelectionNotifier`). On phone, `PlansFlow` pushes `PlanDetailScreen` through the shared
`SelectedDetailController`. On open and desktop, `planPaneProvider` returns a `ShellPane` with a Close
control, and `MoneyFlow` shows it in the right pane. The detail content (`plan_detail_content.dart`)
shows the signed amount, frequency, and key-value rows for Next, Account, Category (or To for a
transfer), Started, Last added and Ends, followed by Edit plan and Delete plan. The view model is
`planDetailViewModelProvider`, an autoDispose family keyed by plan ID.

Edit plan opens the AppSheet form in `app/lib/ui/plans/plan_form/plan_form.dart` (`showPlanFormSheet`, header "Edit plan", footer
"Save plan", no Cancel) through one `SheetSession` owned by `PlansFlow`. Delete plan asks through
`showDestructiveConfirmation` with the title "Delete the <name> plan?" and the body "Entries it already
added stay in History.", then deletes only the plan. On open and desktop, the list uses
`OpenSplitLayout` (3:2) only when `plansWideComposition` is true, which means no sheet and no selection.
The secondary column is empty and reserved for #323, and no floating action is shown. The needs-attention
notice is out of scope (issue 593).

## Key files

- `app/lib/ui/accounts/accounts_view_model.dart`, `accounts_flow.dart`, `accounts_screen.dart` -
  the screen view model, Flow, and screen.
- `app/lib/ui/accounts/account_sections.dart`, `account_row.dart` - section grouping and row
  rendering.
- `app/lib/ui/accounts/account_form/` - the New Account / New Subpocket sheet.
- `app/lib/ui/accounts/source_edit/` - the Edit Account / Edit Subpocket sheet.
- `app/lib/ui/common/pickers/` - the account type and day pickers.
- `app/lib/ui/plans/` - the Plans segment (see "Plans segment").
- `packages/domain/lib/src/accounting.dart` - `accountTotal`, `netWorth`, `balance` (see
  `recurring-plans-and-accounting.md`).


## Module interactions

`AccountsNotifier` is an `autoDispose` provider scoped to the mounted Accounts view. Its `build` is
synchronous, so the screen has no loading state, and a failed build ends in `AsyncError` and shows an
error state. It derives sections and net-worth as pure functions of `LedgerState`, listens to the
ledger itself (the listener is removed in `onDispose`) and recomputes on each change, carrying the
expanded account and any pending step across recomputations through its previous `state.value`. Card math
(payable, outstanding, statement cut) is pure with an injected `now`, so it is testable without the
system clock. Delete = archive to the recycle bin; the dialog shows the referencing-entry count.

`accountSections` still calls the app-side `statementCut`, `payable`, and `outstanding` functions
in `app/lib/ui/accounts/helpers/card_math.dart` through `_row` in
`app/lib/ui/accounts/account_sections.dart`. UI payable uses the full account total; UI outstanding
includes direct-card negative non-transfer entries from the cut through `now`, inclusively.
The separate domain `cardStatement` query bounds payable strictly before `nextCut` and observes
cycle charges through the named day. Its contracts live in
[recurring-plans-and-accounting.md](recurring-plans-and-accounting.md#card-statements)
(`packages/domain/lib/src/analysis/card_statement.dart`).

## Navigation

The Accounts Flow owns the Accounts segment's nested navigator. Tapping an account row pushes the
scoped Transactions screen; the
"Excluding subpockets" and per-pocket expanded rows push narrower scopes. Account headers and pocket
rows offer Edit by swiping start-to-end or using the Edit custom semantic action; it opens the
source-edit form for that exact holder ID. AccountsFlow tags each scoped Transactions route with its
preferred source. Shell Add reads the source on demand from the live Accounts Navigator, which
`MoneyFlow` and `AccountsFlow` share through `accountsNavigatorKeyProvider`
(`app/lib/ui/money/money_flow.dart`); `activeMoneySourceProvider` returns the preferred
source of the top route and caches nothing. The
getter returns no source for any destination other than Money, for Budgets and Plans (the Accounts
Navigator is not mounted), roots and untagged routes. Leaving the Accounts segment unmounts its Navigator and any scoped stack.
(`app/lib/ui/money/money_flow.dart`: `activeMoneySourceProvider`,
`app/lib/ui/accounts/money_navigation.dart`: `scopedRegisterSourceId`)

Account and source-edit forms use root `showAppSheet` routes with `shellSheetPresentation` as the
live resolver. `showAccountFormSheet` and `showSourceEditFormSheet` capture the exact route and wait
for `route.completed` before invalidating their form providers. Installed/exiting AppSheet occupancy
comes from the shared `shellSheetOccupancyProvider`; callers set no manual presentation flag.
Accounts root actions have no detail to shift, so forms remain right-docked on open and desktop
and bottom sheets on phone. Nested account type, day and parent AppSheets inherit coverage
through their nearest non-AppSheet predecessor. The page slot's stable isolation wrappers keep
Money, Budgets and Accounts Flow State mounted while a budget detail shifts under another sheet.
(`app/lib/ui/accounts/account_form/account_form.dart`, `source_edit/source_edit_form.dart`,
`app/lib/ui/shell/shell_sheet_presentation.dart`, `app/lib/ui/common/sheets/app_sheet_route.dart`,
`app/lib/ui/shell/shell_pane_host.dart`)

## Screens and flows

- **Accounts root** - no header row (the Money header owns the title and the `+` that opens the account
  form); a responsive three-metric summary card matching History (`Net worth`, `Assets`, `Owed`),
  configured from `netWorth` with income/expense amount styling; and a grouped list. The shared card
  measures the metrics and uses History's responsive composition in constrained panes.
  Sections group active accounts by `AccountType` in the fixed enum
  order Cash, Checking, Savings, Cards, Prepaid, Investment, Insurance, Other, skipping empty types.
  Non-card rows show `accountTotal`; card rows show payable (`max(0, −accountTotal)`) and outstanding
  (negated negative non-transfer entries since the statement cut). Expanding one account shows an
  "Excluding subpockets" row and one row per pocket. Swipe start-to-end edits the account or pocket;
  swipe end-to-start opens a "Delete \<name\>?" dialog with body "N transactions keep this name".
- **Card math** - payable is what you owe overall; outstanding is spend since the last statement,
  excluding transfers (repayments reduce payable via the balance, not outstanding). Statement cut
  anchors to the current month if `today.day ≥ d` else the previous month, clamped into the month via
  `addMonthsClamped` so an imported `d` of 29–31 does not roll over.
- **Account form** - segmented Account | Subpocket (Subpocket disabled when no pocketable accounts
  exist; pocketable = active, non-card, sorted by name - cards cannot hold pockets). Account mode:
  name, type picker (all `AccountType` values), statement-day picker (1–28, cards only),
  optional opening balance.
  Subpocket mode: name, parent account picker presented by `AppPickerSheet` with the live Accounts
  sheet presentation; choosing a parent updates the form and dismissing the picker keeps its current
  selection. Apply an async picker result only while the originating form route is active and its
  transition is complete. `AppPickerSheet` supplies picker bodies with a transparent `Material`
  ancestor. Save: `addAccount` (statement day only for cards),
  then `setOpeningBalance` if the balance ≠ 0 (posts the synthetic excluded opening-balance entry);
  Subpocket: `addPocket`. Its labelled rows are `FormSheetRow`
  (`app/lib/ui/common/inputs/form_sheet_row.dart`), shared with the Plan and Budget forms.
- **Source edit form** - reached from an account-header or pocket-row Edit action. Name; for
  accounts a balance section (allows negatives) whose edit posts a "Balance adjustment" entry for the
  delta with `includeInAnalysis: false` (no delta produces no entry); toggles "Transfers in count as
  expenses" (`incomingTransfersAsExpenses`) and, accounts only, "Include in net worth".

## Gotchas and invariants

- Statement-cut date math is clamped, never allowed to overflow into the next month, with a test
  matrix across 28/29/30/31 × {Feb, Feb-leap, 30-day, 31-day}.
- Editing a balance does not rewrite history: it posts a synthetic excluded delta entry, keeping the
  running balance replay-consistent.
- Cards cannot hold pockets, guarded in both UI and controller.
- `netWorth` splits by sign of the computed total, not by account type; pockets never count at top
  level. `recurring-plans-and-accounting.md` §4.4
- The domain normalizes `statementDay` on `addAccount`/`updateAccount` (clamp to 1–28, non-card →
  `null`); the account-form and source-edit pickers already constrain cards to 1–28, so the clamp
  is a backstop. The caller-supplied pocket set is dropped on `addAccount` and restored on
  `updateAccount` (`ledger-and-money-model.md`).
- The source-edit `updateAccount` call preserves the account's existing lifecycle, so the
  pocket-demotion cascade is not triggered by the edit; it fires only when an archive/delete moves
  the account to a less-alive lifecycle (`ledger-and-money-model.md`).
- Balance editing posts a `balanceAdjustment` system entry with `includeInAnalysis: false`; a zero
  delta posts nothing.

## Requirements

- Sections group active accounts by type in a fixed order (Cash, Checking, Savings, Cards,
  Prepaid, Investment, Insurance, Other), skipping empty types.
- Card payable is clamped at 0; outstanding excludes transfers and out-of-window entries.
- Balance editing posts a `balanceAdjustment` system entry (`includeInAnalysis: false`) for the
  delta; no delta produces no entry.
- Delete archives to the recycle bin and shows the referencing-entry count.
