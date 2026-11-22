# Overview UI

Last reconciled: 2026-11-22

## Feature overview

The Overview screen renders `DisplayPreferences.overviewWidgets` in stored order, one slot per
`OverviewWidgetKind`, below the header. `OverviewSlotGrid` reads the list through
`displayPreferencesProvider`, passes it through `overviewWidgetsOrDefault` and lays the slots that map to a card out as a waterfall (masonry) in a
column grid. Columns, and cards stacked within a column, are separated by the named 10 dp tray gap
(`overviewTrayGap`). The grid has one column on phone and three
columns on open. On desktop it has three columns when the window is 1250 dp wide or more
and two columns below that. Open and desktop drop to one column while the shell presents Overview as
`ShellPagePresentation.singleColumn`, which happens whenever an AppSheet covers the shell: Add entry,
Edit entry opened from a Recent row, or any other sheet over the shell. Every layout also drops to one
column when a column would be narrower than 220 dp. The grid measures that width itself through a
`LayoutBuilder`, after the sidebar, the open rail gutter, the page padding and any split. The window
width that selects the desktop threshold is `MediaQuery.sizeOf(context).width`, the logical width of
the whole window, not the width of the content pane. `overviewColumnCount` in
`overview_grid_placement.dart` is the pure rule that combines these inputs.

Each kind has a column span from `overviewColumnSpan`. Today, Recent entries and Spending over time
span two columns and every other kind spans one. Cards keep their natural height and are
taken in stored order. `placeOverviewCard` puts each card at the top of the shortest column. A
two-column card takes the adjacent column pair that wastes the least space under the shorter column,
then the lower top, then the leftmost pair. With one column every card stacks in stored order. With
two columns each spanning card takes both columns. Only kinds that map to a card take part in
placement. The default list is Today, This month, Recent entries and Coming up.
`overviewCardFor` (`overview_slots.dart`) is the single kind-to-card mapping, an exhaustive switch
with no default. Each `OverviewCard` carries a `title`, a `subtitle`, a `question` and the `build`
function that creates the widget. Only `today`, `thisMonth`, `recentEntries` and `comingUp` map to a
card; the other eight kinds map to null and render nothing, with no placeholder. A card ticket adds a
kind by replacing its null arm. `overviewSlotFor` is a thin wrapper over `overviewCardFor` that returns
the built widget, and `overviewCardKinds` lists the kinds that have a card in enum declaration order
as the Edit Overview catalogue.

Overview never renders empty. When the stored list holds no card kind, either because it is empty or
because it holds only kinds without a card, `overviewWidgetsOrDefault` returns
`DisplayPreferences.defaults.overviewWidgets` and the grid renders that list. A stored list with at
least one card kind passes through unchanged, kinds without a card included. The stored value is not
rewritten when the screen renders; it changes only when the user taps Done in Edit Overview.

The header carries an 'Edit Overview' action that opens the Edit Overview sheet, described in its own
section below. With the default list no
section is ever blank: each section renders its own copy for an empty ledger, and a section whose
read has not settled renders a `LoadingSkeleton`. The screen reads only through `AnalysisQueries`;
widgets compute no totals.

## Key files

- `app/lib/ui/overview/overview_view_model.dart` - `OverviewViewModel` (abstract), `OverviewNotifier`
  (`AsyncNotifier` with `LedgerBackedNotifier`, `overviewViewModelProvider`), `OverviewViewState`,
  and the row types `OverviewEntryRow` and `OverviewUpcomingRow`, and the This month types
  `OverviewThisMonth` (caption and optional figures) and `OverviewMonthFigures` (signed value strings
  and `netKind`). The view state carries an
  `OverviewStep` (`HasStep`/`StepEmitting`); `requestHistory` emits `OverviewHistoryRequested`,
  `requestBudgets` emits `OverviewBudgetsRequested`, `requestEditOverview` emits
  `OverviewEditOverviewRequested`, `openEntry` emits `OverviewEntryRequested` and `clearStep` clears it. `OverviewEntryRow.entryId`
  identifies the entry a Recent row opens. Rebuilds preserve a pending step.
- `app/lib/ui/overview/overview_screen.dart` - `OverviewScreen` and its header, which holds the 'Edit
  Overview' action wired to `requestEditOverview`; the body places
  `OverviewSlotGrid` under the header. `OverviewScreen` takes `layoutMode` (default phone) and
  `presentation` (default full page) and passes both to the body, so direct fixtures keep the
  single-column stored-order behavior. The Recent entries tray (`overview_recent_section.dart`)
  ends in the shared `AppLinkButton` (action colour, trailing chevron) labelled 'View History', shown for nonempty, empty
  and section-loading rows.
- `app/lib/ui/overview/overview_slot_grid.dart` - `OverviewSlotGrid`, a `ConsumerWidget` that watches
  `overviewWidgets`, collects the present slots and reads the window width from `MediaQuery`. It
  returns a `LayoutBuilder` whose private `_OverviewSlotWaterfall` renders one `OverviewWaterfall` on
  every layout. Each slot is an `OverviewWaterfallSlot` keyed `ValueKey(kind)` with its column span.
- `app/lib/ui/overview/overview_waterfall_layout.dart` - `OverviewWaterfall`, `OverviewWaterfallSlot`
  and `RenderOverviewWaterfall`. The render box lays each child out at its column-span width with an
  unbounded height, asks `OverviewWaterfallColumns` for the column and top from the real heights, and
  relayouts when a card height changes.
- `app/lib/ui/overview/overview_grid_placement.dart` - the pure rules: `overviewColumnCount`,
  `overviewColumnSpan`, `placeOverviewCard` and `OverviewWaterfallColumns`, which owns the column-bottom
  bookkeeping. Their named constants
  (column counts, spans, the 1250 dp desktop threshold and the 220 dp column floor) are in the Layout
  section of `overview_constants.dart`.
- `app/lib/ui/overview/overview_slots.dart` - `OverviewCard`, `overviewCardFor` (the single
  kind-to-card switch carrying title, subtitle, question and builder), `overviewSlotFor` (a thin wrapper
  over it), `overviewCardKinds` (the editor catalogue) and `overviewWidgetsOrDefault` (the seeding
  rule). `thisMonth` maps to `ThisMonthTray`.
- `app/lib/ui/overview/overview_edit_draft.dart` - `OverviewEditDraft`, the pure value class behind
  Edit Overview, with no Flutter imports: `kinds`, `cardKinds`, `shown`, `canHide`, `addable`,
  `isAdded`, `hide`, `add`, `moveShown`, `restoreDefault` and `applyTo`.
- `app/lib/ui/overview/overview_edit_sheet.dart` - `openEditOverview` (the presenter) and
  `EditOverviewSheet`, which holds the draft and the current view and builds the Shown, Add widgets
  and Add widgets view rows.
- `app/lib/ui/overview/overview_this_month_section.dart` - `ThisMonthTray` (the card, with the failed,
  skeleton, empty and figures states), `ThisMonthFigures` (the Spent, Income and Net rows and the
  caption), `ThisMonthCaption` and `ThisMonthFigureRow`.
- `app/lib/ui/overview/overview_rows.dart` - `OverviewLoadError`, the failed-read message and filled
  Retry button shared by the Today and This month trays, a thin wrapper over `LoadErrorView.box`.
  The same file holds `OverviewRowFrame` (the bottom edge between rows), `OverviewAmountText` (a
  padded shared `AmountText`) and `OverviewEmptyCopy` (caption-role subtext copy).
- `app/lib/ui/overview/overview_flow.dart` - `OverviewFlow` (`FlowBase`) subscribing to
  `OverviewStep` once, calling its required `onHistorySelected` callback for history requests, its
  required `onBudgetsSelected` callback for budget requests, `openEditOverview` for Edit Overview
  requests and `openEditEntry` for entry requests.
  `BootChrome` supplies both callbacks (`app/lib/ui/shell/boot_chrome.dart`). It supplies its page
  through `ShellPaneHost`. Its page builder
  passes the layout mode from `ShellPaneScope` and the page presentation to `OverviewScreen`.
- `app/lib/ledger/analysis/summaries/today_summary.dart` - `TodaySummary` carries `spent`, `dailyGuide` and
  `monthlyCap`.
- `app/lib/ui/transactions/daily_list/transaction_row.dart` - `transactionRow` supplies titles,
  account lines, symbols and amount kinds for entries and projected plan occurrences.
- `app/test/ui/overview/` - view model tests, the `overview_screen_test.dart` button-to-step tests
  (320x760), `overview_grid_placement_test.dart`, `overview_slots_test.dart` (card kinds and the
  seeding rule), `overview_edit_draft_test.dart` (the draft), `overview_edit_sheet_test.dart` (the
  sheet's two widget cases) and the shared fixture.

## Edit Overview

The header's 'Edit Overview' action calls `OverviewViewModel.requestEditOverview`, which emits
`OverviewEditOverviewRequested`. `OverviewFlow` consumes the step once, clears it and calls
`openEditOverview` (`overview_edit_sheet.dart`). That function calls `showAppSheet` with
`shellSheetPresentation`, so the sheet is a bottom sheet on phone and docked on open and desktop. It
is the only entry point. The view state and the notifier do not read the widget list. While the sheet
is up, the existing sheet occupancy shows Overview as one column behind the docked sheet, and Overview
does not preview the draft: the grid changes only after Done.

`EditOverviewSheet` holds an `OverviewEditDraft` seeded once from `overviewWidgetsOrDefault` applied
to the stored `overviewWidgets`, so the sheet always opens with at least one shown card. Every edit
changes only the draft. Done reads the live `displayPreferencesProvider` value, calls
`displayPreferencesProvider.notifier.replace(draft.applyTo(current))` and closes the sheet, so other
display preferences are never overwritten with a stale snapshot. Dragging the sheet down, tapping
outside it and system back close it without calling `replace`, and the draft is discarded with the
route. The header has no Cancel and no leading action; Done is a filled button and is always
enabled.

The draft rules:

- `shown` is the part of `kinds` that has a card, in stored order. `addable` is the card kinds not in
  `kinds`, in catalogue order.
- Stored kinds without a card keep their exact index through Hide, Add and reorder. `moveShown`
  reorders only the shown subsequence and writes it back into the positions that card kinds hold, and
  it takes the final-index convention of `ReorderableListView.onReorderItem`.
- `canHide` is true while more than one kind is shown, and `hide` returns the same draft when it is
  false. The last shown card therefore cannot be hidden, the row's Hide action is disabled, and the
  shown list never becomes empty. The guard also keeps the saved list and the rendered Overview
  identical, because a saved list without a card kind would render as the defaults.
- `add` appends a card kind to the end of `kinds`, and only when the kind is a card kind that is not
  already present.
- Restore default sets `kinds` to `DisplayPreferences.defaults.overviewWidgets`, the four-kind default,
  with no confirmation. It replaces the whole list, so stored kinds without a card are dropped.

The sheet has two views. The edit view shows an intro, the 'Shown on Overview' rows (grip, title,
subtitle and a 'Hide' action), an 'Add widgets' heading over the addable rows (title, subtitle and a
'+ Add' action), a 'See all widgets' link and a 'Restore default' button. When nothing is addable,
for example with the default list, the 'Add widgets' heading and its rows are omitted and 'See all
widgets' stays. The 'See all widgets' link opens the in-sheet 'Add widgets' view, which lists every
card kind with its title and question and shows an 'Added' marker where the kind is in the draft and
a '+ Add' action where it is not. That view has no back control; Done saves and closes from either
view, and dismissal discards from either view.

Reorder happens only by dragging the grip. The Shown list is a `ReorderableListView` with
`buildDefaultDragHandles: false`, non-scrolling physics and shrink-wrapping, and only the grip is
wrapped in `ReorderableDragStartListener`. A drag on the grip wins the gesture arena, so the sheet's
drag-to-dismiss does not start, while a drag anywhere else on the row still reaches the sheet's
dismiss physics. There are no Move up or Move down buttons.

## Module interactions

`OverviewNotifier` is an `autoDispose` provider scoped to the mounted Overview view. Its `build` is
synchronous, so the screen has no whole-screen loading state; only the per-section skeletons below
appear. `build` watches `todayProvider`, `analysisQueriesProvider` and `ledgerSessionProvider`
(through `LedgerBackedNotifier`), so it rebuilds on every `AnalysisQueries` notification and on day
change. A failed build ends in `AsyncError` and shows an error state, never a spinner.
It calls `readToday()`, `readRecent()` and `readUpcoming()` and maps the results. It also calls
`readPeriod(window: monthWindow(today))` and `readRegisterDays(window:)` for that same month.
`readToday()` is a mixed read, so the view state carries `today` only while the read is current for
the Ledger revision and otherwise null, which renders the Today skeleton instead of a stale summary; `readRecent()`
and `readUpcoming()` depend on the Ledger only and are available at once. A null section value
renders a skeleton for that section alone. A failed `readToday()` renders 'Couldn't load today's
spending' and a filled Retry in the Today tray. A failed `readPeriod()` renders 'Couldn't load this
month's totals' and a filled Retry in the This month tray. Both Retry buttons call
`OverviewNotifier.retryReads`, which calls `AnalysisQueries.retry()` to clear the failed evaluations and
request a cache refresh.
Recent entries and Coming up keep rendering. `recordedToday` is
read only beside a current Today summary, so the empty headline never appears over stale data.
`thisMonth` is carried only while the `readPeriod()` result for the current month is current for the
Ledger revision, the same gate as `today`; otherwise the This month tray shows a skeleton. The month
comes from `todayProvider`, so a day rollover into a new month reads the new month at once.
Tapping 'View History' calls `OverviewViewModel.requestHistory`; `OverviewFlow` consumes the
resulting `OverviewHistoryRequested` exactly once and clears it, including requests made before its
Navigator mounts. On every layout `BootChrome` supplies a callback that selects the
`ShellDestination.history` slot (`app/lib/ui/shell/boot_chrome.dart`); the flow pushes no route and
History mounts fresh at the current month with an empty stack, and nothing is carried over from Overview before it mounts.
History has no back-to-Overview control.
The 'Set a monthly cap' link in the Today tray calls `OverviewViewModel.requestBudgets`, which emits
`OverviewBudgetsRequested`. `OverviewFlow` consumes it once, clears it and calls `onBudgetsSelected`.
`BootChrome` wires that callback to `moneySegmentProvider.notifier.openAt(MoneySegment.budgets)`.
`openAt` sets the segment to Budgets and selects the Money destination. The segment is kept while Money
is unmounted, so Money mounts at Budgets with no budget preselected, whichever segment it showed last. Overview does not know about
Money. The link is absent while an unscoped budget exists. While an AppSheet covers the shell, a tap on
the link reaches the modal barrier and only dismisses the sheet. On open and desktop the docked sheet
leaves the link visible, so the first tap dismisses the sheet and a second tap navigates.
Recent entries rows are tappable: `OverviewViewModel.openEntry` emits `OverviewEntryRequested` only
for entries active in the ledger, and `OverviewFlow` calls `openEditEntry`
(`app/lib/ui/transactions/entry/edit_entry_presenter.dart`). The Edit entry sheet presents over the
Overview tab and does not change the shell selection.

## Read definitions

- Today: expense items dated today. The daily guide and `monthlyCap` come from the unscoped
  budget's limit. Without an unscoped budget both are null and the tray
  shows 'Set a monthly cap to see a daily guide.' with a 'Set a monthly cap' link.
- Today shows 'Nothing recorded today' instead of an amount when no active entry is dated today
  (`OverviewViewState.recordedToday`), so an unknown day is never drawn as zero spending.
- This month: committed spent, income and net over `[monthStart, nextMonthStart)` for the month of
  today, from `readPeriod`. Entries dated after today count. A transfer counts only when its treatment
  makes it an expense or income item, as in `readPeriod`. Spent is the period's expense total negated.
  Each figure is a value-signed string without a currency symbol (`formatSignedMoney`). The net colour
  comes from `netKind` through `AmountStyle`: income when positive, expense when negative, and the text
  colour when zero. The caption is the month name only. The month is empty when `readRegisterDays` for
  it holds no active entry of any kind, so an empty month is judged by entries and not by zero totals;
  an empty month shows 'No entries this month' with the month name below it. When the register read has
  no value, the figures show. The month name sits under the figures, and the bottom divider of the Net
  row separates them.
- Recent entries: at most 4 active entries dated before tomorrow, newest first; same-day entries
  order by id descending. A row caption is
  '<Today or d MMM> / <category> / <account line>' and the title is the entry name, falling back to
  the category title.
- Coming up: the next 42 days from `readUpcoming()`, in its date order. A statement row reads
  '<card> statement closes' with 'This cycle so far: <amount>' and a card icon in place of an
  amount. Plan occurrences read 'Plan / <account line>' and dated-ahead entries read
  'Dated ahead / <account line>'.

## Gotchas and invariants

- Slot keys are `ValueKey(kind)`, so a reorder keeps slot state. Kinds must be unique: the grid collects
  slots into a map by kind, so a duplicate would render once without an error. The preferences store
  de-duplicates and drops unknown codes.
- All layouts render the slots through one `OverviewWaterfall`, so every slot stays a keyed sibling
  of the same parent. A reorder, a window resize across 1250 dp and opening or closing a sheet all
  keep each slot's state. Per-column widgets would remount a card that changes column, and
  `IntrinsicHeight` would forbid a `LayoutBuilder` inside a future card, so the render box measures
  each card itself and has no intrinsic sizes.
- Placement depends on rendered heights, so a card whose height changes (a skeleton becoming
  content) moves every later card. Tests prove the pure rule and the column count wiring, never the
  geometry.
- Placement never reorders cards, so some space cannot be removed. With column bottoms of 100, 400
  and 100, a two-column card goes at the top of 400 and leaves a 300 gap above it. The bottom edges
  of the last cards are also ragged.
- Placement runs only over kinds with a card, so the eight unmapped kinds never take a cell.
  `spendingOverTime` has a span of two but no card yet, so its span is covered only by the pure tests
  until its card ships.
- Any AppSheet that covers the shell collapses Overview to one column on open and desktop, not only
  Add entry and Edit entry.
- On open, a window about 780 dp wide or narrower (680 dp of grid for three columns, plus 28 dp of
  page padding and the 72 dp rail gutter) renders one column, because three columns would be narrower
  than 220 dp.
- `OverviewNotifier` and `OverviewViewState` do not depend on the widget list; the notifier stays
  synchronous and ledger-derived.
- The 'Set a monthly cap' link is a `MonthlyCapAction` button with a 48x48 minimum tap target. Its
  tap opens Money at Budgets. Under a covering sheet it only dismisses that sheet, as described under
  Module interactions.
- 'View History' is a real action; it stays reachable for empty and section-loading Recent
  entries, not only for nonempty rows.
- The This month card is deliberately untappable. It sends no History request and emits no step, so a
  tap does nothing.
- The This month card is in the default list. A stored `overviewWidgets` list without `thisMonth` hides it.
- Very large figures (7-8 digits) can overflow at the narrowest 220 dp column with 2x text. Recent
  entries rows can overflow the same way.
- The header has the 'Edit Overview' action. The gear of the reference frame is still not rendered.
- Notices above the sections (save retry, plan attention) are not part of this screen. The
  shell's `StatusBanner` owns notice display.
- The fresh-install framing of the reference ('Start with an account' tray, 'Add your first entry'
  link) is not rendered.
- `OverviewFlow` is mounted by `AppShell` as the default `overview` destination on both
  layouts (`app/lib/ui/shell/app_shell.dart`, `app/lib/ui/shell/boot_chrome.dart`); tests may still
  mount it directly.
- `OverviewFlow` uses `ShellPaneHost` when a `ShellPaneScope` is present. Direct Overview fixtures
  keep the standalone screen behavior.
- Every visual value in `overview_screen.dart` is a named constant. Coming up rows pass the date
  column to `MedallionRow.leading`, which replaces the medallion. That column is the shared `DateBadge`
  (`app/lib/ui/common/lists/date_badge.dart`), built in `UpcomingRowContent`
  (`app/lib/ui/overview/overview_coming_up_section.dart`). Plans rows use the same badge.

## Requirements

- Section order is the stored `overviewWidgets` order. A stored list with no card kind, either empty
  or holding only kinds without a card, renders as `DisplayPreferences.defaults.overviewWidgets`
  through `overviewWidgetsOrDefault`, so Overview never renders empty. A list with at least one card
  kind is returned unchanged, kinds without a card included
  (`app/test/ui/overview/overview_slots_test.dart`: 'an empty list becomes the defaults', 'a list with
  only cardless kinds becomes the defaults', 'a list with a card kind is returned unchanged'). The
  grid's use of the function has no widget test.
- `overviewCardKinds` lists the kinds with a card in declaration order
  (`app/test/ui/overview/overview_slots_test.dart`: 'overviewCardKinds lists the card kinds in
  declaration order').
- Recent entries never exceeds 4 and sorts newest first
  (`app/test/ui/overview/overview_view_model_test.dart`).
- 'View History' is shown for nonempty, empty and section-loading Recent entries, and requests the
  History page (`app/test/ui/overview/overview_screen_test.dart` for the request; the shown states
  have no widget test).
- Coming up excludes dates at or beyond 42 days
  (`app/test/ui/overview/overview_view_model_test.dart`).
- The column count follows the layout mode, the shell presentation, the window width and the 220 dp
  column floor. Waterfall placement picks the shortest column or the least wasteful column pair
  for each card (`app/test/ui/overview/overview_grid_placement_test.dart`).
- Overview renders its slots in stored order and uses three columns on open and on desktop at 1250 dp
  or wider, two columns on narrower desktop windows and one column on phone or while a sheet covers
  the shell. The column rule is covered by `app/test/ui/overview/overview_grid_placement_test.dart`;
  the shell-scope wiring has no widget test.
- The 'Set a monthly cap' link is shown only without an unscoped budget, and tapping it emits
  `OverviewBudgetsRequested` (`app/test/ui/overview/overview_screen_test.dart`,
  `app/test/ui/overview/overview_view_model_test.dart`). Overview's `requestBudgets` step is consumed
  and cleared (`app/test/ui/overview/overview_view_model_test.dart`).
- Money opens at the Budgets segment from Overview, selects the Money destination and mounts no budget
  detail (`app/test/ui/shell/destination_lifetime_test.dart`). The segment provider keeps its value
  while Money is selected and resets to Accounts after Money is left
  (`app/test/ui/accounts/money_segment_test.dart`).
- With an Edit entry sheet over Overview without a cap, a tap on the link only dismisses the sheet:
  no budgets step is emitted and the destination does not change
  (`app/test/ui/overview/overview_recent_edit_test.dart`).
- This month sums committed spent, income and net for the current calendar month, dated-ahead entries
  included, captions the month name and carries the net kind for its colour
  (`app/test/ui/overview/overview_content_test.dart`, group 'This month': 'sums the seed month into
  caption and signed figures', 'counts only the current month, dated ahead included').
- A transfer-only month shows zero figures with the transfer net kind
  (`app/test/ui/overview/overview_content_test.dart`: 'a transfer-only month still shows zero figures').
- An empty month carries its caption and no figures. The 'No entries this month' copy has no widget test
  (`app/test/ui/overview/overview_content_test.dart`: 'an empty month has a caption and no figures').
- This month stays pending until the period read is current for the Ledger revision, and Today and This
  month both wait during a pending refresh
  (`app/test/ui/overview/overview_content_test.dart`: 'stays pending while analysis computes and rows still
  show', 'shows Today as loading until it catches up with the ledger').
- A failed period read sets the failed flag, and Retry recomputes. The failure copy and the Retry button
  have no widget test (`app/test/ui/overview/overview_view_model_test.dart`: 'failed Today and This month
  reads are flagged and Retry recomputes').
- A day rollover reads the new month with the day
  (`app/test/ui/overview/overview_view_model_test.dart`: 'This month rolls over to the new month with the day').
- A stored `thisMonth` renders once in stored order, and a replaced list without it removes the card.
  This has no widget test.
- AC6, the This month card is untappable, has no test. The owner skipped it.
- The Edit Overview draft derives `shown` and `addable`, hides and adds kinds, keeps kinds without a
  card at their exact index through every edit, refuses to hide the last shown kind, restores the
  four-kind default and applies itself to the other display preferences unchanged
  (`app/test/ui/overview/overview_edit_draft_test.dart`). An injected fifth card kind appears in
  `addable`, which proves that a future card shows up in the editor with no other edit.
- `requestEditOverview` emits `OverviewEditOverviewRequested`, and `clearStep` clears it
  (`app/test/ui/overview/overview_view_model_test.dart`: 'requestEditOverview emits an edit-overview
  request that clearStep clears').
- On phone, dragging a grip reorders the list without dismissing the sheet, and Done saves the new
  order to `overviewWidgets`
  (`app/test/ui/overview/overview_edit_sheet_test.dart`: 'grip drag reorders without dismissing and
  Done saves'). Tapping outside after a Hide discards the draft and leaves `overviewWidgets`
  unchanged (same file: 'tapping outside after a Hide discards'). Both cases assert preference values
  and the presence of the sheet only.
- These behaviors have no widget test: the docked presentation on open and desktop, the 'Edit
  Overview' header action opening the sheet, the Add widgets view and its Added markers, Restore
  default in the sheet, the disabled Hide on the last shown row, and the omitted 'Add widgets' heading.
  The draft rules behind them are covered by the unit tests above. Restart persistence rests on
  `displayPreferencesProvider.notifier.replace` and the preferences store round trip
  (`app/test/settings/display_preferences_provider_test.dart`).
