# Transactions UI

Last reconciled: ae736584

## Feature overview

The transactions list and its entry form. The unscoped list is the shell History destination;
scoped lists live inside Money. Both show a month-navigated, day-sectioned register and render
account-scoped with a custom title and source filter. One amount-first form creates entries (Add)
and edits existing ones (Edit entry); Add is the only place recurring plans are created.

## Key files

- `app/lib/ui/transactions/transactions_view_model.dart` - screen state (`selectedDate`, optional
  source scope); the visible register is derived from `(LedgerState, params)`.
- `app/lib/ui/transactions/top_categories_view_model.dart` and
  `top_categories_view_state.dart` - the History top-categories period key, immutable projection,
  state variants and Retry interface; the card widget and History placement are separate.
- `app/lib/ui/transactions/daily_list/daily_transactions_screen.dart` - History-local heading,
  month controls and day-sectioned register host.
- `app/lib/ui/transactions/daily_list/transactions_summary.dart` - `TransactionsSummary`, the
  state-free responsive Net/Spent/Income band shared by unscoped History and scoped Money routes.
- `app/lib/ui/transactions/monthly/month_summaries.dart` - shared month/week projection helper;
  it remains available to other consumers although Transactions no longer presents that view.
- `app/lib/ui/transactions/entry/` - the entry form, shared by Add and Edit entry.
- `app/lib/ui/transactions/entry/edit_entry_presenter.dart` - `openEditEntry` and the
  container-scoped `EditEntryPresentationController`: duplicate-open guard, invalidation of
  `entryFormViewModelProvider(entryId)` on every open so each open starts from persisted values, and
  one owner per entry through claim tokens (`claim`, `owns`, `release`).
- `app/lib/ui/transactions/entry/edit_entry_host.dart` - `EditEntryHost`: claims ownership,
  subscribes to the form view model, dispatches its Steps from its own context with
  `sheetPresentation: shellSheetPresentation` and `onPickerRouteCreated`, removes still-active
  picker routes on dispose, and shows the load alert with Retry. Hosted in a sheet or in the History
  detail pane (`EntryFormFrame.sheet` or `.pane`).
- `app/lib/ui/transactions/history_entry_selection.dart` - `historyEntrySelectionProvider`
  (autoDispose), the selected History entry id for the detail pane. It is a
  `HistoryEntrySelectionNotifier`, which extends the shared `IdSelectionNotifier`
  (`app/lib/ui/common/base/id_selection.dart`) and overrides `build` to keep its phone-mode reset.
- `app/lib/ui/transactions/entry/new_entry_presenter.dart` - the shared Add presenter
  (`openNewEntry`): reads `shellLayoutModeProvider` from the caller-side ref, opens the null-key
  entry form in `AppSheet` on the root navigator, and delegates to the container-local
  `NewEntryPresentationController`. Its private Add session owns the duplicate guard, the exact
  `AppSheetRoute`, the only null-form Step subscription, a mount-gated pending Step pickup and one
  completion that settles at `route.completed`. `EntryForm.onDismiss` is supplied only by Add and
  closes exactly that route even under a picker; Edit dismisses through `EditEntryHost.onDismiss`.
  Save, Back, drag or barrier dismissal, route removal, `AppShell` disposal and container
  disposal all retire the session once: the Step subscription closes and the receipt coordinator
  is invalidated in a deferred microtask. Route pop retires the session at `route.popped`;
  presentation ownership and its completion release at `route.completed`. A failed save keeps
  the session and draft.
- `app/lib/ui/transactions/entry/steps/entry_step_handlers.dart` - the shared source, destination,
  category, recurrence, date, end-date and document-crop Step handlers used by both hosts,
  presented above the sheet through the root navigator. `dispatchEntryFormStep` requires
  `sheetPresentation`; there is no legacy modal or `showDatePicker` fallback.
- `app/lib/ui/transactions/receipt_scan/` - the OCR entry hook (see `ocr-receipt-entry.md`).
- `app/lib/ui/transactions/transactions_flow.dart` - the Flow that owns this list's nested navigator.
  It takes an optional `backLabel` passed through to the screen's back control; the shell
  History slot (every layout) and scoped lists set none. `transactionsViewModelProvider`
  is an autoDispose family keyed by the optional `TransactionsScope`, so History and each scoped list
  keep separate state that lasts while their Flow is mounted. `TransactionsFlow`
  handles and clears its screen `Step`s directly. `HistoryTrendsRequested` pushes one tracked
  `MaterialPageRoute` holding `TrendsFlow(onEnded: ...)` onto the Flow's navigator, where `onEnded` pops that route; the guard releases at
  `route.completed`. The push seeds nothing from History's selected date. The route and
  History's state survive resizes while History is selected, and are discarded when another
  destination is selected and History unmounts.
- `app/lib/ui/transactions/trends_detail_action.dart` - 'See more detail', a muted trailing text
  action with chevron and a 48 dp invisible hit height (`trendsDetailActionHitHeight`), rendered
  below the totals band in unscoped History only, including empty months.
- `app/lib/ui/common/navigation/labelled_back_button.dart` - the back control with an optional
  accessible label, shared by `TransactionsScreen` and `TrendsScreen`.
- `app/lib/ui/common/lists/day_sectioned_entry_list.dart`, `form_scaffold.dart`,
  `swipe_row.dart`, `pickers/` - shared components and picker sheets.
- `app/lib/ui/symbol_map.dart` - symbol-to-IconData mapping.

## Module interactions

`TransactionsNotifier` builds its state synchronously, so the list has no loading state; a failed
build ends in `AsyncError` and shows an error state. It watches `todayProvider`, listens to the
ledger itself (the listener is removed in `onDispose`) and rebuilds the day sections and the
income and expense totals on each change, keeping `selectedDate` and the pending `Step` from its
previous `state.value`. It calls `Ledger` mutation methods and holds no `LedgerState` beyond the
state it derives from. Row resolution and section grouping are pure Dart
functions in the application layer, unit-tested independently of any widget. Totals apply only
entry-level `includeInAnalysis`, so Transactions and analysis-driven totals can diverge for the
same month when category inclusion gates exclude entries from analysis
(`packages/domain/lib/src/accounting.dart:Accounting.resolveCategory`). Treat-as-expense transfers
contribute equally to both expense totals, as covered by
`app/test/ui/transactions_stats_totals_parity_test.dart`.

The History top-categories ViewModel keys by the named UTC calendar month in Daily mode or calendar
year in Monthly mode, including mode in family identity. It reads the expense/category
`AnalysisQueries.readCategoryBreakdown` and `readRegisterDays` over the same half-open window. Query
failure takes precedence over retained values and stale revisions; pending, missing or mismatched
revisions expose loading. A confirmed empty register or coherent zero-spend empty breakdown exposes
compact state. Ready state keeps the breakdown's full total and the first three query-ranked rows,
including their unchanged whole-window shares, which may sum below 100 percent. Saved category
metadata comes from the current ready Ledger; the shared bucket-name, color and symbol helpers
resolve synthetic, uncategorized, unresolved and malformed metadata fallbacks. Retry delegates to
`AnalysisQueries.retry()` while the family is mounted
(`top_categories_view_model.dart`, `top_categories_view_state.dart`).

## Navigation

The Transactions Flow owns a nested `Navigator` scoped with a `GlobalKey<NavigatorState>` local to
the Flow (`ui-framework-mvvm.md`). The unscoped `TransactionsFlow` is the shell's History
destination (`ShellDestination.history`); scoped instances live inside Money. Screens pushed: the picker sheets and the receipt scan screen; existing
entries open as Edit entry (see Screens and flows). New entries open only through the shell's
Add control and shared presenter. The Transactions screen has no local Add or Edit source control.
The shell reads the top scoped Money route's preferred source on demand
through its constructor-injected getter (`activeMoneySourceProvider`, backed by
`accountsNavigatorKeyProvider`, both in `app/lib/ui/money/money_flow.dart`); every other
destination, the Budgets and Plans segments and an unscoped Money route open Add without a source. The presenter captures that source at invocation, invalidates the null-key form
and receipt providers, starts an attempt bound to the session lifetime and installs the loading sheet
before awaiting the attempt. Scoped prefill applies once on the first success; Retry starts a fresh
form attempt on the same route. It maps the shell mode to phone, open or desktop and releases its
private session after route completion and deferred receipt cleanup.

On phone, the Add sheet covers the shell's tab bar, which stays mounted beneath the route; the sheet
bottom respects the safe area. Add's open route uses `showShellNavigation`: the shell suppresses its
rail and the route renders the rail overlay, whose destination action selects and dismisses the
sheet. Open form chrome clears the rail. The remaining full-window
barrier consumes outside taps and dismisses. Desktop keeps the sidebar beneath that barrier;
tapping it dismisses Add without navigating. (`app/lib/ui/transactions/entry/new_entry_presenter.dart`,
`app/lib/ui/common/sheets/app_sheet_route.dart`, `app/lib/ui/common/sheets/app_sheet.dart`) The Add route re-resolves its
presentation live through a resolver reading `ShellLayoutModeScope`, so a
phone/open resize changes only the sheet geometry, alignment and chrome around the keyed
form and never replaces the route. A late receipt finish after invalidation writes no state
(`ReceiptEntryCoordinator` checks `ref.mounted` in its asynchronous finally). The account-scoped
screen reuses the same screen with a custom title and `sourceIDs` filter. Each destination owns its own
navigator, and a destination's back stack lasts while that destination is selected. A labelled back
control keeps the existing `BackButton` and `goBack` behavior -
inner child routes pop first - and only changes its accessible label; unlabelled flows render a
plain back control.

Shared sheet composition follows installed routes rather than an Add-specific presentation provider.
`AppSheetRoute.install` registers with the optional `shellSheetOccupancyProvider` until
`route.completed`, including exit animation. Nearest-non-AppSheet predecessor coverage preserves
composition through picker stacks. On open and desktop, Add over the shell shifts the current exposed
detail left while keeping the isolated list's Flow and Navigator State mounted. Clearing selection exposes
the list without replacing Add or losing its draft. Desktop sheets always dock in the right column, like open, using
shared safe pane geometry, while `AppSheetPresentation.desktop` keeps desktop input behavior. A sheet over a
foreground root page keeps that page as its predecessor and leaves the
shell unshifted. (`app/lib/ui/shell/shell_sheet_occupancy.dart`,
`app/lib/ui/shell/shell_pane_host.dart`, `app/lib/ui/shell/shell_pane_geometry.dart`,
`app/lib/ui/common/sheets/app_sheet_route.dart`)

## Screens and flows

The screen owns its heading and period controls; `TransactionsSummary` owns the state-free
Net/Spent/Income presentation. The shared `MonthYearSelector` and `ColumnText` remain separate
components. The default title is History; scoped instances retain their custom title, filter and
Back control. The screen passes the existing register totals and shell composition mode into
`TransactionsSummary`. Phone places Net above Spent and Income; open and desktop place all three in
a row when the measured, text-scaled values fit. Narrow widths stack supporting values, and each
amount can scroll horizontally. The header can scroll within half the available height to preserve
register space. The screen applies top and side `SafeArea` insets with `bottom: false`.
(`app/lib/ui/transactions/daily_list/daily_transactions_screen.dart`,
`app/lib/ui/transactions/daily_list/transactions_summary.dart`)

- **Daily view** - day-sectioned list. `daySections` is a pure function: scope to touched entries,
  resolve each to a `TransactionRow`, filter to the half-open interval, group by `startOfDay(date)`,
  sort days descending and rows by timestamp descending. Section aggregates count income and
  negated expenses of entries with `includeInAnalysis == true`. Sticky day headers show the full
  date and bare net in the `AmountStyle` sign colour. `_DailyContent` owns the lazy sliver list,
  pinned day groups and 10 dp gaps between days. It opts into `DayHeaderDelegate(registerStyle: true)`
  and `TransactionCell.register`; the default header and cell constructors retain their existing
  presentation. Each day forms a bordered register card with 14 dp side insets, rounded header
  corners and rounded bottom corners on its last row. The sticky header paints opaque page-base
  backing across its pinned bounds so scrolling rows cannot show through its rounded corners.
  Rows show the note as the primary label,
  falling back to the category title when empty; the secondary label retains category and source
  when a note exists, or source alone otherwise. Icons use the row's symbol and colour, and amounts
  keep signed formatting and `AmountStyle` colours. Tapping a row opens Edit entry (`EntryRow` calls `openEditEntry`).
  The empty state shows an inbox icon and "No transactions".
  Swipe leading-to-trailing opens a "Delete this transaction?" confirmation.
- **Entry form** - one amount-first form serves Add and Edit (`EntryFormMode` is `newEntry` or
  `editing`). `NewEntryForm` shows the kind selector, `AddAmountBlock`, then the `NewEntryRows` group;
  `NewEntryLoadingForm` is its loading shell. Copy follows `state.isEditing` (title "Add entry" or
  "Edit entry", footer "Save entry" or "Update entry"). `EntryForm` is the Add host only.
  `NewEntryRows` lays out Name, Category, Account (Transfer:
  From, To), Date, Repeat, Ends (only while recurring), Note, Include in analysis and Add receipt
  (key `new-entry-receipt`, camera icon, empty value, no chevron; hidden when
  `scanStripEnabledProvider` is false). Edit rows omit Repeat, Ends, the recurring hint and Add
  receipt, keep Note editable, and end with `EditEntryDeleteAction` (key `edit-entry-delete`), with one `EntryRowDivider` between adjacent rows. The
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
  Desktop uses docked form chrome without a grab handle; phone supports drag and barrier dismissal, and
  open and desktop dismiss by tapping the barrier.
  (`new_entry_form.dart`, `new_entry_chrome.dart`, `app/lib/ui/common/sheets/app_sheet.dart`)
  The Add session installs its route before awaiting form initialization: a disabled shell with loading
  placeholders while initializing, the same shell with a "Couldn't load the entry form" alert and
  Retry on failure. `entryFormViewModelProvider` opts out of automatic retry
  (`retry: (_, _) => null`), so only the session's explicit Retry re-initializes; scoped source
  prefill applies once on the first success. Save failures keep every field and project a
  "Could not save entry" alert outside the sheet; a fresh save attempt clears a previous save
  error, and concurrent or post-dismissal saves create no extra entry. The form state carries a
  `noteText` draft (`setNote`); a one-time new-entry save passes it to `Entry`, a recurring save
  passes `signedEntry.note` to the `EntryTemplate` in `_recurringPlanFor` so the plan and every
  generated occurrence carry it, while Edit saves keep reading the latest persisted note. Account/category labels and icon data resolve through
  `entryFormDisplayProvider`, a `Provider.family` projection of the raw draft and current ledger state
  that listens to `Ledger` notifications without rebuilding the draft; unresolvable selections
  show "Unavailable account" / "Unavailable category".
  Edit entry opens directly as an editable `AppSheet` with no read-only step. `openEditEntry` shows
  `EditEntryHost` on the root navigator with the shell sheet presentation resolver (`shellSheetPresentation`). Update entry
  saves and dismisses. Delete entry is the last body action, archives through `Ledger.archiveEntry`
  with no confirmation and dismisses. System entries lock Name, Category and Include in analysis and
  show no Delete; an edit save keeps the entry's `systemKind`. Drag-down, tapping outside or the
  pane's Close discards the draft silently. Fields: kind segmented (changing kind clears the selected category),
  amount, name, date, source pickers (plus a To row for transfers, else a Category row), Note and
  an "Include in analysis" toggle; recurrence with Ends exists only in Add. `canSave` is a pure function that requires a category for expense and income (transfers and system entries such as an opening balance have none), so Save stays disabled until one is chosen for a user entry; deeper rules are the
  domain validator's job and surface via the `ErrorSection` ("Could not save entry: <error>"). Save
  semantics: sign is applied from kind; edit saves and dismisses; new without
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
  `applyPickedEndDate` sets `hasEndDate` and `endDate` together. Add and Edit pass a sheet-presentation resolver to the category, account,
  repeat, receipt, and date pickers, which use `AppSheet`.
  Picker option chevrons indicate parent drill-in; picker rows (Category, Account, From, To,
  Date, Repeat, Ends) carry trailing chevrons in Add and Edit.
  (`app/lib/ui/common/pickers/`, `app/lib/ui/transactions/entry/new_entry_presenter.dart`,
  `app/lib/ui/transactions/entry/steps/entry_step_handlers.dart`)
- **Shell Add** - phone bar, open rail and desktop sidebar share one callback to the presenter. Transactions
  retains date selection, filtering, row edit and Back behavior.
- **Edit entry hosts** - `EntryRow` (day lists, Trends category detail via `FlatEntrySliver`) and the
  budget counted row call `openEditEntry`. `TransactionsFlow` routes `EntryFormRequested` to
  `openEditEntry` for scoped Money lists and for History on phone. On open and desktop layouts the
  unscoped History shows Edit entry in the shell detail pane instead: `_HistoryPaneHost`
  (`transactions_flow.dart`) supplies a `ShellDetail` with the date subtitle and Close, hosting
  `EditEntryHost` with `EntryFormFrame.pane` (`EntryPaneLayout`, which never builds an `AppSheet`).
  `historyEntrySelectionProvider` owns the selection on the shared `IdSelectionNotifier`; it is scoped
  through `shellLayoutModeProvider` and resets when the layout becomes phone. Re-tapping the selected row keeps the draft, selecting
  another row swaps the keyed pane, and `openEditEntry` clears a matching selection. Overview Recent
  entries also call `openEditEntry` (see `overview-ui.md`). Swipe-to-delete on list rows still
  hard-deletes through `Ledger.deleteEntry`.
- **Drafts** - existing-entry drafts live in the keep-alive `entryFormViewModelProvider` family and
  persist until the next open invalidates them.

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
  (`AnimatedInputSurface._surfaceFactor`, `_NewEntryFormState.build`)
- Phone Add follows downward drags from the handle, header or body at its minimum scroll offset.
  A downward body drag first consumes any remaining scroll distance. Release dismisses when the
  sheet displacement exceeds 25% of its height or downward velocity exceeds 700 dp/s; shorter
  drags spring back over 200 ms, settling immediately with reduced motion. Dismissal discards
  the unsaved draft and retires the Add session; the next Add invalidates its form provider.
  (`app/lib/ui/common/sheets/sheet_drag_dismiss.dart`, `_SheetScrollBody`,
  `app/lib/ui/transactions/entry/new_entry_presenter.dart`)

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

- Only one host owns an entry's form at a time: `EditEntryHost` claims the entry id in
  `EditEntryPresentationController`, and a stale host stops consuming Steps once another claims it.
- Delete entry archives without confirmation; swipe-delete on rows is a separate hard delete.
- Amount sanitizer strips to digits and one `.`, max 2 fraction digits, dropped not rounded; only
  the balance field allows a leading `-`.
- Malformed `colorHex` falls back to gray; writing back emits `#RRGGBB` uppercase, components
  clamped 0–255.
- Transactions totals and analysis-driven totals intentionally use different inclusion rules;
  analysis also applies category inclusion gates.

## Requirements

- Screen state (`selectedDate`, scope) lives in a provider, not a widget. The register has no
  Daily/Monthly selector; month summaries remain a shared helper for other consumers.
- `TransactionsViewModel.previousMonth` and `nextMonth` select UTC day 1 of the adjacent calendar
  month, including year rollover, then rebuild the same scoped register and totals. The commands
  leave source scope and custom titles intact.
  (`app/lib/ui/transactions/transactions_view_model.dart`,
  `app/test/ui/transactions/transactions_view_model_test.dart`)
- `daySections`, `TransactionRow.resolve`, and `monthSummaries` are pure functions.
- Interval filters are half-open `[start, end)` everywhere.
- Saving a new entry with recurrence creates a plan with `lastResolvedDate = date − 1 s` and resolves
  immediately.
