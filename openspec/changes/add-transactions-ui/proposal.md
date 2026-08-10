# Add the transactions screen and entry form

## Why

The shell has four destinations and none of them render anything. Transactions is the first screen
in the master doc's build order because it is the app's primary surface — it is where entries are
read, created and edited, and the entry form is the only way to get data into the ledger at all.

The screen is also where the port's pure-function discipline pays off: V1 computed its day sections
and month summaries inside a view model constructed in a view body, which is why none of it was ever
tested.

## What Changes

- Add the transactions screen: a Daily/Monthly tab pair, an income/expense/total bar, and a
  month-or-year selector whose stepping unit follows the active tab.
- Add `daySections` as a pure function — scope filtering, row resolution, interval filtering,
  grouping by day, and the per-section income and expense aggregates.
- Add `transactionRow` as a pure function resolving an entry against ledger state, so cells never
  read state themselves.
- Add the daily list with sticky day headers carrying the day's net, an empty state, tap-to-open, and
  swipe-to-delete behind a confirmation.
- Add `monthSummaries` as a pure function: months of the selected year up to the current one, newest
  first, each with the weeks overlapping it kept at full range even when they spill across months.
- Add the monthly breakdown view with single-month expansion and week rows that jump to Daily.
- Add the expanding action button, which is a plain button when it has one action and expands when a
  scoped screen gives it two.
- Add the entry form as a sheet: read-only first for existing entries, with kind, amount, name, date,
  recurrence, source and destination or category, an analysis toggle, and an error section.
- Add `canSave` and the save-sign rule as pure functions, plus plan creation from the form.
- Add the source, category and recurrence picker sheets.

Not **BREAKING**: additive. No domain, runtime or persistence behavior changes.

## Capabilities

### New Capabilities

- `transactions-screen`: the day-sectioned list, the month breakdown, their derivation rules and the
  interactions on them.
- `entry-form`: creating, viewing and editing an entry, including validation, sign derivation and
  plan creation.

### Modified Capabilities

None.

## Impact

- New code in `app/lib/ui/transactions/`, with the derivation functions kept separate from widgets so
  they are testable without pumping a widget.
- New tests in `app/test/ui/transactions/`, plus a golden test for the transaction cell.
- No new dependencies.
- No change to `packages/domain/`, the runtime or persistence.
- One open decision is deliberately not resolved here (`design.md`): this screen's totals apply only
  entry-level analysis inclusion, so they can disagree with Stats for the same month. The ruling is a
  domain-level call recorded in the master doc; the call site is kept singular so it is a one-line
  swap.
