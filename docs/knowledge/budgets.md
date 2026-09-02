# Budgets

Last reconciled: 2026-09-02

## Feature overview

A monthly spending cap the user sets against one category or, if unscoped, against every category.
A budget is configured as an append-only timeline of `LimitEvent`s rather than a single mutable
field, so its limit can change over time with a full history. Budgets are pure configuration; they
produce facts (entries) only indirectly, via the spend math the app layer runs against analysis.

## Key files

- `packages/domain/lib/src/budgets/budget.dart` — the `Budget` model: `categoryID`, an
  immutable `List<LimitEvent>`, and `createdAtMonth`.
- `packages/domain/lib/src/budgets/limit_event.dart` — `LimitEvent`, a `default` (changes the
  ongoing limit from a month forward) or an `override` (pins exactly one month).
- `packages/domain/lib/src/ledger_state/ledger_state_budgets.dart` — the budget mutators on
  `LedgerState`: create, update, delete, duplicate-guard, and the category sweep.
- `app/lib/ui/budgets/budget_list/` — budget list view model, form, card, and `budgets_flow.dart`.
- `app/lib/ui/budgets/budget_detail/` — detail and limit screens with their view models.
- `app/lib/ui/budgets/helpers/budget_spend.dart` — the app-layer spend math (budgets-as-stats, not
  a shell tab, per ADR-0044).
- `docs/specs/budgets.md`, `docs/specs/budgets-ui.md` — the behavior contracts.

## Module interactions

Budgets live in the domain as config and are mutated through `Ledger` like any other row, so they
participate in the normal change stream and persistence. Spend math is **not** in the domain — it
lives in `budget_spend.dart` in the app layer, per ADR-0042 ("budget spend math stays app layer").
The budget detail/list screens render the limit timeline and the spend-against-limit derived from
analysis items. Budgets are a Stats-segment feature, not a shell tab (`budgets.md` requirement,
ADR-0044).

## Budget model

- **Uniqueness.** At most one budget per category, and at most one unscoped (no-category) budget at
  a time. Creating a budget on a category that already has one, or a second unscoped budget, is
  rejected with `CategoryAlreadyBudgeted`. (`ledger_state_budgets.dart` `_validateCategoryUniqueness`)
- **Starting limit.** `addBudget` seeds the budget with a single `defaultLimit` event whose
  `effectiveFromMonth` is null, so the starting limit applies retroactively to every past month for
  its category, with no earliest month enforced, so activity recorded before the budget existed
  still counts against it.
- **Rollover.** An optional carry of unused limit or over-spend into the following month, configured
  at creation.
- **`LimitEvent` timeline.** `default` events change the ongoing limit from their month forward;
  `override` events pin exactly one month. The timeline is append-only; updates append a new event
  rather than rewriting history (`docs/adr/0038`, `docs/adr/0043`).
- **Category scope.** A budget names a single category or none (covers every category). A category's
  parent rollup and single-nullable scope are per `docs/adr/0039`.

## Mutators — `ledger_state_budgets.dart`

All amounts are `Decimal`; all reject `<= 0` with `ZeroAmount`.

- **`addBudget(String? categoryID, Decimal initialAmount, {required DateTime now})`** — validates the
  category reference (`UnknownCategory` for missing, `InactiveReference` for inactive; null is the
  unscoped slot), then uniqueness (`CategoryAlreadyBudgeted` when a budget already exists for that
  category or the no-category slot). Builds a `Budget` whose first event is a `defaultLimit`
  `LimitEvent(effectiveFromMonth: null, value: initialAmount)` and returns `[UpsertBudget(budget)]`.
- **`updateBudgetAmount(String rawBudgetID, Decimal newAmount, YearMonth effectiveFromMonth)`** —
  throws `UnknownBudget` on a missing id, then appends a `defaultLimit` event
  (`LimitEvent(effectiveFromMonth: effectiveFromMonth, value: newAmount, kind: defaultLimit)`)
  and returns `[UpsertBudget(updated)]`.
- **`setBudgetMonthOverride(String rawBudgetID, YearMonth month, Decimal value)`** — throws
  `UnknownBudget`, then appends an `override` event and returns `[UpsertBudget(updated)]`.
- **`deleteBudget(String rawID)`** — hard delete, no tombstone: plans are regenerable config and so
  are budgets. Normalizes the id; a missing id returns `[]`, else `[DeleteBudget(id)]`.
- **`_removeBudgetCategorized(categoryID)`** — removes every budget for a category; wired only for a
  future category-delete cascade, not yet called.

**Append-only timeline.** `addBudget`/`updateBudgetAmount`/`setBudgetMonthOverride` append a new
`LimitEvent` via `_appendEvent`; no mutator rewrites an existing event. `LimitEvent`
(`budgets/limit_event.dart`) carries a `LimitEventKind` (`defaultLimit` / `override`, explicit
codes 0/1), a `Decimal value`, and a nullable `YearMonth? effectiveFromMonth` (null for the ongoing
`default`, a specific month for an `override`).

## Spend math (app layer)

`budget_spend.dart` totals analysis items against the limit timeline for the active month, applying
rollover and the category scope (including the unscoped budget covering every category). The exact
thresholds and the direct-matching-any-category rule live in the spec (`docs/specs/budgets.md`,
`docs/adr/0045`). Budget form is create-only (`docs/adr/0046`): the limit is edited by appending
events, not by editing an existing one in place.

## Gotchas and invariants

- Budget spend math is deliberately outside the domain; a domain change must not introduce it
  (`docs/adr/0042`).
- Deleting a budget removes the row entirely — no tombstone, no restore. (`docs/adr/0041`)
- Rollover was designed and then removed; the timeline still records the decision
  (`docs/adr/0040`).

## Requirements

- At most one budget per category and one unscoped budget at a time; duplicates are rejected.
  (`budgets.md`, `ledger_state_budgets.dart`)
- A budget's starting limit applies to every past month for its category. (`budgets.md`)
- Limit changes are append-only `LimitEvent`s; a `default` moves the ongoing limit forward and an
  `override` pins one month. (`docs/adr/0038`, `docs/adr/0043`)
- Spend math stays in the app layer. (`docs/adr/0042`)
- Budget delete is a hard delete with no tombstone. (`docs/adr/0041`)
- `addBudget` rejects `CategoryAlreadyBudgeted`/`UnknownCategory`/`InactiveReference`/`ZeroAmount`;
  `updateBudgetAmount`/`setBudgetMonthOverride` throw `UnknownBudget`. (`ledger_state_budgets.dart`)
- The limit timeline is append-only; `defaultLimit` moves the ongoing limit, `override` pins one
  month. (`budgets/limit_event.dart`, `ledger_state_budgets.dart`)
