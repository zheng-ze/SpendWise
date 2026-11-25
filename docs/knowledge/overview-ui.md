# Overview UI

Last reconciled: 2026-11-25

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
placement. The default list is Today, This month, Recent entries, Coming up and Budget watch.
`overviewCardFor` (`overview_slots.dart`) is the single kind-to-card mapping, an exhaustive switch
with no default. Each `OverviewCard` carries a `title`, a `subtitle` and the `build`
function that creates the widget. Only `today`, `thisMonth`, `recentEntries`, `comingUp` and
`budgetWatch` map to a card; the other seven kinds map to null and render nothing, with no placeholder. A card ticket adds a
kind by replacing its null arm. `overviewSlotFor` is a thin wrapper over `overviewCardFor` that returns
the built widget, and `overviewCardKinds` lists the kinds that have a card in enum declaration order
as the Edit Overview catalogue.

Overview never renders empty. When the stored list holds no card kind, either because it is empty or
because it holds only kinds without a card, `overviewWidgetsOrDefault` returns
`DisplayPreferences.defaults.overviewWidgets` and the grid renders that list. A stored list with at
least one card kind passes through unchanged, kinds without a card included. The stored value is not
rewritten when the screen renders; it changes only when the user taps Done in Edit Overview. A user
who has ever saved a display setting keeps the stored list, so the Budget watch default reaches only
installs that have never saved one.

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
  and `netKind`). `OverviewViewState.budgetWatch` holds the Budget watch rows (`BudgetListCard`) and
  `budgetWatchFailed` flags a failed read. The view state carries an
  `OverviewStep` (`HasStep`/`StepEmitting`); `requestHistory` emits `OverviewHistoryRequested`,
  `requestBudgets` emits `OverviewBudgetsRequested`, `requestEditOverview` emits
  `OverviewEditOverviewRequested`, `openEntry` emits `OverviewEntryRequested`, `openBudget` emits
  `OverviewBudgetRequested` and `clearStep` clears it. `OverviewEntryRow.entryId`
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
  kind-to-card switch carrying title, subtitle and builder), `overviewSlotFor` (a thin wrapper
  over it), `overviewCardKinds` (the editor catalogue) and `overviewWidgetsOrDefault` (the seeding
  rule). `thisMonth` maps to `ThisMonthTray` and `budgetWatch` maps to `BudgetWatchTray`.
- `app/lib/ui/overview/overview_budget_watch_section.dart` - `BudgetWatchTray` (the card, with the
  failed, skeleton, empty and rows states), `BudgetWatchEmpty` and `BudgetWatchRows`, which renders each
  row with `BudgetCard`.
- `app/lib/ui/budgets/budget_list/budget_list_cards.dart` - `budgetListCards` and `BudgetListCard`,
  the row formatter shared by the Budgets list and Budget watch.
- `app/lib/ui/overview/overview_edit_draft.dart` - `OverviewEditDraft`, the pure value class behind
  Edit Overview, with no Flutter imports: `kinds`, `cardKinds`, `shown`, `hidden`, `canApply`,
  `move(from, to)`, `restoreDefault` and `applyTo`.
- `app/lib/ui/overview/overview_edit_sheet.dart` - `openEditOverview` (the presenter) and
  `EditOverviewSheet`, which holds the draft, builds the intro, the one reorderable list and the
  Restore default button, and applies the draft on Done. The private `_EditLayout` maps rendered
  list indices to `OverviewEditDraft.move` indices and `_EditList` builds the flattened rendered
  list.
- `app/lib/ui/overview/overview_edit_rows.dart` - `OverviewEditRow` (the 48 dp grip wrapped in
  `ReorderableDragStartListener`, the card title and the card subtitle), `OverviewEditHeading` (a
  section heading), `OverviewEditHiddenHint` (the empty-section hint row, used for both the Shown and
  the Hidden hint) and `OverviewEditSectionItem` with `OverviewEditSlot` (first, middle, last), which
  draws the tray surface and the joined border around each item of a section.
- `app/lib/ui/overview/overview_constants.dart` - the Edit Overview copy: `overviewEditShownLabel`,
  `overviewEditHiddenLabel`, `overviewEditShownHint`, `overviewEditHiddenHint`, `overviewEditIntro`,
  `overviewEditRestore` and `overviewEditDone`.
- `app/lib/ui/overview/overview_this_month_section.dart` - `ThisMonthTray` (the card, with the failed,
  skeleton, empty and figures states), `ThisMonthFigures` (the Spent, Income and Net rows and the
  caption), `ThisMonthCaption` and `ThisMonthFigureRow`.
- `app/lib/ui/overview/overview_rows.dart` - `OverviewLoadError`, the failed-read message and filled
  Retry button shared by the Today and This month trays, a thin wrapper over `LoadErrorView.box`.
  The same file holds `OverviewRowFrame` (the bottom edge between rows), `OverviewAmountText` (a
  padded shared `AmountText`) and `OverviewEmptyCopy` (caption-role subtext copy).
  `OverviewLinkAction` is the shared link button (action colour, top padding) that the 'View History'
  link and both Budget watch links use.
- `app/lib/ui/overview/overview_flow.dart` - `OverviewFlow` (`FlowBase`) subscribing to
  `OverviewStep` once, calling its required `onHistorySelected` callback for history requests, its
  required `onBudgetsSelected` callback for budget-list requests, its required `onBudgetSelected`
  callback for a single-budget request, `openEditOverview` for Edit Overview requests and
  `openEditEntry` for entry requests.
  `BootChrome` supplies the budget and history callbacks (`app/lib/ui/shell/boot_chrome.dart`). It supplies its page
  through `ShellPaneHost`. Its page builder
  passes the layout mode from `ShellPaneScope` and the page presentation to `OverviewScreen`.
- `app/lib/ledger/analysis/summaries/today_summary.dart` - `TodaySummary` carries `spent`, `dailyGuide` and
  `monthlyCap`.
- `app/lib/ui/transactions/daily_list/transaction_row.dart` - `transactionRow` supplies titles,
  account lines, symbols and amount kinds for entries and projected plan occurrences.
- `app/test/ui/overview/` - view model tests, the `overview_screen_test.dart` button-to-step tests
  (320x760), `overview_grid_placement_test.dart`, `overview_slots_test.dart` (card kinds and the
  seeding rule), `overview_content_test.dart` (the This month and Budget watch reads), `overview_edit_draft_test.dart` (the draft), `overview_edit_sheet_test.dart` (the
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
route. The header has no Cancel and no leading action. Done is a filled button that is disabled
while the draft has no shown card (`canApply`).

The draft rules:

- `shown` is the part of `kinds` that has a card, in stored order. `hidden` is every card kind not
  in `kinds`, in catalogue order (`overviewCardKinds`, enum declaration order). Hidden is not
  reorderable.
- `move(from, to)` takes indexes into the flattened sheet list: the shown rows, then the Hidden
  header at index `shown.length`, then the hidden rows. `to` is the final index after removal, as
  `ReorderableListView.onReorderItem` reports it. A move within the shown rows reorders them. A
  shown row dropped at or past the Hidden header becomes hidden. A hidden row dropped at or above
  the header becomes shown and lands at the drop position. Moving the header, hidden to hidden,
  an out-of-range index and a drop where the row started change nothing.
- Stored kinds without a card keep their exact index when shown cards are reordered: a reorder
  writes the reordered shown subsequence back into the positions that card kinds hold. Hiding a
  card removes it from the stored list and showing a card inserts it, so a kind without a card that
  sits after that point shifts by one. Their relative order never changes.
- `canApply` is true while at least one kind is shown. A saved list without a card kind would
  render as the defaults, so Done is disabled instead of saving it. The last shown card may still be
  dragged into Hidden.
- Restore default sets `kinds` to `DisplayPreferences.defaults.overviewWidgets`, the five-kind
  default, with no confirmation. It replaces the whole list, so stored kinds without a card are
  dropped.

The sheet body shows an intro, two visually distinct sections and a 'Restore default' button. Each
section has its own heading ('Shown on Overview' and 'Hidden') and its own tray surface, and a gap
separates the two. Each row shows a grip, the card title and the card subtitle. The Hidden section
lists every card kind that is not shown, in fixed catalogue order. Each section has an empty-state
hint row: 'Drag a widget here to show it.' in Shown when nothing is shown, and 'Drag a widget here to
hide it.' in Hidden when nothing is hidden. There is no Hide action, no '+ Add' action, no 'See all
widgets' link, no Add widgets view and no Added marker.

A card is hidden or shown only by dragging its grip between the sections, and it lands at the drop
position. The sheet is still one `ReorderableListView.builder` over one flattened rendered list:
the Shown heading, the shown rows or the Shown hint, a spacer, the Hidden heading, then the hidden
rows or the Hidden hint. It uses `buildDefaultDragHandles: false`, non-scrolling physics and
shrink-wrapping. Headings, hints and the spacer are plain items that carry no drag listener, so they
are not draggable. Each item sits in an `OverviewEditSectionItem`, whose slot decides which corners
are rounded, so the items of one section read as one tray. The private `_EditLayout` in
`overview_edit_sheet.dart` converts rendered indices to the draft indices described above. An item
that is not a row (a heading, a hint or the spacer) maps to nothing, so dragging it changes
nothing. A drop past the Hidden heading maps to the Hidden boundary, so the card becomes hidden. A
drop onto or around the Shown hint shows the card at position 0. The draft API (`shown`, `hidden`,
`canApply`, `move`, `restoreDefault`, `applyTo`) is unchanged by this mapping.

Only the 48 dp grip target of each row is wrapped in `ReorderableDragStartListener`. A drag on the
grip wins the gesture arena, so the sheet's drag-to-dismiss does not start, while a drag anywhere
else on the row still reaches the sheet's dismiss physics. The drag proxy is a `Material` with the
sheet fill (`context.colors.raised`) and a small elevation and radius. There are no Move up or Move
down buttons.

## Module interactions

`OverviewNotifier` is an `autoDispose` provider scoped to the mounted Overview view. Its `build` is
synchronous, so the screen has no whole-screen loading state; only the per-section skeletons below
appear. `build` watches `todayProvider`, `analysisQueriesProvider` and `ledgerSessionProvider`
(through `LedgerBackedNotifier`), so it rebuilds on every `AnalysisQueries` notification and on day
change. A failed build ends in `AsyncError` and shows an error state, never a spinner.
It calls `readToday()`, `readRecent()` and `readUpcoming()` and maps the results. It also calls
`readPeriod(window: monthWindow(today))` and `readRegisterDays(window:)` for that same month, and
`AnalysisQueries.readBudgets(month:)` for the month start of today. It never reads
`budgetsMonthProvider`, so changing the month on the Budgets screen does not change Budget watch.
`readToday()` is a mixed read, so the view state carries `today` only while the read is current for
the Ledger revision and otherwise null, which renders the Today skeleton instead of a stale summary; `readRecent()`
and `readUpcoming()` depend on the Ledger only and are available at once. A null section value
renders a skeleton for that section alone. A failed `readToday()` renders 'Couldn't load today's
spending' and a filled Retry in the Today tray. A failed `readPeriod()` renders 'Couldn't load this
month's totals' and a filled Retry in the This month tray. A failed `readBudgets()` renders 'Couldn't
load your budgets' and a filled Retry in the Budget watch tray. All three Retry buttons call
`OverviewNotifier.retryReads`, which calls `AnalysisQueries.retry()` to clear the failed evaluations and
request a cache refresh.
Recent entries and Coming up keep rendering. `recordedToday` is
read only beside a current Today summary, so the empty headline never appears over stale data.
`thisMonth` is carried only while the `readPeriod()` result for the current month is current for the
Ledger revision, the same gate as `today`; otherwise the This month tray shows a skeleton. The month
comes from `todayProvider`, so a day rollover into a new month reads the new month at once.
`budgetWatch` follows the same gate: it is null, which renders a skeleton, until the `readBudgets()`
result is current for the Ledger revision.
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
The Budget watch links 'Add a budget' (empty tray) and 'View budgets' (tray with rows) both call
`requestBudgets` and so share this path: Money opens at Budgets with nothing selected. A Budget watch
row tap calls `OverviewViewModel.openBudget`, which emits `OverviewBudgetRequested` only for a budget
that exists in the ledger. `OverviewFlow` calls `onBudgetSelected`, and `BootChrome` passes the ID to
`requestBudgetSelection` (`app/lib/ui/budgets/budget_list/budget_selection.dart`). That function sets
the kept-alive `pendingBudgetSelectionProvider` and then calls
`moneySegmentProvider.notifier.openAt(MoneySegment.budgets)`. `BudgetsFlow` listens to the pending
provider and, after the frame, clears it and sets `selectedBudgetProvider`, so the budget opens as a
phone detail page or an open and desktop pane. The pending provider exists because
`selectedBudgetProvider` is autoDispose and cannot hold a value before Money mounts, and because
providers cannot be written during build. Overview does not know about Money or Budgets selection.
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
- Budget watch: the top 3 category budgets of the month of today from `readBudgets`, highest
  utilization first, formatted by `budgetListCards` (the function the Budgets list uses) and rendered
  with `BudgetCard`. The unscoped All spending budget never gets a row. The tray is empty, with 'No
  budgets yet.' and an 'Add a budget' link, when no category budget exists, including when only an
  All spending budget exists. With rows it ends in a 'View budgets' link. It has no forecast line,
  chip, headline or legend.
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
- Placement runs only over kinds with a card, so the seven unmapped kinds never take a cell.
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
  The same holds for Budget watch: an install that saved a display setting before it joined the default
  list never shows it until the user adds it in Edit Overview.
- Budget watch reads the month of today, so a month chosen on the Budgets screen does not affect it.
  Its figures match the Budgets list only while the list shows the current month.
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

- The Edit Overview index mapping lives in the private `_EditLayout`, so it has no unit test. Only
  the draft's own `move` is unit tested. Hint rows are real drop targets, but in practice a drag
  must travel past the edge of the neighbouring section before the list reports a drop on a hint, so
  a short drag from the last row of one section toward the other can leave the card where it was.
- `OverviewEditHiddenHint` serves both sections, so its name describes only the Hidden use.

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
- The Edit Overview draft derives `shown` and `hidden`, moves a card within shown, hides a card by
  moving it past the Hidden header, shows a card at its drop position, keeps kinds without a card at
  their exact index when shown cards are reordered (and in their relative order when a card is
  hidden or shown), reports `canApply` false when nothing is shown, restores the
  five-kind default and applies itself to the other display preferences unchanged
  (`app/test/ui/overview/overview_edit_draft_test.dart`, groups 'shown and hidden', 'move within
  shown', 'move shown to hidden', 'move hidden to shown', 'moves that change nothing',
  'restoreDefault and applyTo'). An injected fifth card kind appears in `hidden` ('an injected fifth
  card kind appears in hidden'), which proves that a future card shows up in the editor with no
  other edit.
- `requestEditOverview` emits `OverviewEditOverviewRequested`, and `clearStep` clears it
  (`app/test/ui/overview/overview_view_model_test.dart`: 'requestEditOverview emits an edit-overview
  request that clearStep clears').
- On phone, dragging a grip reorders the list without dismissing the sheet, and Done saves the new
  order to `overviewWidgets`
  (`app/test/ui/overview/overview_edit_sheet_test.dart`: 'grip drag reorders without dismissing and
  Done saves'). Dragging a card into Hidden and then tapping outside discards the draft and leaves
  `overviewWidgets` unchanged (same file: 'dragging a card into Hidden then tapping outside
  discards'). Both cases assert preference values and the presence of the sheet only.
- The sheet shows Shown and Hidden as two separate sections, each with a heading, a tray surface and
  an empty-state hint row that is a drop target (`overviewEditShownHint`, `overviewEditHiddenHint`).
  The rendered-to-draft index mapping in `_EditLayout`, including a drop past the Hidden heading
  and a drop onto the Shown hint, has no unit test because the class is private.
- Budget watch lists the top three category budgets with the Budgets list strings, excludes an
  unscoped budget, stays pending until current for the Ledger revision and reads the month of today
  when the Budgets month is changed (`app/test/ui/overview/overview_content_test.dart`, group 'Budget
  watch'). `openBudget` emits `OverviewBudgetRequested` for an existing budget and `clearStep` clears it
  (`app/test/ui/overview/overview_view_model_test.dart`, group 'Budget step').
- A Budget watch row opens that budget in Money on a phone, 'View budgets' opens the Budgets list
  without a selection, and a row tap selects the budget in the open layout pane
  (`app/test/ui/shell/destination_lifetime_test.dart`: 'Budget watch row opens that budget in Money on
  a phone', 'Budget watch View budgets opens the Budgets list without a selection', 'Budget watch row
  selects the budget in the open layout pane'). `BudgetsFlow` selects a budget requested before or
  while it is mounted and selects nothing without a request
  (`app/test/ui/budgets/budget_list/budgets_flow_pending_selection_test.dart`).
- These behaviors have no widget test: the docked presentation on open and desktop, the 'Edit
  Overview' header action opening the sheet, Done disabled while nothing is shown, Restore default
  in the sheet, the two sections and their headings and hint rows, a drag from Hidden into Shown, a
  drag onto either hint, and the visual separation of the sections. The draft rules behind them are
  covered by the unit tests above. Restart persistence rests on
  `displayPreferencesProvider.notifier.replace` and the preferences store round trip
  (`app/test/settings/display_preferences_provider_test.dart`).
