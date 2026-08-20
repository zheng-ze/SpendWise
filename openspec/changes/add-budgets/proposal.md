## Why

SpendWise has no way to cap spending against a limit. Users can see what they spent (Stats,
Monthly) but can't set a target and track progress against it. Budgets close that gap: a monthly
limit per category (or an overall limit across every category), with month-to-month history and
optional rollover of unused or overspent amounts.

## What Changes

- New `Budget` domain model: a single category (or `null` for an overall, all-categories budget),
  a monthly limit that can change over time without rewriting past months, an optional per-month
  override, and a rollover mode fixed at creation.
- New domain mutators: `addBudget`, `updateBudgetAmount`, `deleteBudget`. No mutator changes a
  budget's category or rollover mode after creation — those require delete and recreate.
- Deleting or tombstoning a category cascades to delete any budget on that exact category, mirroring
  the existing `RecurringPlan` cascade in `ledger_state_plans.dart`.
- Spend-per-category-per-month, rollover-adjusted effective limits, and parent-category spend
  rollup all stay app-layer, computed from existing entries — the domain never computes "spent,"
  only "configured limit."
- Budgets UI (new tab, cards, form, multi-select-free single-category picker) is out of scope for
  this change; it lands once this domain model is delivered and reviewed.

## Capabilities

### New Capabilities
- `budgets`: monthly budget configuration — creation, per-month limit history with override,
  rollover mode, category-tombstone cascade, and uniqueness per category.

### Modified Capabilities
- (none — no existing capability's requirements change; the category-tombstone cascade is new
  behavior scoped entirely to the new `budgets` capability, not a change to `ledger-lifecycle`'s
  existing category-deletion contract)

## Impact

- `packages/domain/lib/src/`: new `budget.dart`, `limit_event.dart` (or similar), a new
  `ledger_state_budgets.dart` part file, new `LedgerChange` cases (`UpsertBudget`, `DeleteBudget`),
  new `LedgerError` cases for budget validation failures.
- `packages/domain/lib/src/ledger_state_categories.dart` (or wherever category cascade removal
  lives): extend the existing dereference/cascade sweep to include budgets, alongside plans.
- No changes to `app/` in this change — UI is a follow-up change once this design is reviewed.
