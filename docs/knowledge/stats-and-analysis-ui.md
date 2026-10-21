# Trends & Category Detail UI

Last reconciled: 2026-10-21

## Feature overview

History opens a full-screen Trends page through its own `TransactionsFlow` navigator. Trends shows an
Expense/Income control, a Month by month/Year by year control, a period row with previous/next arrows,
a bar chart with selectable axis labels, a selected-period headline, and (month mode only) a Compared
with usual row. It has no category drill-down entry point. The retained Category Detail implementation has no production entry point.
It renders a main category's subcategory table, trend card, and scoped entry list. Its data comes from
the ready Ledger's `AnalysisCache` (`app/lib/ui/stats/category_detail/category_detail_view_model.dart`).

## Key files

- `app/lib/ui/stats/trends_flow.dart` and `trends_screen.dart` - the hosted Flow and the Trends page;
  the optional `onBackPressed` callback controls the History-labelled back button.
- `app/lib/ui/stats/trends/` - `trends_intent.dart` (route-owned intent, grid/page arithmetic, intent
  notifier), `trends_projection.dart` (day-aligned, revision-coherent projection of the analysis reads),
  `trends_usual.dart` (Compared with usual copy), `trends_body.dart` (presentation variants),
  `trends_view_model.dart` (`TrendsViewModel` interface and `LedgerBackedNotifier`), and the
  `trends_controls`, `trends_period_card`, `trends_state_views` widgets.
- `app/lib/ui/stats/category_detail/` - the retained category drill-down screen and view model.
- `app/lib/ui/stats/analysis/analysis_scan.dart` - memoized category-detail filtering.
- `app/lib/ui/stats/helpers/slices.dart` - category slice and roll-up helpers referenced only by tests,
  retained for the Transactions versus analysis accounting contract.
- `app/lib/ui/format/analysis_bucket_name.dart` - `analysisBucketName` and `uncategorizedName`: the
  shared display name for a null (Uncategorized) or synthetic transfer bucket ID, used by slices.
- `app/lib/ui/common/lists/day_sectioned_entry_list.dart` - reused entry list with tap-to-view and
  swipe-delete.
- `packages/domain/lib/src/accounting.dart` - `rollUp`, `fraction`, and filtering (see
  `recurring-plans-and-accounting.md`).
- `app/lib/ledger/analysis_cache.dart` - source-revision-stamped cache; ownership and acceptance
  contracts are in [ledger-runtime.md](ledger-runtime.md).

## Module interactions

`CategoryDetailNotifier.build` obtains the ready Ledger and its non-null cache through
`LedgerBackedNotifier`, which watches `ledgerSessionProvider` and throws `StateError` while the
session is unavailable (`app/lib/ui/common/base/ledger_backed_notifier.dart`). It captures the
Ledger and cache, attaches listeners, registers removal against those captured instances, and awaits
`cache.refresh(ledger.state)`. Later notifications refresh the captured cache. The session provider
owns cache disposal, and replacement Ledger identity rebuilds the session and its consumers
(`app/lib/boot/providers.dart:ledgerSessionProvider`, `app/lib/ledger/ledger_session.dart`,
`app/test/boot/ledger_session_provider_test.dart`,
`app/lib/ui/stats/category_detail/category_detail_view_model.dart`).

`categoryDetailViewModelProvider` is an `AsyncNotifierProvider.autoDispose.family` owned by its
route consumer, `CategoryDetailScreen`. Closing the route disposes the notifier and removes its
captured Ledger/cache listeners. After disposal, `_onChanged` returns without touching state. Tests
hold an explicit `container.listen` subscription to keep the provider alive
(`app/test/ui/stats/category_detail/category_detail_lifecycle_test.dart`).

Slices filter cache items by kind and window, roll up to main-category buckets with
`Accounting.rollUp`, and sort by amount descending. Slice color comes from the category's
`colorHex`; Uncategorized and synthetic transfer buckets use the gray fallback, and take their names from
`analysisBucketName`. Treat-as-expense
transfers use synthetic buckets by destination account type (`app/lib/ui/stats/helpers/slices.dart`,
`packages/domain/lib/src/accounting.dart:Accounting.classify`). Category Detail's `AnalysisScan` memoizes filtering by
cache identity, `itemsRevision`, kind, and bucket set. Cache identity matters because a replacement
Ledger's cache restarts `itemsRevision` and can match the previous cache's revision
(`app/lib/ui/stats/analysis/analysis_scan.dart:AnalysisScan.scan`,
`app/lib/ui/stats/category_detail/category_detail_view_model.dart:_buildState`,
`app/test/ui/stats/analysis/analysis_scan_test.dart`,
`app/test/boot/category_detail_cache_retry_test.dart`).

## Trends period state

`trendsIntentProvider` (auto-dispose `Notifier<TrendsIntent>`, no watched dependencies) owns kind, mode,
requested spread end, requested selected period, remembered month and `followsCurrent`. It starts on
expense, month mode and the current month, ignoring History's selected month, and survives analysis
notifications, failures and Retry within one route lifetime. `trendsViewModelProvider` is an
auto-dispose `AsyncNotifier` using `LedgerBackedNotifier`; it watches the intent, `analysisQueriesProvider`
and `todayProvider` and returns a `TrendsBody`: loading, error, empty (ledger has no records) or ready.
It reactively watches `breakdownChart`, `breakdownLevel` and `chartColours` through a selection of
`displayPreferencesProvider`. Each build copies category names, parent IDs and saved hex colours
from the ready Ledger into an immutable map for that revision (`TrendsNotifier.build`).
Spreads are rolling 12-month windows and 3 calendar-year windows anchored at the current period.
Computed clamps to the earliest spread never rewrite stored intent: a genuine action adopts the displayed
basis first. Month to Year clamps to the earliest yearly slot; Year to Month applies the remembered month,
clamped to the current month and the earliest monthly slot. A projection first reads month completeness
for the current month and requires its `today` to equal `todayProvider` (otherwise loading), then requires
first-record, spread, usual and category-breakdown reads to be ready with one `sourceRevision` equal
to the Ledger revision;
failed reads give the error body, pending or mismatched ones the skeleton. Compared with usual copy
(higher, lower, same, zero baseline, elapsed-day and cross-year wording) is built in `trends_usual.dart`.
Retry calls `AnalysisQueries.retry()` only. (`app/lib/ui/stats/trends/`,
`app/test/ui/stats/trends_period_test.dart`, `trends_states_test.dart`, `trends_usual_test.dart`)

The category breakdown uses the selected period, kind and level. The projection explicitly maps the
settings `BreakdownLevel` to the analysis `BreakdownLevel`. A failed breakdown read gives the error
body; pending reads or stale revisions give loading. A ready breakdown with no rows produces
`TrendsEmptyBreakdown` within the ready body, while an empty ledger has no breakdown in its empty
body. The breakdown window, kind, level and total must match the selected period. Row amounts must
sum to the total; nonempty rows' shares must sum to 100 percent. The projection carries the breakdown data,
but no widget renders it (`trends_projection.dart:_readBreakdown`, `_breakdown`,
`trends_body.dart`, `trends_screen.dart`, `app/test/ui/stats/trends_breakdown_projection_test.dart`).

## Navigation

`TransactionsFlow` handles `HistoryTrendsRequested`, seeds `selectedMonthProvider` from History's
selected date at UTC month start, and pushes one route containing `TrendsFlow(onEnded: ...)`.
`TrendsFlow` uses its nested navigator and renders `TrendsScreen`. The optional History-labelled
header Back delegates to `FlowBase.goBack`; at the root this ends the Flow and pops the History-owned
route. System Back and the iOS edge swipe pop the enclosing route. `TransactionsFlow` holds its
single-route guard until the matching route's `completed` future (`transactions-ui.md`,
`app/lib/ui/transactions/transactions_flow.dart`, `app/lib/ui/common/base/flow_base.dart`).

Trends has no category navigation. Category Detail retains its own date state, seeded by
its arguments, and inherits a fixed month or year mode. Its toolbar has the `MonthYearSelector` only;
it has no range menu.

Budgets live in the Money Budgets segment. Trends does not mount `BudgetsFlow`
(`app/lib/ui/money/money_flow.dart`).

## Screens and flows

- **Trends** - app bar titled "Trends", optional History-labelled back control, the kind and mode
  controls (always mounted), and a body that is skeleton trays, an error box with a filled Retry, the
  fresh-ledger empty state with a disabled period row, or the period card. It has no category
  drill-down (`app/lib/ui/stats/trends_screen.dart`).
- **Category Detail** - a `TransactionsTableView` whose header stack is scope total, subcategory
  table (only when the category has children), trend card, and "ENTRIES"; the day-sectioned entry
  list follows. Scope selection is `all` | `sub(id)` | `direct`: a caption identifies the scope,
  and the amount uses the kind's `AmountStyle` colour. The subcategory table starts with "All
  <Main>" (100%), then child slices and the Direct slice (id nil, parent color) sorted together by
  amount. The Direct row exists only when main total minus child totals is greater than zero.
  Fractions use the main-category total. The trend card shows a smoothed line over `trendMonths`
  (month mode uses six months ending at detailDate's month; year mode uses all 12 months of
  detailDate's year) with nearest-point selection. `matchingCategoryIDs` drives totals and entry
  filtering, modeling the null bucket as its own sealed case.

## Gotchas and invariants

- Analysis-driven totals can differ from Transactions for the same month because analysis also
  applies category inclusion gates. Both totals respect entry-level `includeInAnalysis` and count
  treat-as-expense transfers (`Accounting.classify`, `Accounting.totals`,
  `app/test/ui/transactions_stats_totals_parity_test.dart`).
- The domain classifies treat-as-expense transfers into synthetic account-type buckets; retained
  slice helpers label those buckets and keep them non-navigable (`Accounting.classify`,
  `app/lib/ui/stats/helpers/slices.dart:Slice.isNavigable`).
- Slice fractions guard zero totals.

## Requirements

- Category Detail captures the ready session's Ledger and cache during build, uses that cache for
  listener removal and later refreshes, and scopes memoized scans to cache identity
  (`CategoryDetailNotifier.build`, `AnalysisScan.scan`).
- Slices roll categories up to main buckets, preserve synthetic transfer buckets, and sort by
  amount descending (`Accounting.rollUp`, `app/lib/ui/stats/helpers/slices.dart:slices`).
- Category Detail scope selection, subcategory Direct-bucket threshold (`> 0`), trend windows in
  both modes, and `matchingCategoryIDs` are pure, tested functions.
