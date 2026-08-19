# Add the accounts screen and holder forms

## Why

Balances exist in the domain but nothing shows them. There is no way to create an account, no way to
see what a card is owed, and no way to reach an account's own transaction history.

This is the third screen in the master doc's build order. It is also where the port fixes a real V1
defect: the credit-card statement cut is built from naive date components that overflow into the
following month for statement days past the 28th. V1's form caps the day at 28 so its own UI cannot
create the bad case, but imported or synced data can — and Dart's `DateTime` rolls over silently, so
a straight translation would be wrong by construction.

## What Changes

- Add the accounts screen: a header, a net-worth summary bar, and accounts grouped by type in a fixed
  order with empty types skipped.
- Add the section and row derivations as pure functions — per-account totals, own balance excluding
  pockets, pocket sub-rows, and section subtotals, with cards carrying two labelled columns.
- Add the card math: payable clamped at zero, outstanding as spend since the statement cut, and the
  statement cut itself computed with the shared clamping date helper.
- Add row expansion with an "excluding subpockets" row and one row per pocket, each navigating to the
  transactions screen scoped to that holder.
- Add swipe-delete on accounts and pockets, archiving to the recycle bin behind a confirmation that
  states how many entries keep the name.
- Add the account form: account or subpocket, type, a statement day for cards only, an optional
  opening balance, and a parent picker for subpockets.
- Add the source edit form: name, type, statement day, a balance field that posts an adjustment entry
  rather than rewriting history, and the treat-as-expense and net-worth toggles.

Not **BREAKING**: additive. No domain, runtime or persistence behavior changes.

## Capabilities

### New Capabilities

- `accounts-screen`: the grouped account list, its derived totals, the card statement math, and the
  navigation and deletion available on a row.
- `holder-forms`: creating accounts and pockets, and editing an existing holder including the balance
  adjustment.

### Modified Capabilities

None.

## Impact

- New code in `app/lib/ui/accounts/`, with the derivations kept separate from widgets.
- New tests in `app/test/ui/accounts/`, including the statement-day clamp matrix and a golden test for
  the account row.
- No new dependencies.
- No change to `packages/domain/`, the runtime or persistence.
- One V1 defect fixed under the master doc's sanction (`design.md`): the unclamped statement cut. One
  deliberate V1 deviation: the delete confirmation shows the referencing-entry count V1 computed but
  never displayed.
