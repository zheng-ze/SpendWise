Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ui_screens.md` §2, which is more detailed than the
specs in this change.

Depends on `add-app-shell-and-boot` — the shell hosts this tab, and formatting, the amount field, the
category chip, the picker sheet and the form scaffold all come from there.

## 1. Row resolution

- [x] 1.1 Add `transactionRow(entry, state)` as a pure function returning title, account line, symbol,
      color and amount
- [x] 1.2 Non-transfer: title from category, `"Parent/Child"` when nested, `"Uncategorized"` when
      unset; account line from source, unknown label when unresolvable
- [x] 1.3 Transfer: titled "Transfer", account line `"Source > Destination"`, transfer glyph, gray
      chip, amount as an unsigned magnitude
- [x] 1.4 The row's note is the entry's typed name; the title derives from the category. There is no
      separate note field on `Entry` — the reserved persistence column stays unused
- [x] 1.5 Test: both kinds, nesting, the unresolvable-holder fallback

## 2. Day sections

- [x] 2.1 Add `daySections(entries, state, {interval, sourceScope})` as a pure function
- [x] 2.2 Scope filter first: keep entries touching a scoped id as source OR destination
- [x] 2.3 Resolve rows, filter to the interval half-open `[start, end)`, group by start of day
- [x] 2.4 Sort rows within a day newest first, and days newest first
      EDIT: `Entry.date` is calendar-day-only (no time component, by domain design), so "newest
      first" within a day is creation order (map insertion order), not a timestamp sort. Documented
      at `day_sections.dart:41-44`.
- [x] 2.5 Per-section aggregates: income sums income rows, expenses is the positive magnitude of
      expense rows, transfers count toward neither. Only entry-level `includeInAnalysis` gates —
      NOT category gates (`design.md`, open decision)
- [x] 2.6 Keep the totals call site singular so the pending domain ruling is a one-line swap
- [x] 2.7 Test: grouping and both sort orders; the scope filter on source and on destination; the
      include rules; a transfer contributing to neither total; interval boundaries half-open

## 3. Daily view

- [x] 3.1 Add the screen scaffold: tab pair, divider, income/expense/total bar, divider, content;
      app bar with the month/year selector
- [x] 3.2 State in a provider family keyed by optional source scope: selected date and mode. Daily
      steps by month, Monthly by year
      EDIT: `transactionsScreenProvider` in `transactions_screen_state.dart`, `NotifierProvider.family`
      keyed by `String? sourceScope`. Also exposes `switchToDaily(month)`, an atomic mode+date setter
      group 4's week-tap (task 4.8) calls into.
- [x] 3.3 Add day header rows: day number, secondary date line, trailing net colored by the net rule.
      Keep headers pinned while the section scrolls
- [x] 3.4 Add the transaction cell: category chip, title, optional note, account line, trailing amount
- [x] 3.5 Add the empty state when the interval has no sections
- [ ] 3.6 Tap a row opens the entry form read-only
      EDIT: stubbed only. Screen accepts `onRowTap: void Function(Entry)?`; group 5 (entry form) wires
      the real read-only form through it. Re-tick once group 5 lands and wires this.
- [x] 3.7 Swipe a row reveals delete, behind a confirmation identifying the entry by its note, falling
      back to its title when empty
      EDIT: initial landing zipped rows to entries by list index (re-deriving daySections' own
      filter/sort by hand), a duplicate-logic correctness risk. Fixed by adding `id` to
      `TransactionRow` (transaction_row.dart) and resolving via `state.entries[row.id]`
      (daily_transactions_screen.dart), removing the duplicate derivation entirely. Pinned with
      `daily_transactions_screen_test.dart`.
- [x] 3.8 Golden test the transaction cell
- [x] 3.9 Test: the empty state; the confirmation's fallback text

## 4. Monthly view

- [x] 4.1 Add `monthSummaries(state, year)` as a pure function
- [x] 4.2 Months up to and including the current calendar month, newest first. A future year yields
      zero rows; a fully past year yields twelve
- [x] 4.3 Per month: income and expenses by the §2.5 rules, a current-month flag, and its weeks
- [x] 4.4 Weeks: every week overlapping the month, kept at FULL range even when spilling into a
      neighbor, so a spillover week appears under both months with identical totals. Newest first,
      with a current-week flag
      EDIT: week-start convention was an open gap (Swift's `Calendar.current` week boundary follows
      device locale, no Dart equivalent). Fixed to ISO Monday start for determinism, documented at
      `month_summaries.dart:120-122`.
- [x] 4.5 Add month rows: chevron, month name, bold and tinted when current, trailing net
- [x] 4.6 Expanding a month collapses any other — at most one open at a time
- [x] 4.7 Add week rows: leading bar and highlight when current, range text, trailing net
- [x] 4.8 Tapping a week switches to Daily for that week's month. It does NOT scroll to the week
- [x] 4.9 Test: the year cutoff including the future-year and past-year cases; spillover weeks under
      both months with equal totals; single-month expansion

## 5. Entry form

- [ ] 5.1 Add the form sheet with three modes: new, viewing an existing entry, and editing one.
      Existing entries open READ-ONLY — do not change this to edit-first (`design.md`)
- [ ] 5.2 All fields non-interactive in the read-only view while rendering normally
- [ ] 5.3 Cancelling an edit reverts fields to persisted values and returns to the read-only view with
      the sheet still open
- [ ] 5.4 Add fields in order: kind segmented control, amount, name, date, source, destination or
      category, analysis toggle defaulting on
- [ ] 5.5 Changing kind clears the selected category
- [ ] 5.6 Recurrence control on new entries only, with an end-date toggle constrained to on-or-after
      the date
- [ ] 5.7 Add the error section shown after a failed save
- [ ] 5.8 Add `canSave` as a pure function: amount parses and is non-zero, name non-empty, source
      selected; transfers also require a destination differing from the source
- [ ] 5.9 Add the sign rule as a pure function: income positive, expense negative, transfer positive
      with a destination and no category
- [ ] 5.10 Save an edit via `updateEntry`, then stay open and flip back to read-only
- [ ] 5.11 Save a new entry without recurrence via `addEntry`, then dismiss
- [ ] 5.12 Save a new entry WITH recurrence as a plan: anchor at the date, optional end date, resolved
      cursor set one step BEHIND the anchor so the anchor day itself resolves. Then resolve plans
      immediately and dismiss. Do not confuse this with the seed's cursor-at-anchor convention
- [ ] 5.13 Prefill the source from the scope when opened from a scoped screen
- [ ] 5.14 Add delete while editing an existing entry: deletes and dismisses with NO confirmation —
      the swipe path is the confirmed one (V1 parity)
- [ ] 5.15 Test: the `canSave` matrix; the save-sign matrix; kind-change-clears-category; the plan
      wiring including anchor, end date and cursor; cancel-revert keeping the sheet open

## 6. Picker sheets

- [x] 6.1 Add the source picker over the shared two-column sheet: active accounts with their active
      pockets as children, no none option
- [x] 6.2 Add the category picker: parents of the current kind with their children, ordered roots
      then children alphabetically, chips beside names, none option offered. Never shown for transfers
- [x] 6.3 Add the recurrence picker: no repetition, weekly, biweekly, monthly, quarterly, yearly, with
      a checkmark on the selection
- [x] 6.4 Test: a childless parent selects on first tap; an expanded parent selects on second tap; a
      child selects; the none option clears
      EDIT: first landing's test helpers returned a pending `Future` from an `async` function, which
      Dart auto-flattens, so `await openSheet(...)` silently blocked on sheet dismissal instead of just
      the open. Fixed by capturing the outcome future separately from the open step. Also found and
      fixed a real test-environment issue in the recurrence picker test: the default 800x600 test
      surface clipped the last row (`Yearly`) out of the `ListView` viewport.

## 7. Action button and close-out

- [ ] 7.1 Add the action button: a plain button firing create when it has one action; expanding when a
      scoped screen supplies a second, collapsing before firing
- [ ] 7.2 Run `cd app && flutter analyze && flutter test`. Analyzer at zero issues, not just zero errors
- [ ] 7.3 Confirm no `double` money reached `app/lib/`
- [ ] 7.4 Confirm the derivation functions carry no widget imports — they must be testable without
      pumping a widget
