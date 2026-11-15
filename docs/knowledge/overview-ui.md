# Overview UI

Last reconciled: 8ca1a166

## Feature overview

The Overview screen renders `DisplayPreferences.overviewWidgets` in stored order, one slot per
`OverviewWidgetKind`, below the header. `OverviewSlotGrid` reads the list through
`displayPreferencesProvider` and places the slots that map to a card in a column grid. Columns and
rows are separated by the named 10 dp tray gap (`overviewTrayGap`). The grid has one column on phone
and three columns on open. On desktop it has three columns when the window is 1250 dp wide or more
and two columns below that. Open and desktop drop to one column while the shell presents Overview as
`ShellPagePresentation.singleColumn`, which happens whenever an AppSheet covers the shell: Add entry,
Edit entry opened from a Recent row, or any other sheet over the shell. Every layout also drops to one
column when a column would be narrower than 220 dp. The grid measures that width itself through a
`LayoutBuilder`, after the sidebar, the open rail gutter, the page padding and any split. The window
width that selects the desktop threshold is `MediaQuery.sizeOf(context).width`, the logical width of
the whole window, not the width of the content pane. `overviewColumnCount` in
`overview_grid_placement.dart` is the pure rule that combines these inputs.

Each kind has a column span from `overviewColumnSpan`. Today, Recent entries and Spending over time
span two columns and every other kind spans one. `placeOverviewWidgets` places the kinds in stored
order with backfill. Each kind takes the first row with enough free columns for its span, so a
one-column widget can move up beside a wider widget, while spanning widgets keep their stored order
relative to each other. With one column every kind occupies one cell. With two columns each spanning
widget takes a whole row. Only kinds that map to a card take part in placement. With the default
list in three columns, Coming up moves up beside Today and Recent entries starts the second row. The
default list is Today, Recent entries and Coming up. `overviewSlotFor` (`overview_slots.dart`) is the single kind-to-widget mapping, an
exhaustive switch with no default. Only `today`, `recentEntries` and `comingUp` map to a card; the
other nine kinds map to null and render nothing, with no placeholder. A card ticket adds a kind by
replacing its null arm. The screen has no edit mode or widget catalogue. With the default list no
section is ever blank: each section renders its own copy for an empty ledger, and a section whose
read has not settled renders a `LoadingSkeleton`. The screen reads only through `AnalysisQueries`;
widgets compute no totals.

## Key files

- `app/lib/ui/overview/overview_view_model.dart` - `OverviewViewModel` (abstract), `OverviewNotifier`
  (`AsyncNotifier` with `LedgerBackedNotifier`, `overviewViewModelProvider`), `OverviewViewState`,
  and the row types `OverviewEntryRow` and `OverviewUpcomingRow`. The view state carries an
  `OverviewStep` (`HasStep`/`StepEmitting`); `requestHistory` emits `OverviewHistoryRequested`,
  `openEntry` emits `OverviewEntryRequested` and `clearStep` clears it. `OverviewEntryRow.entryId`
  identifies the entry a Recent row opens. Rebuilds preserve a pending step.
- `app/lib/ui/overview/overview_screen.dart` - `OverviewScreen` and its header; the body places
  `OverviewSlotGrid` under the header. `OverviewScreen` takes `layoutMode` (default phone) and
  `presentation` (default full page) and passes both to the body, so direct fixtures keep the
  single-column stored-order behavior. The Recent entries tray (`overview_recent_section.dart`)
  ends in a `TextButton` action labelled 'View History' with a chevron, shown for nonempty, empty
  and section-loading rows.
- `app/lib/ui/overview/overview_slot_grid.dart` - `OverviewSlotGrid`, a `ConsumerWidget` that watches
  `overviewWidgets`, collects the present slots and reads the window width from `MediaQuery`. It
  returns a `LayoutBuilder` whose private `_OverviewSlotWrap` renders one `Wrap` on every layout.
  Each slot is wrapped in `KeyedSubtree(key: ValueKey(kind))` and sized to its column span.
- `app/lib/ui/overview/overview_grid_placement.dart` - the pure rules: `overviewColumnCount`,
  `overviewColumnSpan`, `OverviewGridCell` and `placeOverviewWidgets`. Their named constants
  (column counts, spans, the 1250 dp desktop threshold and the 220 dp column floor) are in the Layout
  section of `overview_constants.dart`.
- `app/lib/ui/overview/overview_slots.dart` - `overviewSlotFor`, the kind-to-widget switch.
- `app/lib/ui/overview/overview_flow.dart` - `OverviewFlow` (`FlowBase`) subscribing to
  `OverviewStep` once, calling its required `onHistorySelected` callback for history requests and
  `openEditEntry` for entry requests. It supplies its page through `ShellPaneHost`. Its page builder
  passes the layout mode from `ShellPaneScope` and the page presentation to `OverviewScreen`.
- `app/lib/ledger/analysis/summaries/today_summary.dart` - `TodaySummary` carries `spent`, `dailyGuide` and
  `monthlyCap`.
- `app/lib/ui/transactions/daily_list/transaction_row.dart` - `transactionRow` supplies titles,
  account lines, symbols and amount kinds for entries and projected plan occurrences.
- `app/test/ui/overview/` - view model tests, the `ov-default` frame-parity widget tests (light and
  dark, 320x760), `overview_widget_order_test.dart`, `overview_grid_placement_test.dart`,
  `overview_grid_layout_test.dart` and the shared fixture.

## Module interactions

`OverviewNotifier` is an `autoDispose` provider scoped to the mounted Overview view. Its `build` is
synchronous, so the screen has no whole-screen loading state; only the per-section skeletons below
appear. `build` watches `todayProvider`, `analysisQueriesProvider` and `ledgerSessionProvider`
(through `LedgerBackedNotifier`), so it rebuilds on every `AnalysisQueries` notification and on day
change. A failed build ends in `AsyncError` and shows an error state, never a spinner.
It calls `readToday()`, `readRecent()` and `readUpcoming()` and maps the results. `readToday()` is a
mixed read, so the view state carries `today` only while the read is current for the Ledger revision
and otherwise null, which renders the Today skeleton instead of a stale summary; `readRecent()`
and `readUpcoming()` depend on the Ledger only and are available at once. A null section value
renders a skeleton for that section alone. A failed `readToday()` renders 'Couldn't load today's
spending' and a filled Retry in the Today tray; Retry calls `AnalysisQueries.retry()` through
`OverviewNotifier.retryToday`. Recent entries and Coming up keep rendering. `recordedToday` is
read only beside a current Today summary, so the empty headline never appears over stale data.
Tapping 'View History' calls `OverviewViewModel.requestHistory`; `OverviewFlow` consumes the
resulting `OverviewHistoryRequested` exactly once and clears it, including requests made before its
Navigator mounts. On every layout `BootChrome` supplies a callback that selects the
`ShellDestination.history` slot (`app/lib/ui/shell/boot_chrome.dart`); the flow pushes no route and
History mounts fresh at the current month with an empty stack, and nothing is carried over from Overview before it mounts.
History has no back-to-Overview control.
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
- Recent entries: at most 4 active entries dated before tomorrow, newest first; same-day entries
  order by id descending. A row caption is
  '<Today or d MMM> / <category> / <account line>' and the title is the entry name, falling back to
  the category title.
- Coming up: the next 42 days from `readUpcoming()`, in its date order. A statement row reads
  '<card> statement closes' with 'This cycle so far: <amount>' and a card icon in place of an
  amount. Plan occurrences read 'Plan / <account line>' and dated-ahead entries read
  'Dated ahead / <account line>'.

## Gotchas and invariants

- Slot keys are `ValueKey(kind)`, so a reorder keeps slot state. Keys must be unique: a list with a
  duplicate kind would throw, which is why the preferences store de-duplicates and drops unknown
  codes.
- All layouts render the slots through one `Wrap`, so every slot stays a keyed sibling of the same
  parent. A reorder, a backfill move, a window resize across 1250 dp and opening or closing a sheet all
  keep each slot's state. Per-row `Row` widgets would remount a card that changes row, and
  `IntrinsicHeight` would forbid a `LayoutBuilder` inside a future card.
- Only one-column widgets backfill. Spanning widgets keep their stored order relative to each other,
  and holes sit only at the end of a row. The `Wrap` breaks its runs where the placement does
  because the cells are emitted row by row and each full row's widths sum to the grid width, so no
  spacer cells are needed.
- Rows are top-aligned and each card keeps its natural height. Rows therefore vary in height and their
  bottom edges can be ragged. This trade-off stands until a product decision changes it.
- Placement runs only over kinds with a card, so the nine unmapped kinds never take a cell.
  `spendingOverTime` has a span of two but no card yet, so its span is covered only by the pure tests
  until its card ships.
- Any AppSheet that covers the shell collapses Overview to one column on open and desktop, not only
  Add entry and Edit entry.
- On open, a portrait window about 768 dp wide or narrower renders one column, because three columns
  would be narrower than 220 dp.
- `OverviewNotifier` and `OverviewViewState` do not depend on the widget list; the notifier stays
  synchronous and ledger-derived.
- The 'Set a monthly cap' link renders as styled text without a tap target. The shell wiring
  that makes it navigate does not exist yet.
- 'View History' is a real action; it stays reachable for empty and section-loading Recent
  entries, not only for nonempty rows.
- The screen has no header actions. The gear and 'Edit Overview' of the reference frame are not
  rendered.
- Notices above the sections (sync, save retry, plan attention) are not part of this screen. The
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

- Section order is the stored `overviewWidgets` order, and replacing the list re-renders it
  (`app/test/ui/overview/overview_widget_order_test.dart`).
- An empty list, or a list holding only kinds without a card, shows the header only
  (`app/test/ui/overview/overview_widget_order_test.dart`).
- Recent entries never exceeds 4 and sorts newest first
  (`app/test/ui/overview/overview_view_model_test.dart`).
- 'View History' is shown for nonempty, empty and section-loading Recent entries, carries
  button semantics with a 48px minimum hit target, and requests the History page
  (`app/test/ui/overview/overview_screen_test.dart`).
- Coming up excludes dates at or beyond 42 days
  (`app/test/ui/overview/overview_view_model_test.dart`).
- With the default list, an empty ledger renders all three sections with their own copy
  (`app/test/ui/overview/overview_screen_test.dart`).
- The column count follows the layout mode, the shell presentation, the window width and the 220 dp
  column floor. Span and backfill placement keep stored order for one-column widgets, and a spanning
  widget takes a whole row in two columns (`app/test/ui/overview/overview_grid_placement_test.dart`).
- Overview backfills its slots in three columns on open and on desktop at 1250 dp or wider, keeps the
  stored order in one or two columns, and keeps the stored order while a sheet covers the shell. The
  window width, the mode and the presentation reach the column rule through the shell scopes
  (`app/test/ui/overview/overview_grid_layout_test.dart`).
