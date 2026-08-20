## Why

`add-budgets` delivered the domain model — `Budget`, `LimitEvent`, mutators, category cascade —
but budgets are invisible: no storage, so they don't survive a restart, and no screen, so there's
no way to create one. This change makes budgets usable: persist them and let a user see, create,
and edit them.

## What Changes

- New `budgets` Drift table storing one row per `Budget`, with `limitEvents` encoded as a JSON text
  column (an unbounded, small list unlike the rest of the schema's flat columns).
- `_apply`'s switch in `drift_ledger_store.dart` gains real `UpsertBudget`/`DeleteBudget` cases,
  closing the exhaustive-switch gap `add-budgets` deliberately left open.
- `loadChanges` gains a `budgets` replay source, so budgets survive restart like every other row
  kind.
- `Ledger` gains `addBudget`/`updateBudgetAmount`/`setBudgetMonthOverride`/`deleteBudget` methods
  following the existing `addPlan`/`updatePlan`/`deletePlan` wiring.
- New Budgets UI: a third top-level segment on the Stats screen (alongside the existing
  Income/Expense `TopTabBar`), listing each budget as a card showing configured limit vs. spend
  for the selected month (spend computed app-side from `Accounting.rollUp`, mirroring how Stats
  already computes category slices — the domain never computes "spent"). A form for creating and
  editing a budget (category picker restricted to categories with no existing budget, plus an
  "Overall" option; amount; rollover mode; carry cap when applicable).
- No shell change: `ShellDestination` stays at its current four tabs.

## Capabilities

### New Capabilities
- `budgets-ui`: the Budgets segment on Stats — list, card, spend-vs-limit computation, create/edit
  form, and their interaction with the domain mutators and validation errors.

### Modified Capabilities
- (none — `data-persistence`'s existing requirements (enum round-trip, validated replay) already
  cover any row kind by construction; budgets satisfying them is new code following an existing
  contract, not a change to that contract. The replay-order list itself lives in code, not in any
  spec.)

## Impact

- `app/lib/persistence/tables.dart`: new `Budgets` table (`SyncedRow` mixin, JSON `limit_events`
  text column).
- `app/lib/persistence/ledger_database.dart`: add `Budgets` to `@DriftDatabase(tables: [...])`,
  bump `schemaVersion`.
- `app/lib/persistence/mappers.dart`: `budgetFromRow`/`budgetToRow`.
- `app/lib/persistence/drift_ledger_store.dart`: `loadChanges` gains a `budgets` source;
  `_apply`'s switch gains `UpsertBudget`/`DeleteBudget`.
- `app/lib/ledger/ledger.dart`: four new mutator-wrapping methods.
- `app/lib/ui/stats/`: new `budgets_tab.dart` (or similar), budget card widget, wiring into
  `stats_screen.dart`'s top tab bar (Income/Expense/Budgets).
- New `app/lib/ui/budgets/` (or kept under `ui/stats/`, decided in design.md): budget form screen,
  category picker restricted to unbudgeted categories.
- `app/lib/ui/common/error_section.dart`: no change needed — the three budget `LedgerError`
  messages already landed in `add-budgets`.
