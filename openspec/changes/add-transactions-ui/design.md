# Design — transactions screen and entry form

## Layout

`app/lib/ui/transactions/` splits into derivation and presentation. `day_sections.dart`,
`transaction_row.dart`, `month_summaries.dart` and the form's `can_save` / sign rules are pure
functions of `(LedgerState, params)`; the widgets call them and render.

That split is the point. V1 computed all of this inside view models constructed in view bodies, so
none of it could be tested without a running view — which is why V1 shipped zero view-model tests.

## Decisions

### Screen state lives in providers, keyed by scope

The selected date and the active mode live in a provider family keyed by the optional source scope,
so the account-scoped rendering of this same screen keeps its own selection without a second
implementation. Form controllers are per-sheet and auto-dispose.

### The totals divergence is deliberately not resolved here

This screen's income and expense totals apply **only** entry-level analysis inclusion. Stats
additionally applies category include-gates and reclassifies transfers into treat-as-expense holders,
so the two surfaces can report different numbers for the same month.

That is a real divergence and it is a known open decision at the domain level — either route both
through the accounting gates, or document it as intentional parity with the app V1 imitated. It is
not this change's call to make. What this change owes is a **singular call site**, so that whichever
way the ruling lands it is a one-line swap rather than a hunt through widgets.

### Half-open windows, again

Interval containment is `[start, end)` here as everywhere else in the port, deviating from Swift's
end-inclusive interval. The visible consequence is the week range label, which subtracts a day from
the exclusive end before formatting so the displayed end is the last day actually included.

### Spillover weeks appear twice, by design

A week overlapping two months is listed under both, at its full range, with identical totals. Clipping
it to the month would make the week's total disagree with itself depending on which month you opened
it from. Duplication is the lesser evil and matches V1.

### The plan cursor is set one step behind the anchor

Creating an entry with a recurrence sets the plan's resolved cursor just behind the anchor, so that
resolving immediately afterwards materializes the anchor day itself. Setting it *to* the anchor would
skip the first occurrence — which is the convention the sample seed deliberately uses, and the two
must not be confused.

### Delete has two paths with different confirmation rules

Swiping a row confirms; deleting from within the form does not. This looks inconsistent and is V1
parity — the form path is already several deliberate taps deep, where the swipe is one gesture from a
list. Keep both as they are.

## Test approach

The derivation functions carry the test weight, since they are where the logic is: grouping and
ordering, the scope filter, the include rules for section totals, the year cutoff and spillover weeks
in month summaries, the `canSave` matrix, the save-sign matrix, and the plan-creation wiring.

The transaction cell gets a golden test — it is the densest layout in the app and the one most likely
to regress silently.

Widget tests cover the interactions that are stateful rather than derived: cancelling an edit reverting
fields without dismissing, kind change clearing the category, and single-month expansion.
