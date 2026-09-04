# Transactions UI

Last reconciled: 2026-09-02

## Feature overview

The Transactions tab and its entry form. The tab shows a month-navigated list grouped into day
sections (Daily) or a year broken into months and weeks (Monthly), and renders account-scoped with
a custom title and source filter. The entry form creates, views (read-only-first), and edits entries
and is the only place recurring plans are created.

## Key files

- `app/lib/ui/transactions/transactions_view_model.dart` — screen state (`selectedDate`, `mode`,
  optional source scope); derived lists are pure functions of `(LedgerState, params)`.
- `app/lib/ui/transactions/daily_list/` and `app/lib/ui/transactions/monthly/` — the day-sectioned
  list and the month/week breakdown views.
- `app/lib/ui/transactions/entry/` — the entry form sheet.
- `app/lib/ui/transactions/receipt_scan/` — the OCR entry hook (see `ocr-receipt-entry.md`).
- `app/lib/ui/transactions/transactions_flow.dart` — the Flow that owns this tab's nested navigator.
- `app/lib/ui/common/day_sectioned_entry_list.dart`, `expanding_fab.dart`, `form_scaffold.dart`,
  `swipe_to_delete_row.dart`, `pickers/` — shared components and picker sheets.
- `app/lib/ui/symbol_map.dart` — symbol-to-IconData mapping.

## Module interactions

The view model calls `Ledger` query/mutation methods and reads `AnalysisCache` where totals apply;
it never holds a `LedgerState` reference. Row resolution and section grouping are pure Dart
functions in the application layer, unit-tested independently of any widget. Totals apply only
entry-level `includeInAnalysis`, so Transactions and Stats can diverge for the same month — a ruled
decision, not a bug.

## Navigation

The Transactions Flow owns a nested `Navigator` scoped with a `GlobalKey<NavigatorState>` local to
the Flow (`ui-framework-mvvm.md`). Screens pushed: the entry form sheet, the category/source picker
sheets, and the receipt scan screen. The account-scoped screen reuses the same screen with a custom
title and `sourceIDs` filter. Back-stack behavior per tab survives switching because each
destination keeps its own navigator.

## Screens and flows

- **Daily view** — day-sectioned list. `daySections` is a pure function: scope to touched entries,
  resolve each to a `TransactionRow`, filter to the half-open interval, group by `startOfDay(date)`,
  sort days descending and rows by timestamp descending. Section aggregates count income and
  negated expenses of entries with `includeInAnalysis == true`. Day headers are sticky and show a
  net colored by the net-amount rule. Empty state: tray icon + "No transactions". Tap a row opens a
  read-only entry sheet; swipe leading-to-trailing opens a "Delete this transaction?" confirmation.
- **Monthly view** — `monthSummaries` is a pure function: months up to and including the current
  month, newest first, each with weeks kept at full week range even when spilling into neighboring
  months (a spillover week appears under both months). Tap a month expands only it; tap a week jumps
  to Daily view of that week's month.
- **Entry form** — three modes. New ("New Entry", Save enabled when valid). View existing ("Entry",
  leading ‹ Back, trailing ✎ Edit). Edit existing ("Edit Entry", leading ✕ Back reverts fields to
  persisted values and drops to view mode with the sheet open). Fields: kind segmented (changing
  kind clears the selected category), amount, name, date with a recurrence button (new only),
  optional end date, source pickers (plus a To row for transfers, else a Category row), and an
  "Include in Analysis" toggle. `canSave` is a pure function; deeper rules are the domain validator's
  job and surface via the `ErrorSection` ("Could not save entry: <error>"). Save semantics: sign is
  applied from kind; edit stays open and flips to read-only; new without recurrence calls `addEntry`;
  new with recurrence builds an `EntryTemplate` and calls `addPlan` with `anchor = date` and
  `lastResolvedDate = date − 1 s` so the anchor day resolves, then calls `resolvePlans`.
- **Picker sheets** — `TwoColumnPickerSheet` (master/detail, expands a parent into the right column,
  selects a childless parent or a child); `SourcePickerSheet` (active accounts with active pockets as
  children, no None); `CategoryPickerSheet` (groups from `EntryFormViewModel.categoryGroups`,
  ordered roots-then-children A–Z, `allowsNone: true`, never shown for transfers); `RecurrencePickerSheet`
  (One time then Weekly/Biweekly/Monthly/Quarterly/Yearly).
- **ExpandingFAB** — single action behaves as a plain FAB; multiple actions toggle expansion (`+`
  rotates to `×`, capsule buttons stack above, outside-tap collapses).

## Gotchas and invariants

- The entry form is read-only-first for existing entries — a memory-pinned design fact, not to be
  "improved" into edit-first.
- Amount sanitizer strips to digits and one `.`, max 2 fraction digits, dropped not rounded; only
  the balance field allows a leading `-`.
- Malformed `colorHex` falls back to gray; writing back emits `#RRGGBB` uppercase, components
  clamped 0–255.
- Transactions/Stats totals divergence is ruled, not a bug; a single shared totals function keeps a
  future unification a one-line swap.

## Requirements

- Screen state (`selectedDate`, `mode`, scope) lives in a provider, not a widget.
- `daySections`, `TransactionRow.resolve`, and `monthSummaries` are pure, tested functions.
- Interval filters are half-open `[start, end)` everywhere.
- Saving a new entry with recurrence creates a plan with `lastResolvedDate = date − 1 s` and resolves
  immediately.
