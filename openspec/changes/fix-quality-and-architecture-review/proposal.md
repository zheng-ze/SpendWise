## Why

Two review passes — a code-quality audit and a module-depth audit — ran for the first time on
this codebase and surfaced one spec-conformance bug and four structural issues, written up in
`docs/reviews/2026-08-21-quality-and-architecture-review.md`. The bug (`Accounting.totals`
skipping the entry-gating check the ledger-accounting spec already requires) is live in two
screens today. The structural issues compound as the codebase grows: a widget duplicated across
two screens, a screen file approaching the project's 1,000-line ceiling, and domain logic
running inside a Flutter `ChangeNotifier` where it can't be unit-tested directly.

## What Changes

- Fix `Accounting.totals` (`packages/domain/lib/src/accounting.dart`) to apply the same
  existence-set gate `Accounting.classify` already applies, so an entry referencing a deleted
  holder stops contributing to income/expense totals, matching the ledger-accounting spec's
  entry-gating requirement.
- Move `Ledger.categories(kind)`'s parent/child grouping logic
  (`app/lib/ledger/ledger.dart:149-178`) into a new `LedgerStateQueries` method on `LedgerState`
  (`packages/domain/lib/src/ledger_state_queries.dart`), so `Ledger.categories()` becomes a
  one-line forward and the grouping logic is unit-testable without a `ChangeNotifier`.
- Extract a shared `DaySectionedEntryList` widget from the two duplicated implementations in
  `budget_detail_screen.dart` (`_BudgetEntryList`) and `category_detail_screen.dart`
  (`_ScopedEntryList`), parameterized by the entry-matching predicate.
- Split `app/lib/ui/stats/category_detail_screen.dart` (676 lines) by extracting `_TrendCard`
  and the subcategory table classes into their own files, and deduplicate the month-tick chart
  axis label builder (`_monthTick` / `_monthLabel`) as part of that split.

None of this is user-visible except the `Accounting.totals` fix, which corrects a case where a
holder-deletion edge case could currently show a wrong income/expense total; the rest is
behavior-preserving restructuring.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `ledger-accounting`: the entry-gating requirement's existing rule ("an entry SHALL be counted
  only when its source holder is present in the supplied id set") extends explicitly to the
  income/expense totals calculation, closing a gap where that calculation did not apply the
  gate.

## Impact

- `packages/domain/lib/src/accounting.dart` — `totals` signature gains a `sourceIDs` parameter
  to match `classify`'s existing gate.
- `app/lib/ui/transactions/month_summaries.dart`, `app/lib/ui/transactions/day_sections.dart` —
  both call `Accounting.totals`; both update to pass the existence set.
- `app/lib/ledger/ledger.dart`, `packages/domain/lib/src/ledger_state_queries.dart` — grouping
  logic relocates; `Ledger`'s public contract (`categories(kind)`) is unchanged.
- `app/lib/ui/budgets/budget_detail_screen.dart`, `app/lib/ui/stats/category_detail_screen.dart`
  — lose their private duplicated widgets in favor of a new shared one.
- New file: `app/lib/ui/transactions/day_sectioned_entry_list.dart` (or similar name, decided in
  design.md).
- New files under `app/lib/ui/stats/` for the classes extracted out of
  `category_detail_screen.dart`.
- No changes to `app/lib/persistence/`, storage schema, or any other promoted capability besides
  `ledger-accounting`.
