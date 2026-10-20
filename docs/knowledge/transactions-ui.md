# Transactions UI

Last reconciled: 2026-10-20

## Feature overview

The transactions list and its entry form. The unscoped list is the shell History destination;
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
  entry form in `AppSheet` on the root navigator, and delegates to the container-local
  `NewEntryPresentationController`. Its private Add session owns the duplicate guard, the exact
  `AppSheetRoute`, the only null-form Step subscription, a mount-gated pending Step pickup and one
  completion that settles at `route.completed`. `EntryForm.onDismiss` is supplied only by Add and
  closes exactly that route even under a picker; Edit and view dismissal is unchanged.
  Save, Back, drag or barrier dismissal, route removal, `AppShell` disposal and container
  disposal all retire the session once: the Step subscription closes and the receipt coordinator
  is invalidated in a deferred microtask. Route pop retires the session at `route.popped`;
  presentation ownership and its completion release at `route.completed`. A failed save keeps
  the session and draft.
- `app/lib/ui/transactions/entry/steps/entry_step_handlers.dart` — the shared source, destination,
  category, recurrence, date, end-date and document-crop Step handlers used by both the presenter
  and `TransactionsFlow`, presented above the sheet through the root navigator.
- `app/lib/ui/transactions/receipt_scan/` — the OCR entry hook (see `ocr-receipt-entry.md`).
- `app/lib/ui/transactions/transactions_flow.dart` — the Flow that owns this list's nested navigator.
  It takes an optional `backLabel` passed through to the screen's back control; the shell
  History slot (always mounted, every layout) and scoped lists set none. `TransactionsFlow`
  handles and clears its screen `Step`s directly. `HistoryTrendsRequested` pushes one tracked
  `MaterialPageRoute` holding `StatsFlow(onEnded: ...)` onto the Flow's navigator, where `onEnded` pops that route; the guard releases at
  `route.completed`. Each accepted push invalidates `statsRootViewModelProvider` (fresh Expense and
  Monthly) and seeds `selectedMonthProvider` from History's `selectedDate` at UTC month start. The
  route is retained across destination switches and resizes because the always-mounted Flow state
  persists.
- `app/lib/ui/transactions/trends_detail_action.dart` - 'See more detail', a muted trailing text
  action with chevron and a 48 dp invisible hit height (`trendsDetailActionHitHeight`), rendered
  below the totals bar in unscoped History only, including empty months.
- `app/lib/ui/common/navigation/labelled_back_button.dart` - the back control with an optional
  accessible label, shared by `TransactionsScreen` and `StatsRootScreen`.
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
the Flow (`ui-framework-mvvm.md`). The unscoped `TransactionsFlow` is the shell's History
destination (`ShellDestination.history`); scoped instances live inside Money. Screens pushed: the entry form sheet for an existing entry, the
category/source picker sheets, and the receipt scan screen. New entries open only through the shell's
Add control and shared presenter. The Transactions screen has no local Add or Edit source control.
When Money is selected, the shell reads the top scoped Money route's preferred source through its
constructor-injected observer getter; every other destination and an unscoped Money route open Add
without a source. The presenter captures that source at invocation, installs the sheet route first,
invalidates the null-key form and receipt providers once, binds that initialization attempt to the
session lifetime, and applies the scoped prefill once after the first successful attempt, maps the shell layout mode to the
`AppSheet` presentation (phone, open or desktop), and releases its presentation state and
subscription when the sheet completes or presentation fails. The Add route re-resolves its
presentation live through a resolver reading `ShellLayoutModeScope`, so a
phone/open resize changes only the sheet geometry, alignment and chrome around the retained keyed
form and never replaces the route. A late receipt finish after invalidation writes no state
(`ReceiptEntryCoordinator` checks `ref.mounted` in its asynchronous finally). The account-scoped
screen reuses the same screen with a custom title and `sourceIDs` filter. Back-stack behavior per
destination survives switching because each destination keeps its own navigator. A labelled back
control keeps the existing `BackButton` and `goBack` behavior —
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
- **Entry form** - three modes. New uses the amount-first `NewEntryForm`: kind selector,
  `AddAmountBlock`, then the `NewEntryRows` group. Edit keeps
  `EntryFields`; Add no longer uses it. `NewEntryRows` lays out Name, Category, Account (Transfer:
  From, To), Date, Repeat, Ends (only while recurring), Note, Include in analysis and Add receipt
  (key `new-entry-receipt`, camera icon, empty value, no chevron; hidden when
  `scanStripEnabledProvider` is false), with one `EntryRowDivider` between adjacent rows. The
  receipt row opens a content-height `AppSheet` chooser with the header "Add receipt", the hint
  "Scanning fills in a draft. You check it before saving.", and plain "Scan receipt" (camera icon)
  and "Choose photo" (image icon) rows. It has no Cancel and dismisses by dragging down on phone
  or tapping outside. A choice closes the chooser and calls the keyed form's existing `requestScan`
  with camera or gallery. While scanning, the final row reads "Reading receipt", shows a small
  spinner on the right and ignores taps. The hint "Saving creates a plan. Review it in Money,
  Plans." follows that row directly in recurring drafts, without a divider. Opening the chooser
  unfocuses Amount, Name and Note; returning leaves the pad and IME dismissed. The chooser uses
  the live Add presentation on the root navigator, and the Add session tracks its exact route,
  removes it on retirement and rejects a choice that resumes after retirement. Each row is an
  `AddEntryRow` (`add_entry_row.dart`): 12 dp secondary label on the left, 12 dp w500 primary
  value on the right, 10 dp gap, 8 dp vertical padding while the pad shows and 10 dp otherwise,
  and a 13 dp trailing chevron on picker rows. A row stacks its label above the value when the
  scaled label, gap, 48 dp minimum value and chevron do not fit. Empty values read Choose
  (Category), Select (Account, From, To), Does not repeat and Never.
  Name and Note are inline right-aligned multiline `TextField`s (keys `new-entry-name`,
  `new-entry-note`, minLines 1, no length limit, blank with no hint text) built by one private
  `_InlineTextRow`; each row's label and value share one `TextFieldTapRegion` group id, so tapping
  the focused row keeps focus. A focused Name or Note replaces the divider below it with a 2 dp
  focus-colour underline (`_FocusDivider`). Opening any picker row
  unfocuses the current field first.
  `NewEntryHeader` shows only the title on phone and desktop, and the title with Save in open
  layout (a spacer of equal width keeps the title centered). There is no Cancel in any layout.
  `NewEntrySaveFooter` supplies Save entry in all layouts, driven by `canSave`.
  Desktop uses a dialog without a grab handle; phone supports drag and barrier dismissal, and
  open and desktop dismiss by tapping the barrier.
  (`new_entry_form.dart`, `new_entry_chrome.dart`, `fields/entry_fields.dart`,
  `app/lib/ui/common/sheets/app_sheet.dart`)
  The Add session installs its route before the form loads: a disabled shell with loading
  placeholders while initializing, the same shell with a "Couldn't load the entry form" alert and
  Retry on failure. `entryFormViewModelProvider` opts out of automatic retry
  (`retry: (_, _) => null`), so only the session's explicit Retry re-initializes; scoped source
  prefill applies once on the first success. Save failures keep every field and project a
  "Could not save entry" alert outside the sheet; a fresh save attempt clears a previous save
  error, and concurrent or post-dismissal saves create no extra entry. The form state carries a
  `noteText` draft (`setNote`); a one-time new-entry save passes it to `Entry`, a recurring save
  passes `signedEntry.note` to the `EntryTemplate` in `_recurringPlanFor` so the plan and every
  generated occurrence carry it, while Edit saves keep reading the latest persisted note. Account/category labels and icon data resolve through
  `entryFormDisplayProvider`, an autoDispose projection of the raw draft and current ledger state
  that listens to `Ledger` notifications without rebuilding the draft; unresolvable selections
  show "Unavailable account" / "Unavailable category".
  View existing ("Entry", leading ‹ Back, trailing ✎ Edit). Edit existing ("Edit Entry", leading ✕
  Back reverts fields to persisted values and drops to view mode with the sheet open). Fields: kind
  segmented (changing kind clears the selected category), amount, name, date, source pickers
  (plus a To row for transfers, else a Category row), and an "Include in Analysis" toggle (Edit
  and view; Add rows are described above, and recurrence with Ends exists only in Add). `canSave` is a pure function that requires a category for expense and income (transfers and system entries such as an opening balance have none), so Save stays disabled until one is chosen for a user entry; deeper rules are the
  domain validator's job and surface via the `ErrorSection` ("Could not save entry: <error>"). Save
  semantics: sign is applied from kind; edit stays open and flips to read-only; new without
  recurrence calls `addEntry`; new with recurrence builds an `EntryTemplate` and calls `addPlan`
  with `anchor = date` and `lastResolvedDate = date − 1 s` so the anchor day resolves, then calls
  `resolvePlans`. A saved or cancelled new entry resets on the next open through provider
  invalidation. Drag, barrier dismissal and Back dismiss Add without creating an entry.
- **Picker sheets** - `TwoColumnPickerSheet` expands a parent into the detail column and selects a
  childless parent or child; side-by-side columns scroll independently, and the Add `AppSheet` variant stacks the child list under its parent for the phone presentation at any width, and for open or desktop when two columns cannot hold the longest measured word without a mid-word break. Every Add picker is an `AppSheet` with `dragToDismiss`, so it drags down to dismiss on phone and dismisses by tapping outside, and its header has no Cancel; a dismissal applies nothing. The header keeps its title centered in the sheet when it fits and otherwise gives it all the space between the leading and trailing controls on one line (`AppPickerHeader` over `NavigationToolbar`). Year selection in the date sheets follows the sheet's drag dismissal: `SheetDismissScrollConfiguration` gives the calendar's vertical scrollables `SheetDismissPhysics` (`app/lib/ui/common/sheets/sheet_drag_dismiss.dart`). The date and end-date sheet header is Today (leading), title, Done (trailing), with no bottom Today link; Done applies the draft and Today selects today. The date sheet removes ambient `MediaQuery` padding around `CalendarDatePicker`. The cancel-free sheets deliberately differ from the approved reference frames, which draw Cancel. The legacy `TwoColumnPickerSheet` modal (Account form) also has no Cancel and dismisses by the modal sheet's own drag and barrier. `SourcePickerSheet` shows
  active accounts with active pockets as children and no None option. `CategoryPickerSheet` uses
  `EntryFormViewModel.categoryGroups`, ordered roots then children A–Z, offers no None option, and is never
  shown for transfers. `RecurrencePickerSheet` offers One time, Weekly, Biweekly, Monthly,
  Quarterly, and Yearly; its Add presentation (`sheetPresentation` set) offers Does not repeat,
  Every week, Every two weeks, Every month, Every three months and Every year
  (`addFrequencyLabels`, `addNoRepeatLabel`). The Ends row calls `requestPickEnds`, which emits
  `PickEndsRequested`; the shared handler (`_pickEnds`, Add with a live resolver and a selected
  recurrence only) opens `showEndsChoiceSheet` (Never or Choose date, an `AppSheet` without a
  reference frame) and Choose date awaits `_pickEndDate` directly. A dismissed choice or calendar
  changes nothing, Never sets `hasEndDate` false and keeps the cached date, and
  `applyPickedEndDate` sets `hasEndDate` and `endDate` together. Add passes its live sheet-presentation resolver to category, account,
  repeat, receipt, and date pickers, which use `AppSheet`; without that resolver, category, account, and
  repeat use their legacy modal sheets and date uses `showDatePicker` for Edit and view flows.
  Picker option chevrons indicate parent drill-in; Add picker rows (Category, Account, From, To,
  Date, Repeat, Ends) carry trailing chevrons, Edit rows do not.
  (`app/lib/ui/common/pickers/`, `app/lib/ui/transactions/entry/new_entry_presenter.dart`,
  `app/lib/ui/transactions/entry/steps/entry_step_handlers.dart`)
- **Shell Add** — phone bar, open rail and desktop sidebar share one callback to the presenter. Transactions
  retains date selection, mode switching, filtering, row view/edit and Back behavior.

## Add input and dismissal

- Phone and open Add autofocus Amount and show `NumberPad` while Amount owns focus. The Amount
  field uses `TextInputType.none`; Name uses the system keyboard. Desktop uses the system numeric
  keyboard for Amount and never mounts the pad. A tap outside the focused field unfocuses it;
  a drag exceeding touch slop preserves focus. Tapping anywhere in `AddAmountBlock` requests Amount
  focus and reopens the pad. Closing the Name or Note keyboard restores Amount focus on phone and open.
  A picker return leaves both input surfaces dismissed until the user taps Amount or a text field.
  (`app/lib/ui/transactions/entry/new_entry_form.dart`, `add_amount_block.dart`)
- `AnimatedInputSurface` animates pad entry for 240 ms and exit for 200 ms, retaining the outgoing
  pad until its exit settles. Phone Add interpolates `AppSheet.phoneMaxHeightFraction` from 0.66
  to 1.0 only while the pad is visible or a keyboard inset (`viewInsets.bottom > 0`) is present,
  allowing the sheet to grow toward the top safe area. Focusing Name or Note, or tapping a row,
  with neither present leaves the height unchanged. Reduced motion settles the pad and height change immediately.
  (`app/lib/ui/transactions/entry/animated_input_surface.dart`, `new_entry_form.dart`)
- An outgoing pad and rising keyboard can coexist in a handoff frame. Reserved pad height is clamped
  to `max(0, 192 - keyboardInset)` dp, so their combined reserved height stays at most one pad
  height while the keyboard inset is at most 192 dp; larger insets reserve only keyboard space.
  The pad remains through Add route exit to avoid collapsing the outgoing form.
  (`AnimatedInputSurface._surfaceFactor`, `_NewEntryFormState.build`,
  `app/test/ui/transactions/entry/new_entry_pad_motion_test.dart`)
- Phone Add follows downward drags from the handle, header or body at its minimum scroll offset.
  A downward body drag first consumes any remaining scroll distance. Release dismisses when the
  sheet displacement exceeds 25% of its height or downward velocity exceeds 700 dp/s; shorter
  drags spring back over 200 ms, settling immediately with reduced motion. Dismissal discards
  the unsaved draft and retires the Add session; the next Add invalidates its form provider.
  (`app/lib/ui/common/sheets/sheet_drag_dismiss.dart`, `_SheetScrollBody`,
  `app/lib/ui/transactions/entry/new_entry_presenter.dart`,
  `app/test/ui/transactions/entry/new_entry_sheet_drag_test.dart`)

The amount-first host renders the reference row shell described under Entry form. Repeat is its
own row, not a button beside Date. Receipt input uses `showReceiptChoiceSheet` and
`PickReceiptRequested`. `ReceiptScanStopHost` stays mounted independently of the receipt preference,
listens for `scanStop`, shows "Camera or photo library access was denied." for permission denial,
and calls `clearScanStop` after consuming an occurrence. Scan prefill updates Name, Amount and Date
while preserving Note, recurrence and analysis. The existing crop dispatch and coordinator's
captured initiating-Ref guards continue to reject late results after Add retirement.
`noteText` is the draft behind the inline Note row; the host retains the Note controller
and focus node beside Name's; Note focus alone does not change the phone sheet height.
(`app/lib/ui/transactions/entry/new_entry_form.dart`, `new_entry_rows.dart`,
`entry_form_state.dart` - `EntryFormViewState.noteText`,
`app/lib/ui/common/pickers/receipt_choice_sheet.dart`,
`app/lib/ui/transactions/receipt_scan/receipt_scan_stop_host.dart`,
`app/lib/ui/transactions/receipt_scan/receipt_entry_coordinator.dart`)

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
