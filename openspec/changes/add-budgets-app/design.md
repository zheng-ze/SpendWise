## Context

`add-budgets` delivered `Budget`, `LimitEvent`, `RolloverMode`, the four mutators, the category
cascade, and two new `LedgerChange` cases (`UpsertBudget`, `DeleteBudget`) — all domain-only. See
proposal.md for why persistence and UI are the remaining gap.

`drift_ledger_store.dart`'s `_apply` switch is currently non-exhaustive over `LedgerChange` on
purpose: it was left red rather than given a silent no-op, so the missing budget storage stays
visible. This change is what turns that red green for real.

The Drift schema (`app/lib/persistence/tables.dart`) has one table per row kind, each with a
`SyncedRow` mixin (`version_data` blob, `lifecycle` int) and flat columns — `Plans` flattens its
`EntryTemplate` fields (`template_amount`, `template_category_id`, ...) directly onto the row.
`schemaVersion` is still `1` with no `MigrationStrategy` anywhere in the app; there's no installed
base to migrate, so adding a table is a plain schema bump, not a migration.

Stats (`app/lib/ui/stats/stats_screen.dart`) already has a `TopTabBar` (Income/Expense) and computes
category spend via `Accounting.rollUp` + `slices()`. The user chose Budgets as a third segment on
that same tab bar, reusing this computation path rather than a new shell tab (`ShellDestination` is
a fixed 4-value enum: transactions/stats/accounts/settings).

## Goals / Non-Goals

**Goals:**
- Budgets persist across restart with the same round-trip guarantees every other row kind has.
- A user can create, edit (limit + override, not category/rollover), and delete a budget from the
  UI, and see configured limit vs. actual spend per month.
- `_apply`'s switch becomes exhaustive again, honestly this time — real storage, not a stand-in.

**Non-Goals:**
- No new `ShellDestination` tab.
- No editing of a budget's category or rollover mode in place (delete-and-recreate only, per
  `add-budgets`'s design.md ruling — this change doesn't revisit that).
- No sync/multi-device conflict resolution beyond what `SyncedRow`'s existing version-vector
  bump-on-write already gives every other table.
- No year-range view for budgets (Stats' Annually toggle stays scoped to Income/Expense).

## Decisions

### `limitEvents` storage: JSON text column, not a child table

`Budgets` gets one row per `Budget`. `limit_events` is a `TextColumn` holding a JSON-encoded array
of `{effectiveFromMonth, value, kind}`, decoded/encoded in the mapper.

Alternatives considered: a `budget_limit_events` child table (FK to `budget.id`), matching normal
relational practice. Rejected — `limitEvents` is typically 1-3 entries, never queried independently
of its parent budget (`effectiveLimit` always operates on the whole list at once), and a child table
would need its own version-vector story for a sub-row that isn't a `SyncedRow` in its own right.
The existing schema already denormalizes structured data onto a single row (`Plans`' `EntryTemplate`
fields), so a JSON column is closer to house style than introducing the app's first child table.

`YearMonth` encodes as `"YYYY-MM"`; `Decimal` as its string form (matching every other money
column, e.g. `templateAmount`); `LimitEventKind` as its int `code` (matching the enum convention
everywhere else — never the JSON key name, so a future rename of the Dart enum value doesn't change
the wire format).

### Schema bump, no migration strategy

`schemaVersion` goes from `1` to `2`. No `MigrationStrategy.onUpgrade` is added because none exists
yet anywhere in the app — there's no installed release to migrate from, so the same "fresh schema"
posture that's implicitly governed version 1 continues to govern version 2. The first time this
becomes a real migration is a separate, future concern once a version ships.

### Budgets as a third Stats segment, not a new shell tab

Confirmed with the user. `TopTabBar` takes `List<String> titles` and an index — extending
Income/Expense to Income/Expense/Budgets is additive to `stats_screen.dart` alone; no shell,
navigation, or `ShellDestination` change.

`_StatsScreenBodyState._kind` is currently typed `CategoryKind`, which has no value for Budgets.
It's replaced with a 3-value `_StatsTab { income, expense, budgets }`, and every site that reads
the old `_kind` — `_setKind`, `_onTapCategory` (navigates to `CategoryDetailScreen`, which only
makes sense for a category slice), the `slices()` call, the total label/color ternaries, and
`_EmptyState` (also `CategoryKind`-typed) — stays guarded to the `income`/`expense` branches. The
Budgets branch renders a budgets list instead of the donut + legend, keyed off the same
`selectedMonthProvider` the other two branches already use for their month header, with its own
empty-state widget rather than reusing the `CategoryKind`-typed one.

The AppBar's `StatsRangeMode` popup (Monthly/Annually) stays visible across all three segments
today; per this design's Non-Goals (no year-range budgets), it's hidden — or disabled and forced
to `month` — whenever the Budgets segment is active, so a user can't switch to a year window and
see spend figures that don't correspond to any budget's monthly `effectiveLimit`.

### Spend computation: direct `AnalysisItem` matching, not `Accounting.rollUp` — any category can be budgeted

A budget can be set on any active category, top-level or subcategory (confirmed with the user —
this reopens and reverses the top-level-only restriction from the first review pass). A
subcategory's spend counts toward both its own budget and its parent's budget independently; the
two totals are allowed to overlap, since they represent two separate limits a user is tracking on
purpose, not one number rolled up twice.

`Accounting.rollUp` can't serve this directly: it keys its result by `Accounting.mainBucketID`,
which collapses every leaf category onto `category.parentID ?? category.id`, so its map never
carries a leaf's own id as a key. Using it would make a subcategory budget's spend always resolve
to zero — the gap the first review pass caught, at the time worked around by forbidding
subcategory budgets rather than fixing the lookup. That workaround is now withdrawn.

Instead, `budgetSpend` filters `AnalysisItem`s directly against `state.categories`, without going
through `rollUp`:
- **Overall budget** (`categoryID == null`): sum every expense item in the month (unchanged).
- **Category budget**: sum items whose `bucketID` is the budgeted category's id, plus items whose
  `bucketID` names a category whose `parentID` is the budgeted category's id (its direct children).

`packages/domain`'s category nesting is capped at two levels — `ledger_state_categories.dart`
throws `CategoryTooDeep` the moment a category with a non-null `parentID` is itself given a child
(`parent.parentID != null` check) — so "direct children" is the whole subtree; no recursive walk
is needed. No new domain function; the domain keeps computing only "configured limit"
(`effectiveLimit`), per `add-budgets`' original design ruling.

### Ledger wiring mirrors plans exactly

`Ledger` gains:
```dart
List<LedgerChange> addBudget(String? categoryID, Decimal amount, RolloverMode mode, {Decimal? carryCap}) =>
    _mutate((state) => state.addBudget(categoryID, amount, mode, carryCap: carryCap));
List<LedgerChange> updateBudgetAmount(String budgetID, Decimal amount, YearMonth from) =>
    _mutate((state) => state.updateBudgetAmount(budgetID, amount, from));
List<LedgerChange> setBudgetMonthOverride(String budgetID, YearMonth month, Decimal value) =>
    _mutate((state) => state.setBudgetMonthOverride(budgetID, month, value));
List<LedgerChange> deleteBudget(String budgetID) =>
    _mutate((state) => state.deleteBudget(budgetID));
```
matching `addPlan`/`updatePlan`/`deletePlan`'s shape (`ledger.dart:103-110`) exactly — `_mutate`
already carries the try/catch-and-report-`LedgerError` behavior every other mutator method relies
on, so the form-error pattern (`_error` field + `ErrorSection`, as in `plan_form.dart`) needs no new
machinery.

### Form scope: one form, category+rollover locked after creation

One `BudgetForm` widget, reusing `form_scaffold.dart`/`amount_field.dart`/`error_section.dart` as
`plan_form.dart` does. Create mode shows category picker (any active category, top-level or
subcategory, excluding one already budgeted, plus an "Overall" option representing
`categoryID: null`) and rollover mode selector. Edit mode shows those two as read-only text, with
an editable amount field and an optional override-month picker. This matches the spec's "Rollover
mode is fixed after creation" scenario and avoids a second widget for what's otherwise the same
layout.

## Risks / Trade-offs

- **[Risk]** JSON in a `TextColumn` means malformed JSON on load can't be caught by Drift's own
  type system, only by the mapper. → Mitigation: the mapper throws a real (non-assert) error on
  decode failure, consistent with `data-persistence`'s "unrecognized code fails loudly" requirement
  and `fromCode`'s existing `ArgumentError` convention; this surfaces the same way any other corrupt
  row already does (load fails loudly, not silently).
- **[Risk]** A parent budget's spend and a child budget's spend can overlap (a subcategory's entry
  counts toward both), and a user could misread the two cards as summing to a combined total when
  they don't. → Mitigation: this is an intentional product decision (confirmed with the user), not
  a bug; each card shows its own limit and its own spend, with no combined-total UI implying
  otherwise. Task list includes a test asserting the overlap is real (a child's entry counts toward
  both budgets independently) so it isn't accidentally "fixed" into double-counting prevention
  later.
- **[Risk]** A budget's `categoryID` can outlive its category in the window between the category
  being deleted and the cascade in `add-budgets` removing the budget (the cascade fires on purge,
  not on archive) — or, more simply, the budget card must not crash on a category lookup miss. →
  Mitigation: the budget card (task 6.2) handles a missing `ledger.state.categories[categoryID]`
  the same way `slices.dart`'s `_slice` already does for a missing category — fall through to a
  clear fallback label rather than a null-check crash.
- **[Trade-off]** No child table for `limitEvents` means a future feature needing to query across
  all budgets' override months (e.g., "show me every override next month") would need to decode
  every budget row rather than a SQL query. Accepted: no such feature is planned, and the list is
  always small.

## Migration Plan

No user data exists in the wild yet (personal-use app, pre-release). Schema bump from 1 to 2 is a
plain additive change: existing tables are untouched, `Budgets` is new. No rollback plan needed
beyond reverting the commit before any build ships.

## Open Questions

None — the two decisions that would have changed scope (storage shape, UI placement) were resolved
with the user before writing this document.
