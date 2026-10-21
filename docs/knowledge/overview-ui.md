# Overview UI

Last reconciled: 2026-10-20

## Feature overview

The Overview screen renders three read-only sections in fixed default order: Today, Recent entries
and Coming up. A full-page open layout places Today across row one columns one and two, leaves the
third column empty, then places Recent entries across row two columns one and two and Coming up in
column three. Three equal columns use the named 10 dp tray gap. The row-two cards stretch to the
larger card's content-driven height. Add presentation, a detail pane, or a column narrower than
220 dp uses one column in the same section order. The 220 dp minimum is not text-scaled, so the grid
needs a page width of 708 dp (a window of about 780 dp beside the 72 dp rail) at any text size.
Phone and desktop retain their single-column presentation. The screen has no edit mode or widget
catalogue. No section is ever blank. Each section renders its own copy for an empty ledger, and a
section whose read has not settled renders a `LoadingSkeleton`. The screen reads only through
`AnalysisQueries`; widgets compute no totals.

## Key files

- `app/lib/ui/overview/overview_view_model.dart` - `OverviewViewModel` (abstract), `OverviewNotifier`
  (`AsyncNotifier` with `LedgerBackedNotifier`, `overviewViewModelProvider`), `OverviewViewState`,
  and the row types `OverviewEntryRow` and `OverviewUpcomingRow`. The view state carries an
  `OverviewStep` (`HasStep`/`StepEmitting`); `requestHistory` emits `OverviewHistoryRequested` and
  `clearStep` clears it. Rebuilds preserve a pending step.
- `app/lib/ui/overview/overview_screen.dart` - `OverviewScreen`, its open-layout grid and its
  standalone section widgets. The Recent entries tray ends in a `TextButton` action labelled 'View
  History' with a chevron, shown for nonempty, empty and section-loading rows.
- `app/lib/ui/overview/overview_flow.dart` - `OverviewFlow` (`FlowBase`) subscribing to
  `OverviewStep` once and calling its required `onHistorySelected` callback. When hosted in the shell it supplies its
  page through `ShellPaneHost`, which provides bounded width and full-page or single-column
  presentation.
- `app/lib/ledger/analysis/summaries/today_summary.dart` - `TodaySummary` carries `spent`, `dailyGuide` and
  `monthlyCap`.
- `app/lib/ui/transactions/daily_list/transaction_row.dart` - `transactionRow` supplies titles,
  account lines, symbols and amount kinds for entries and projected plan occurrences.
- `app/test/ui/overview/` - view model tests, the `ov-default` frame-parity widget tests (light and
  dark, 320x760) and the shared fixture.

## Module interactions

`OverviewNotifier.build` watches `todayProvider`, `analysisQueriesProvider` and
`ledgerSessionProvider` (through `LedgerBackedNotifier`), so it rebuilds on every `AnalysisQueries` notification and on day change.
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
the retained History flow keeps its stack, date and mode. History has no back-to-Overview control.

## Read definitions

- Today: expense items dated today. The daily guide and `monthlyCap` come from the unscoped
  budget's effective limit for the month. Without an unscoped budget both are null and the tray
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
  column to `MedallionRow.leading`, which replaces the medallion.

## Requirements

- Section order is Today, Recent entries, Coming up (`app/test/ui/overview/overview_screen_test.dart`).
- Recent entries never exceeds 4 and sorts newest first
  (`app/test/ui/overview/overview_view_model_test.dart`).
- 'View History' is shown for nonempty, empty and section-loading Recent entries, carries
  button semantics with a 48px minimum hit target, and requests the History page
  (`app/test/ui/overview/overview_screen_test.dart`).
- Coming up excludes dates at or beyond 42 days
  (`app/test/ui/overview/overview_view_model_test.dart`).
- An empty ledger renders all three sections with their own copy
  (`app/test/ui/overview/overview_screen_test.dart`).
