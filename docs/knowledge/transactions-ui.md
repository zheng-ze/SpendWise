# Transactions UI

Last reconciled: 2026-10-14

## Feature overview

The transactions list and its entry form. The unscoped list is the desktop History destination;
scoped lists live inside Money. It shows a month-navigated list grouped into day
sections (Daily) or a year broken into months and weeks (Monthly), and renders account-scoped with
a custom title and source filter. The entry form creates, views (read-only-first), and edits entries
and is the only place recurring plans are created.

## Key files

- `app/lib/ui/transactions/transactions_view_model.dart` — screen state (`selectedDate`, `mode`,
  optional source scope); derived lists are pure functions of `(LedgerState, params)`.
- `app/lib/ui/transactions/daily_list/` and `app/lib/ui/transactions/monthly/` — the day-sectioned
  list and the month/week breakdown views.
- `app/lib/ui/transactions/entry/` — the entry form sheet.
- `app/lib/ui/transactions/entry/new_entry_presenter.dart` — the shared Add presenter
  (`openNewEntry`): reads `shellLayoutModeProvider` from the caller-side ref, opens the null-key
  entry form in `AppSheet` on the root navigator, and owns the only null-form Step subscription for
  the modal lifetime.
- `app/lib/ui/transactions/entry/steps/entry_step_handlers.dart` — the shared source, destination,
  category, recurrence, date, end-date and document-crop Step handlers used by both the presenter
  and `TransactionsFlow`, presented above the sheet through the root navigator.
- `app/lib/ui/transactions/receipt_scan/` — the OCR entry hook (see `ocr-receipt-entry.md`).
- `app/lib/ui/transactions/transactions_flow.dart` — the Flow that owns this list's nested navigator.
  It takes an optional `backLabel` passed through to the screen's back control; the phone
  History page sets it to 'Overview' with an `onEnded` that pops its containing Overview route,
  while the desktop History slot and scoped lists set none.
- `app/lib/ui/common/lists/day_sectioned_entry_list.dart`, `form_scaffold.dart`,
  `swipe_row.dart`, `pickers/` — shared components and picker sheets.
- `app/lib/ui/symbol_map.dart` — symbol-to-IconData mapping.

## Module interactions

The view model calls `Ledger` query/mutation methods and reads `AnalysisCache` where totals apply;
it never holds a `LedgerState` reference. Row resolution and section grouping are pure Dart
functions in the application layer, unit-tested independently of any widget. Totals apply only
entry-level `includeInAnalysis`, so Transactions and Stats can diverge for the same month — a ruled
decision, not a bug.

## Navigation

The Transactions Flow owns a nested `Navigator` scoped with a `GlobalKey<NavigatorState>` local to
the Flow (`ui-framework-mvvm.md`). The unscoped `TransactionsFlow` is the desktop shell's History
destination (`ShellDestination.history`); scoped instances live inside Money. Screens pushed: the entry form sheet for an existing entry, the
category/source picker sheets, and the receipt scan screen. New entries open only through the shell's
Add control and shared presenter. The Transactions screen has no local Add or Edit source control.
When Money is selected, the shell reads the top scoped Money route's preferred source through its
constructor-injected observer getter; every other destination and an unscoped Money route open Add
without a source. The presenter captures that source at invocation, invalidates the null-key form and
receipt providers before opening, initializes the fresh
form, applies the scoped prefill after initialization, maps the shell layout mode to the
`AppSheet` presentation (open uses the phone presentation until the open sheet lands), and releases its open guard and subscription when the sheet completes or
presentation fails. A late receipt finish after invalidation writes no state
(`ReceiptEntryCoordinator` checks `ref.mounted` in its asynchronous finally). The account-scoped
screen reuses the same screen with a custom title and `sourceIDs` filter. Back-stack behavior per
destination survives switching because each destination keeps its own navigator. A labelled back
control (phone History's 'Overview') keeps the existing `BackButton` and `goBack` behavior —
inner child routes pop first — and only changes its accessible label; unlabelled flows render a
plain back control.

## Screens and flows

- **Daily view** — day-sectioned list. `daySections` is a pure function: scope to touched entries,
  resolve each to a `TransactionRow`, filter to the half-open interval, group by `startOfDay(date)`,
  sort days descending and rows by timestamp descending. Section aggregates count income and
  negated expenses of entries with `includeInAnalysis == true`. Day headers are sticky and show a
  bare net in the `AmountStyle` sign colour. Empty state: tray icon + "No transactions". Tap a row opens a
  read-only entry sheet; swipe leading-to-trailing opens a "Delete this transaction?" confirmation.
- **Monthly view** — `monthSummaries` is a pure function: months up to and including the current
  month, newest first, each with weeks kept at full week range even when spilling into neighboring
  months (a spillover week appears under both months). Tap a month expands only it; tap a week jumps
  to Daily view of that week's month.
- **Entry form** — three modes. New ("Add entry" with Cancel in the `AppSheet` header,
  `ReceiptScanStrip` + fields + `ErrorSection` in the body, Save in the footer driven by `canSave`).
  View existing ("Entry", leading ‹ Back, trailing ✎ Edit). Edit existing ("Edit Entry", leading ✕
  Back reverts fields to persisted values and drops to view mode with the sheet open). Fields: kind
  segmented (changing kind clears the selected category), amount, name, date with a recurrence
  button (new only), optional end date, source pickers (plus a To row for transfers, else a Category
  row), and an "Include in Analysis" toggle. `canSave` is a pure function; deeper rules are the
  domain validator's job and surface via the `ErrorSection` ("Could not save entry: <error>"). Save
  semantics: sign is applied from kind; edit stays open and flips to read-only; new without
  recurrence calls `addEntry`; new with recurrence builds an `EntryTemplate` and calls `addPlan`
  with `anchor = date` and `lastResolvedDate = date − 1 s` so the anchor day resolves, then calls
  `resolvePlans`. A saved or cancelled new entry resets on the next open through provider
  invalidation. Cancel, barrier dismissal and Back dismiss Add without creating an entry.
- **Picker sheets** — `TwoColumnPickerSheet` (master/detail, expands a parent into the right column,
  selects a childless parent or a child); `SourcePickerSheet` (active accounts with active pockets as
  children, no None); `CategoryPickerSheet` (groups from `EntryFormViewModel.categoryGroups`,
  ordered roots-then-children A–Z, `allowsNone: true`, never shown for transfers); `RecurrencePickerSheet`
  (One time then Weekly/Biweekly/Monthly/Quarterly/Yearly).
- **Shell Add** — phone bar and desktop sidebar share one callback to the presenter. Transactions
  retains date selection, mode switching, filtering, row view/edit and Back behavior.

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
