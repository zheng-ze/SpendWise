# Accounts UI

Last reconciled: 2026-09-02

## Feature overview

The Accounts tab and its account/pocket forms. The tab groups active accounts by type with pockets
nested under their parent, shows card accounts as payable/outstanding two columns, and derives net
worth from `Accounting.netWorth`. Tapping an account row pushes the Transactions screen scoped to
that account and its pockets. Forms exist for creating accounts and pockets and for editing a source,
including posting a balance-adjustment delta entry.

## Key files

- `app/lib/ui/accounts/accounts_view_model.dart`, `accounts_flow.dart`, `accounts_screen.dart` —
  the tab view model, Flow, and screen.
- `app/lib/ui/accounts/account_sections.dart`, `account_row.dart` — section grouping and row
  rendering.
- `app/lib/ui/accounts/account_form/` — the New Account / New Subpocket sheet.
- `app/lib/ui/accounts/source_edit/` — the Edit Account / Edit Subpocket sheet.
- `app/lib/ui/common/pickers/` — the account type and day pickers.
- `packages/domain/lib/src/accounting.dart` — `accountTotal`, `netWorth`, `balance` (see
  `recurring-plans-and-accounting.md`).


## Module interactions

The view model derives sections and net-worth as pure functions of `LedgerState`. Card math
(payable, outstanding, statement cut) is pure with an injected `now`, so it is testable without the
system clock. Delete = archive to the recycle bin; the dialog shows the referencing-entry count.

## Navigation

The Accounts Flow owns this tab's nested navigator, and the tab additionally owns its own stack
internally (path-based). Tapping an account row pushes the scoped Transactions screen; the
"Excluding subpockets" and per-pocket expanded rows push narrower scopes. The account/source-edit
forms and the entry form open as sheets.

## Screens and flows

- **Accounts root** — custom header row ("Accounts" headline + trailing `+` opening the account
  form), a summary bar (Assets blue / Liabilities red / Total = assets − liabilities from
  `netWorth`), and a grouped list. Sections group active accounts by `AccountType` in the fixed enum
  order Cash, Checking, Savings, Cards, Prepaid, Investment, Insurance, Other, skipping empty types.
  Non-card rows show `accountTotal`; card rows show payable (`max(0, −accountTotal)`) and outstanding
  (negated negative non-transfer entries since the statement cut). Expanding one account shows an
  "Excluding subpockets" row and one row per pocket. Swipe-delete on account and pocket rows opens a
  "Delete \<name\>?" dialog with body "N transactions keep this name".
- **Card math** — payable is what you owe overall; outstanding is spend since the last statement,
  excluding transfers (repayments reduce payable via the balance, not outstanding). Statement cut
  anchors to the current month if `today.day ≥ d` else the previous month, clamped into the month via
  `addMonthsClamped` so an imported `d` of 29–31 does not roll over.
- **Account form** — segmented Account | Subpocket (Subpocket disabled when no pocketable accounts
  exist; pocketable = active, non-card, sorted by name — cards cannot hold pockets). Account mode:
  name, type picker (all `AccountType` values), statement-day picker (1–28, cards only),
  optional opening balance.
  Subpocket mode: name, parent account picker. Save: `addAccount` (statement day only for cards),
  then `setOpeningBalance` if the balance ≠ 0 (posts the synthetic excluded opening-balance entry);
  Subpocket: `addPocket`.
- **Source edit form** — reached only via the scoped-transactions FAB "Edit \<name\>". Name; for
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
