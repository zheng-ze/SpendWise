# Overview UI

Last reconciled: 2026-10-10

## Feature overview

The Overview screen renders three read-only sections in fixed default order: Today, Recent entries
and Coming up. It has no edit mode and no widget catalogue. No section is ever blank. Each section
renders its own copy for an empty ledger, and a section whose read has not settled renders a
`LoadingSkeleton`. The screen reads only through `AnalysisQueries`; widgets compute no totals.

## Key files

- `app/lib/ui/overview/overview_view_model.dart` - `OverviewNotifier` (`overviewViewModelProvider`),
  `OverviewViewState`, and the row types `OverviewEntryRow` and `OverviewUpcomingRow`.
- `app/lib/ui/overview/overview_screen.dart` - `OverviewScreen` and its standalone section widgets.
- `app/lib/ui/overview/overview_flow.dart` - `OverviewFlow` (`FlowBase`) with an empty `OverviewStep`.
- `app/lib/ledger/analysis/today_summary.dart` - `TodaySummary` carries `spent`, `dailyGuide` and
  `monthlyCap`.
- `app/lib/ui/transactions/daily_list/transaction_row.dart` - `transactionRow` supplies titles,
  account lines, symbols and amount kinds for entries and projected plan occurrences.
- `app/test/ui/overview/` - view model tests, the `ov-default` frame-parity widget tests (light and
  dark, 320x760) and the shared fixture.

## Module interactions

`OverviewNotifier.build` watches `todayProvider`, `analysisQueriesProvider` and
`ledgerSessionProvider`, so it rebuilds on every `AnalysisQueries` notification and on day change.
It calls `readToday()`, `readRecent()` and `readUpcoming()` and maps the results. `readToday()` is a
mixed read, so its value is null until the cache accepts the current Ledger revision; `readRecent()`
and `readUpcoming()` depend on the Ledger only and are available at once. A null section value
renders a skeleton for that section alone.

## Read definitions

- Today: expense items dated today. The daily guide and `monthlyCap` come from the unscoped
  budget's effective limit for the month. Without an unscoped budget both are null and the tray
  shows 'Set a monthly cap to see a daily guide.' with a 'Set a monthly cap' link.
- Today shows 'Nothing recorded today' instead of an amount when no active entry is dated today
  (`OverviewViewState.recordedToday`), so an unknown day is never drawn as zero spending.
- Recent entries: at most 4 active entries dated before tomorrow, newest first. A row caption is
  '<Today or d MMM> / <category> / <account line>' and the title is the entry name, falling back to
  the category title.
- Coming up: the next 42 days from `readUpcoming()`, in its date order. A statement row reads
  '<card> statement closes' with 'This cycle so far: <amount>' and a card icon in place of an
  amount. Plan occurrences read 'Plan / <account line>' and dated-ahead entries read
  'Dated ahead / <account line>'.

## Gotchas and invariants

- The 'View History' and 'Set a monthly cap' links render as styled text without a tap target. The
  shell wiring that makes them navigate does not exist yet.
- The screen has no header actions. The gear and 'Edit Overview' of the reference frame are not
  rendered.
- Notices above the sections (sync, save retry, plan attention) are not part of this screen. The
  shell's `StatusBanner` owns notice display.
- The fresh-install framing of the reference ('Start with an account' tray, 'Add your first entry'
  link) is not rendered.
- `OverviewFlow` is not mounted by `AppShell` yet; tests mount it directly.
- Every visual value in `overview_screen.dart` is a named constant.

## Requirements

- Section order is Today, Recent entries, Coming up (`app/test/ui/overview/overview_screen_test.dart`).
- Recent entries never exceeds 4 and sorts newest first
  (`app/test/ui/overview/overview_view_model_test.dart`).
- Coming up excludes dates at or beyond 42 days
  (`app/test/ui/overview/overview_view_model_test.dart`).
- An empty ledger renders all three sections with their own copy
  (`app/test/ui/overview/overview_screen_test.dart`).
