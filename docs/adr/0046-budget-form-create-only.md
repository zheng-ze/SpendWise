# 46. The budget form is create-only; its edit path was removed as unreachable

## Status

Accepted

## Context

`BudgetForm` was originally built with both a creation mode and an edit mode (a locked category
tile, an override-month tile, a delete button). Once the rest of the budgets UI was in place, the
form's edit-mode path turned out to have no real caller: the actual edit flow a user reaches is
`BudgetCard` → `BudgetDetailScreen` → `BudgetLimitScreen`'s own bottom sheet, and the form's
edit-sheet entry point was never invoked with a budget to edit.

## Decision

The form's edit-mode path was removed rather than wired up to a caller that doesn't exist. `BudgetForm`
now only ever creates a new budget: a category picker (any active category, excluding one already
budgeted, plus an "Overall" option) and an amount field.

## Consequences

There is exactly one place a budget's limit is edited after creation (`BudgetLimitScreen`'s sheet),
and exactly one place a budget is created (`BudgetForm`) — no dead code implementing a second edit
path that nothing calls. Any future need to edit a budget's category or rollover setting still
requires delete-and-recreate, per the earlier ruling that those fields are immutable after creation.
