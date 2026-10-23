# Trends & Category Detail UI

Last reconciled: 2026-10-23

## Feature overview

History opens a full-screen Trends page through its own `TransactionsFlow` navigator. Trends shows an
Expense/Income control, a Month by month/Year by year control, a period row with previous/next arrows,
a bar chart with selectable axis labels, a selected-period headline, (month mode only) a Compared
with usual row, and a ranked category breakdown whose rows and chart blocks open Category Detail. Category
Detail keeps the incoming month or year fixed while route-local scope and trend controls project the
incoming-period totals and a selectable scoped trend from `AnalysisQueries`.

## Key files

- `app/lib/ui/stats/trends_flow.dart` and `trends_screen.dart` - the nested Flow and page; the Flow
  root resolves phone versus the shared open/desktop composition from `ShellPaneScope.mode` once.
  `TrendsScreen` owns the page scroller and optional History-labelled back button.
- `app/lib/ui/stats/trends/` - `trends_intent.dart` (route-owned intent, grid/page arithmetic, intent
  notifier), `trends_projection.dart` (day-aligned, revision-coherent projection of the analysis reads),
  `trends_usual.dart` (Compared with usual copy), `trends_body.dart` (presentation variants),
  `trends_view_model.dart` (`TrendsViewModel` interface, `TrendsViewState`, `TrendsStep` and the
  `LedgerBackedNotifier`, typed scope action and named category source), `trends_breakdown_scope.dart`
  (route-lifetime scope state), `trends_scoped_presentation.dart` (coordinated breakdown/header/source),
  `trends_open_layout.dart` (shared open/desktop composition), `trends_shared_breakdown_card.dart`,
  `trends_category_averages.dart`, and the `trends_controls`, `trends_period_card`,
  `trends_state_views` widgets.
- `app/lib/ui/stats/category_detail/` - immutable route arguments, route-local scope and trend intent,
  synchronous query projection, scope/breakdown presentation, and the drill-down screen.
- `app/lib/ledger/analysis_queries.dart` - shared mixed-read entry points and revision-aware
  analysis ownership for Category Detail.
- `app/lib/ui/common/lists/flat_entry_sliver.dart` - the lazy selected-period entry list with
  tap-to-view and swipe-delete.
- `app/lib/ui/common/sheets/sliver_tray.dart` - the shared sliver tray used by the Category Detail
  trend card.
- `app/lib/ui/stats/helpers/slices.dart` - category slice and roll-up helpers referenced only by tests,
  retained for the Transactions versus analysis accounting contract.
- `app/lib/ui/format/analysis_bucket_name.dart` - `analysisBucketName` and `uncategorizedName`: the
  shared display name for a null (Uncategorized) or synthetic transfer bucket ID, used by slices.
- `packages/domain/lib/src/accounting.dart` - `rollUp`, `fraction`, and filtering (see
  `recurring-plans-and-accounting.md`).
- `app/lib/ledger/analysis_cache.dart` - source-revision-stamped cache; ownership and acceptance
  contracts are in [ledger-runtime.md](ledger-runtime.md).

## Module interactions

`CategoryDetailNotifier.build` synchronously watches `analysisQueriesProvider`,
`ledgerSessionProvider`, `todayProvider`, and the route-keyed `categoryDetailIntentProvider`. It reads
the incoming-period result first, derives `TrendsBounds` from its current effective scope's
`firstRecord`, then reads the spread and its effective selected-period amount and entries using that
scope and trend basis. The projection publishes financial content only when both reads are ready,
non-null, and match the current Ledger revision; the spread's `today` must also match `todayProvider`.
Loading or error replaces financial content, and Retry delegates to `AnalysisQueries.retry()`
(`app/lib/ui/stats/category_detail/category_detail_view_model.dart:CategoryDetailNotifier.build`,
`app/lib/ui/stats/category_detail/category_detail_projection.dart:projectCategoryDetailWithTrend`,
`app/lib/ledger/analysis_queries.dart:readCategoryDetailPeriod`,
`readCategoryDetailSpread`).

The auto-dispose `categoryDetailViewModelProvider` and
`categoryDetailIntentProvider` are keyed by unchanged `CategoryDetailArgs`. The ViewModel projects
shared query values and has no direct cache listeners or `AnalysisScan` use. Provider dependencies
own route lifetime; the shared session and `AnalysisQueries` retain refresh, replacement and cache
ownership (`app/lib/ui/stats/category_detail/category_detail_view_model.dart`,
`app/test/ui/stats/category_detail/category_detail_lifecycle_test.dart`,
`app/test/boot/category_detail_cache_retry_test.dart`).

Slices filter cache items by kind and window, roll up to main-category buckets with
`Accounting.rollUp`, and sort by amount descending. Slice color comes from the category's
`colorHex`; Uncategorized and synthetic transfer buckets use the gray fallback, and take their names from
`analysisBucketName`. Treat-as-expense
transfers use synthetic buckets by destination account type (`app/lib/ui/stats/helpers/slices.dart`,
`packages/domain/lib/src/accounting.dart:Accounting.classify`). Trends continues to own those slice
projections; Category Detail uses the pure evaluators behind `AnalysisQueries` instead of the former
`AnalysisScan` path.

## Trends period state

`trendsIntentProvider` (auto-dispose `Notifier<TrendsIntent>`, no watched dependencies) owns kind, mode,
requested spread end, requested selected period, remembered month and `followsCurrent`. It starts on
expense, month mode and the current month, ignoring History's selected month, and survives analysis
notifications, failures and Retry within one route lifetime. `trendsViewModelProvider` is an
auto-dispose `AsyncNotifier` using `LedgerBackedNotifier` and `StepEmitting`; it watches the intent,
`analysisQueriesProvider` and `todayProvider` and returns a `TrendsViewState` whose `body` is a
`TrendsBody`: loading, error, empty (ledger has no records) or ready, and whose `step` is the pending
`TrendsStep`.
It reactively watches `breakdownChart`, `breakdownLevel` and `chartColours` through a selection of
`displayPreferencesProvider`. Each build copies category names, parent IDs and saved hex colours
from the ready Ledger into an immutable map for that revision (`TrendsNotifier.build`).
Spreads are rolling 12-month windows and 3 calendar-year windows anchored at the current period.
Computed clamps to the earliest spread never rewrite stored intent: a genuine action adopts the displayed
basis first. Month to Year clamps to the earliest yearly slot; Year to Month applies the remembered month,
clamped to the current month and the earliest monthly slot. A projection first reads month completeness
for the current month and requires its `today` to equal `todayProvider` (otherwise loading), then
requires the first-record and category-breakdown reads plus the `readTrendsPeriod` aggregate in both
modes to share the Ledger revision; month mode also gates on its separate usual read
(`app/lib/ui/stats/trends/trends_projection.dart:months`, `years`, `_unready`,
`app/lib/ledger/analysis_queries.dart:readTrendsPeriod`).
failed reads give the error body, pending or mismatched ones the skeleton. Compared with usual copy
(higher, lower, same, zero baseline, elapsed-day and cross-year wording) is built in `trends_usual.dart`.
Retry calls `AnalysisQueries.retry()` only. (`app/lib/ui/stats/trends/`,
`app/test/ui/stats/trends_period_test.dart`, `trends_states_test.dart`, `trends_usual_test.dart`)

Both modes read the sealed `TrendsPeriod` through `AnalysisQueries.readTrendsPeriod` and store it as
the required, non-null `TrendsReadyBody.periodSummary`. Month mode carries a 12-month spread and a
ranked category breakdown over that window; year mode carries a three-calendar-year spread and a ranked breakdown
over the full three-year window. Both summaries include the first ranked `largestRow` and per-category
`CategoryPeriodAverages` across complete periods. Month mode also identifies the highest-total
complete positive month, while year mode identifies the highest-total complete positive year. In
year mode, years beginning before `firstRecordMonth` are excluded in full, and
`completePeriodCount` counts D8-complete calendar years. Average means are null when no periods are
complete. The projection waits for the aggregate alongside the other reads and validates revision
inputs, spread bounds and shape, whole-window
breakdown, and average-row identity before rendering (`app/lib/ui/stats/trends/trends_projection.dart:months`,
`years`, `_monthSummaryMatches`, `_yearSummaryMatches`, `_averagesMatchBreakdown`,
`app/lib/ui/stats/trends/trends_body.dart:TrendsReadyBody`,
`app/lib/ledger/analysis/summaries/trends_period.dart:MonthTrendsPeriod`,
`YearTrendsPeriod`, `CategoryPeriodAverages`).

Only `TrendsReadyBody` carries the required `wholePeriod` payload (`TrendsWholePeriod`). Both month
and year projections call `projectWholePeriod` to build its breakdown from `periodSummary.breakdown`,
using the shared row projection and current display preferences. Its header carries the kind-specific
title, spread range and signed whole-period total. Insights contain at most two observations: the
largest category's name and share, then the highest complete month or year with its signed amount
(for example, `July 2026: -S$1,234.00`). Unavailable observations are omitted; when neither exists,
the empty message is `Not enough data`. Insights have no qualifier text
(`app/lib/ui/stats/trends/trends_whole_period.dart:projectWholePeriod`,
`app/test/ui/stats/trends_breakdown_projection_test.dart`). `TrendsInsightsCard` renders this payload's
Insights in the shared open/desktop composition; phone renders the selected-period breakdown
(`app/lib/ui/stats/trends/trends_insights_card.dart`,
`app/lib/ui/stats/trends/trends_open_layout.dart`).

The open and desktop shell modes share `TrendsOpenLayout`; the Flow root maps `ShellPaneScope.mode`
to phone or shared composition once. The shared layout puts kind, mode and period controls beside the
period chart in a full-width top card. Below it, the shared breakdown and Insights group sits beside
the selected-period headline and chart-free Category averages. The latter shows selected-period
amounts against monthly or yearly averages and includes Compared with usual only in month mode. A
640 dp content-width threshold stacks or pairs the lower groups and controls/chart inside this layout;
it does not change shell mode. The reserved composition boundary remains zero-content. One page
`SingleChildScrollView` contains the entire composition. Phone keeps its own controls, period card,
headline, month-only usual row and selected-period breakdown (`trends_open_layout.dart`,
`trends_screen.dart`, `trends_flow.dart`, `trends_layout_test.dart`,
`trends_open_layout_test.dart`).

The shared breakdown card switches between whole-period and selected-period rows. Its separate
auto-dispose `trendsBreakdownScopeProvider` defaults to `wholePeriod`; the typed ViewModel action
changes it within the Trends route lifetime. `resolveTrendsScopedPresentation` selects the matching
breakdown, header and `TrendsCategoryDetailSource` together. The control labels the selected scope
`Selected month` or `Selected year` according to mode. The shared card draws the saved donut or
category map and ranked rows; Category averages draws no chart. Scope, helper and widget behavior
are covered by `trends_breakdown_scope_test.dart`, `trends_scoped_presentation_test.dart`,
`trends_shared_breakdown_card_test.dart` and `trends_category_averages_test.dart`.

The selected-period category breakdown uses the selected period, kind and level. The projection explicitly maps the
settings `BreakdownLevel` to the analysis `BreakdownLevel`. A failed breakdown read gives the error
body; pending reads or stale revisions give loading. A ready breakdown with no rows produces
`TrendsEmptyBreakdown` within the ready body, while an empty ledger has no breakdown in its empty
body. The breakdown window, kind, level and total must match the selected period. Row amounts must
sum to the total; nonempty rows' shares must sum to 100 percent. The projection carries the breakdown data
(`trends_projection.dart:_readBreakdown`, `_breakdown`, `trends_body.dart`, `trends_screen.dart`,
`app/test/ui/stats/trends_breakdown_projection_test.dart`).

`TrendsReadyBody.averageComparison` joins selected-period breakdown rows to
`periodSummary.averages.rows` by `(bucketID, mainBucketID, isDirect)`, preserving selected-row order.
A missing selected identity or duplicate identity in either input makes the projection return
`TrendsErrorBody`. The header is `Monthly average` or `Yearly average`; a null mean displays as
`Unavailable`, a genuine zero as plain `0.00`, and other means as signed amounts
(`app/lib/ui/stats/trends/trends_average_comparison.dart`, `trends_projection.dart`).

The selected-period phone breakdown and shared scoped breakdown draw the saved chart (donut or
category map) at the saved level and colour mode, then ranked rows with
swatch, name, a caption of `share / parent` and the
signed amount. A period with no records of the selected kind shows the empty card copy instead of chart
and rows. Colours resolve once per row through `CategoryPalette`; Direct rows use the parent's saved hex
with their own rank. The donut centre label is bounded to the hole, and row labels wrap inside the
card at phone width. A row with a navigation target shows a trailing chevron and a tap action; a row without
one has neither. Both charts forward the tapped item's index and never receive a selected index, so
`selectedMark` stays reserved for selection.

`TrendsBreakdownSection` accepts an optional `header` and `scopeControl`; a supplied scope control
requires a header and places its range and total above the rows. Category averages belong to
`TrendsCategoryAverages`
(`app/lib/ui/stats/trends/trends_breakdown_section.dart`,
`app/lib/ui/stats/trends/trends_category_averages.dart`). Loading, error with Retry and empty bodies
replace financial totals rather than displaying stale values (`trends_screen.dart`).

## Navigation

`TransactionsFlow` handles `HistoryTrendsRequested`, seeds `selectedMonthProvider` from History's
selected date at UTC month start, and pushes one route containing `TrendsFlow(onEnded: ...)`.
`TrendsFlow` uses its nested navigator and renders `TrendsScreen`. The optional History-labelled
header Back delegates to `FlowBase.goBack`; at the root this ends the Flow and pops the History-owned
route. System Back and the iOS edge swipe pop the enclosing route. `TransactionsFlow` holds its
single-route guard until the matching route's `completed` future (`transactions-ui.md`,
`app/lib/ui/transactions/transactions_flow.dart`, `app/lib/ui/common/base/flow_base.dart`).

A row or chart block calls `TrendsViewModel.requestCategoryDetail(rowIndex)`. Its named `source`
parameter defaults to `TrendsCategoryDetailSource.selectedPeriod`, resolving against
`body.breakdown.rows`; `wholePeriod` resolves against `body.wholePeriod.breakdown.rows`. The scoped
presentation supplies the source for the shared breakdown; Category averages always uses
`selectedPeriod`.
The notifier ignores the
request after disposal, outside a ready body, for an invalid index and for a row without a navigation
target, then emits `TrendsCategoryDetailRequested` carrying the unchanged `CategoryDetailArgs`:
`mainID` is the row's `mainBucketID`, `kind` the selected kind, `isYearRange` follows the mode and
`initialDate` is the effective selected UTC period. Null (Uncategorized) and synthetic transfer buckets
have no target and are inert; an unresolved non-null bucket ID stays navigable and displays as
Uncategorized. The notifier keeps the pending step in a private field so clock, preference, query and
Ledger rebuilds preserve it until `clearStep`. `TrendsFlow` listens with `ref.listenManual`, also picks
up a step pending at mount after the first frame, clears the step before dispatching, and pushes
`CategoryDetailScreen` on its own nested navigator. It holds a single-route
guard until that route's `completed` future, so repeated taps and taps during the reverse transition
open no second route. Returning performs no intent update or invalidation.
(`app/lib/ui/stats/trends_flow.dart`, `trends/trends_view_model.dart`,
`app/test/ui/stats/trends_navigation_state_test.dart`).

Category Detail preserves the incoming `CategoryDetailArgs` unchanged. Projection normalizes its
date for the page subtitle, totals and primary entries; switching trend mode or selecting a trend
period never moves that incoming page period.

Budgets live in the Money Budgets segment. Trends does not mount `BudgetsFlow`
(`app/lib/ui/money/money_flow.dart`).

## Screens and flows

- **Trends** - app bar titled "Trends", optional History-labelled back control, the kind and mode
  controls (always mounted), and a body that is skeleton trays, an error box with a filled Retry, the
  fresh-ledger empty state with a disabled period row, or the layout-specific ready composition
  described above
  (`app/lib/ui/stats/trends_screen.dart`, `app/test/ui/stats/trends_layout_test.dart`).
- **Category Detail** - one pushed `CategoryDetailScreen` shows the Trends back action, category
  title, immutable incoming month/year subtitle, kind-token 26 px headline, scope chips, optional
  Subcategories tray, and trend tray. `CategoryDetailArgs` retains its fields and value
  equality; the projection normalizes `initialDate` to UTC month/year start without changing the args
  (`category_detail_args.dart:CategoryDetailArgs`,
  `category_detail_projection.dart:categoryDetailUnreadyState`).
  Chips appear when children exist and offer All, every child, and Direct. Subcategories appears only
  for All with children. It includes zero-total children with a one-decimal parent-total share; the
  Direct breakdown row appears only for a positive direct total. Rows rank by descending total, name,
  then ID. The page headline uses `context.text.headline` and the expense or income `AmountStyle`;
  category color and icon do not style that amount (`category_detail_sections.dart:CategoryDetailHeadline`,
  `category_detail_projection.dart:_chips`, `_directRow`, `_share`).
  The trend tray always presents the effective selected period's signed amount and entries on initial
  load and after mode changes. Its entries use a flat lazy list, newest first, with short
  date/category/account captions and no day headers. An empty selected period displays
  `No entries in this period`
  (`category_detail_screen.dart:_CategoryDetailReadyView`,
  `flat_entry_sliver.dart:FlatEntrySliver`, `category_detail_trend.dart:_selectionSlivers`).
  The trend reuses `TrendsChart`, shared mode controls and period row inside one `SliverTray`.
  Month mode contains twelve chronological months; year mode contains three calendar years. Bounds
  come from the first analysis-included record in the effective scope. Clamps are derived for display
  and do not rewrite the requested intent. The chart mark, amount and entries follow the effective
  selected period on initial load, mode changes, paging and slot selection. Selecting any valid slot
  opens its signed total and entries, including a zero-total slot; the incoming page period remains
  fixed (`category_detail_intent.dart:CategoryDetailIntent`,
  `category_detail_projection.dart:_trendBody`,
  `category_detail_trend.dart:CategoryDetailTrend`).

## Gotchas and invariants

- Analysis-driven totals can differ from Transactions for the same month because analysis also
  applies category inclusion gates. Both totals respect entry-level `includeInAnalysis` and count
  treat-as-expense transfers (`Accounting.classify`, `Accounting.totals`,
  `app/test/ui/transactions_stats_totals_parity_test.dart`).
- The domain classifies treat-as-expense transfers into synthetic account-type buckets; retained
  slice helpers label those buckets and keep them non-navigable (`Accounting.classify`,
  `app/lib/ui/stats/helpers/slices.dart:Slice.isNavigable`).
- Slice fractions guard zero totals.
- A trend period with zero total draws no bar, while its axis label remains selectable. An empty
  effective selected period still shows its signed zero headline and the empty-entry message.
- Category Detail scope and trend intent are route-local and independent of `trendsIntentProvider`.
  `TrendsFlow` pushes one `MaterialPageRoute`, passes its `goBack` action to the detail screen, and
  holds its duplicate-route guard until that route completes. The detail provider and intent are
  auto-dispose families keyed by the incoming args (`app/lib/ui/stats/trends_flow.dart:_openCategoryDetail`,
  `category_detail_view_model.dart:categoryDetailIntentProvider`,
  `app/test/ui/stats/category_detail/category_detail_lifecycle_test.dart`).
- The former `SubcategoryTable`, category `TrendCard`, and `TrendLineChart` are removed. Keep
  `app/lib/ui/stats/helpers/trend.dart`: `budget_detail_view_model.dart` still calls `trendMonths`.

## Requirements

- Category Detail reads only through the shared `AnalysisQueries`; both mixed results must match the
  current Ledger revision, and the spread evaluation day must match `todayProvider` before financial
  content appears (`CategoryDetailNotifier.build`, `projectCategoryDetailWithTrend`).
- Slices roll categories up to main buckets, preserve synthetic transfer buckets, and sort by
  amount descending (`Accounting.rollUp`, `app/lib/ui/stats/helpers/slices.dart:slices`).
- Category Detail's scope, breakdown ordering/shares, mode-relative incoming mark, selected empty
  period projection, lifecycle, and replacement-cache behavior have focused tests
  (`app/test/ui/stats/category_detail/`,
  `app/test/boot/category_detail_cache_retry_test.dart`).
