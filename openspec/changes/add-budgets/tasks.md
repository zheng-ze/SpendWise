## 1. YearMonth value type

- [ ] 1.1 Add `YearMonth` to `packages/domain/lib/src/calendar_day.dart` (or a new
      `year_month.dart` alongside it): immutable `{year, month}`, hand-written `==`/`hashCode`,
      `compareTo`/`Comparable<YearMonth>` so events can be ordered and compared, and a
      `YearMonth.fromUtc(DateTime)` constructor for deriving a month from an entry date.
- [ ] 1.2 Test comparison, equality, and `fromUtc` in a new `year_month_test.dart`, including that
      December-to-January comparisons order correctly across a year boundary.

## 2. LimitEvent and Budget models

- [ ] 2.1 Add `packages/domain/lib/src/limit_event.dart`: `LimitEvent {effectiveFromMonth:
      YearMonth?, value: Decimal, kind}` with `kind` an int-coded enum (`default`, `override`) per
      this repo's enum convention, immutable, hand-written `==`/`hashCode`.
- [ ] 2.2 Add `packages/domain/lib/src/budget.dart`: `Budget {id, categoryID: String?,
      limitEvents: List<LimitEvent>, rolloverMode, carryCap: Decimal?, createdAtMonth: YearMonth}`.
      `rolloverMode` is an int-coded enum (`none`, `positiveOnly`, `both`). `limitEvents` exposed as
      an unmodifiable list, matching how `LedgerState`'s maps are exposed. Immutable, hand-written
      `==`/`hashCode`.
- [ ] 2.3 Add a pure `effectiveLimit(Budget budget, YearMonth month)` function (design.md's
      resolution rule): exact-month override wins (last one appended if more than one), else the
      latest default event at or before `month`.
- [ ] 2.4 Test `effectiveLimit` directly against `LimitEvent` lists (no `LedgerState` involved):
      default-only timeline, a default change taking effect from a later month, an override pinning
      one month while surrounding months keep resolving to the default, two overrides on the same
      month (last one wins), and a month before every event (falls back to the unbounded-past
      first event).

## 3. LedgerChange and LedgerError cases

- [ ] 3.1 Add `UpsertBudget` and `DeleteBudget` to `ledger_change.dart`, following the existing
      `UpsertPlan`/`DeletePlan` shape (`targetID`, value `==`, `hashCode`, `toString`).
- [ ] 3.2 Add new `LedgerError` cases to `ledger_error.dart` for: unknown budget id (thrown on
      update to a nonexistent budget; `deleteBudget` does not use this case, since delete on a
      missing id no-ops like `deletePlan` does), category-already-budgeted collision, and
      carry-cap-invalid (covers negative, zero-under-rollover, and non-null-under-`none` — one case
      is enough since all three are "this carryCap value is unusable").
- [ ] 3.3 Test each new error's `==`/`hashCode`/`toString` alongside the existing cases in
      `ledger_change_test.dart` / wherever those sealed-class tests live, matching the existing
      per-case test shape.

## 4. Budget mutators

- [ ] 4.1 Add `packages/domain/lib/src/ledger_state_budgets.dart` as a `part of 'ledger_state.dart'`
      extension `LedgerStateBudgets`, mirroring `ledger_state_plans.dart`'s structure.
- [ ] 4.2 Implement `addBudget(categoryID, initialAmount, rolloverMode, {carryCap})`: validates
      categoryID (`null` exempt, otherwise must reference an existing active category — reuse the
      category lookup pattern from `_validatePlan`), validates categoryID uniqueness against
      existing budgets (`null` included, so at most one budget has no category), validates
      `initialAmount > 0`, validates `carryCap` (null or strictly positive; must be null when
      `rolloverMode` is `none`), constructs the budget with one `LimitEvent{effectiveFromMonth:
      null, value: initialAmount, kind: default}` and `createdAtMonth` set to the current month,
      stores it, returns `_checked([UpsertBudget(budget)])`.
- [ ] 4.3 Implement `updateBudgetAmount(budgetID, newAmount, effectiveFromMonth)`: looks up the
      budget (throw unknown-budget if missing), validates `newAmount > 0` and `effectiveFromMonth`
      is non-null, appends a new `{effectiveFromMonth, value: newAmount, kind: default}` event,
      returns `_checked([UpsertBudget(updated)])`.
- [ ] 4.4 Implement `setBudgetMonthOverride(budgetID, month, value)`: looks up the budget, validates
      `value > 0` and `month` non-null, appends `{effectiveFromMonth: month, value, kind:
      override}`, returns `_checked([UpsertBudget(updated)])`.
- [ ] 4.5 Implement `deleteBudget(budgetID)`: hard-removes the budget, no-op on a missing id,
      matching `deletePlan`'s shape exactly.
- [ ] 4.6 Test each mutator directly against `LedgerState`: creation success and every rejection
      path from design.md's "Creation validation" (bad category, inactive category, duplicate
      category including duplicate `null`, non-positive amount, negative carryCap, zero carryCap
      under `positiveOnly`/`both`, non-null carryCap under `none`), amount-update success and its
      rejections, override success including overwrite-an-existing-override, and delete (found and
      not-found).

## 5. Category-tombstone cascade

- [ ] 5.1 Add `_removeBudgetCategorized(String categoryID)` to `ledger_state_budgets.dart`,
      mirroring `_removePlansCategorized`'s shape exactly: finds any budget whose `categoryID`
      matches, removes it, returns `[DeleteBudget(id)]` (there is at most one match, unlike plans,
      since categoryID is unique per budget, but keep the same return-a-list shape for consistency
      with the plan helper it mirrors).
- [ ] 5.2 Call `_removeBudgetCategorized(category.id)` alongside the existing
      `_removePlansCategorized(category.id)` call in `_purgeCategoryRow`
      (`ledger_state_purge.dart:91`).
- [ ] 5.3 Call `_removeBudgetCategorized(categoryID)` alongside the existing
      `_removePlansCategorized(categoryID)` call in `_sweepCategory` (`ledger_state_purge.dart:134`).
- [ ] 5.4 Test the cascade: deleting a category with a budget removes the budget and emits
      `DeleteBudget`; deleting a category with a budgeted *child* leaves the child's budget intact
      (matches design.md's "Deleting a category cascades to its budget" — exact match only, not
      descendants); deleting an unrelated category leaves an existing budget untouched.

## 6. Invariants

- [ ] 6.1 Read `ledger_state_invariants.dart` to find where categorized-row invariants
      (`_checked`/`assertInvariants`) are asserted, and add a debug-only invariant clause: every
      `Budget.categoryID` that is non-null names an existing category (a budget cannot outlive its
      category outside the cascade paths above), and every `Budget.limitEvents` list satisfies the
      first-event-only-null-effectiveFromMonth rule from design.md (defensive backstop — the
      mutators should already make any other state unreachable).
- [ ] 6.2 Test the invariant catches a deliberately malformed state the normal mutator path cannot
      produce (matching this repo's existing invariant-test style of constructing bad state
      directly rather than through mutators).

## 7. Gate

- [ ] 7.1 Run `cd packages/domain && dart format . && dart analyze && dart test` and confirm zero
      analyzer issues and all tests green.
