# Ledger Runtime

Last reconciled: 2026-10-10

## Feature overview

The app-layer runtime that wraps the domain: `Ledger` (the sole mutation hub), `EventBus`
(synchronous broadcast of `LedgerPublication` batches), `AnalysisCache` (a source-revision-stamped cache of analysis
items), `AnalysisQueries` (the shared app-layer read service), `PersistenceProcessor`
(the pipe from bus to store), the boot phase machine, the save/plan
banners, and first-launch seeding. These live in `app/lib/ledger/` and `app/lib/boot/`.

## Key files

- `app/lib/ledger/ledger.dart` - the only object permitted to touch `LedgerState`; every local
  mutation forwards to a domain mutator through `mutate` (`applySyncBatch` below is the sync
  boundary, not a local mutation).
- `app/lib/ledger/event_bus.dart` - one `StreamController<LedgerPublication>.broadcast(sync: true)`.
- `app/lib/ledger/ledger_publication.dart` - the `LedgerPublication` batch (`changes` plus optional sync `stamps`).
- `app/lib/ledger/analysis_cache.dart` - bus-driven cache of `Accounting.analysisItems`, with a
  publication counter and accepted source revision.
- `app/lib/ledger/ledger_session.dart` - pairs a ready Ledger with its non-null analysis cache.
- `app/lib/ledger/analysis_queries.dart` - observable query results, refresh ownership, retry,
  and per-query memoization, including the mixed `readScopedTrend` read.
- `app/lib/ledger/analysis/` - app-owned query result types and pure helpers for summaries,
  entry metadata, register days, recent entries, upcoming items, weeks, search, calendar days,
  firstRecordMonth, period completeness, month and year spreads, category breakdowns, scoped trends,
  and compared with usual.
  The pure-domain card query lives in `packages/domain/lib/src/analysis/card_statement.dart`.
- `app/lib/ui/common/ledger_backed_notifier.dart` - watches the ready session and exposes its
  Ledger and cache to ViewModels.
- `app/lib/persistence/persistence_processor.dart` - subscribes to the bus and forwards each
  publication to `enqueue` (unstamped) or `enqueueStamped` (stamped).
- `app/lib/boot/app_boot.dart`, `app_phase.dart`, `banner_state.dart`, `providers.dart`,
  `seed_data.dart` - boot state machine, banner state, Riverpod wiring, and the sample dataset.
  `providers.dart` also holds `clockProvider` and `todayProvider`; the day
  rollover ticker lives in `app/lib/ui/shell/day_ticker.dart`, and the month
  override in `app/lib/ui/shell/shell_providers.dart`.
- `app/lib/ui/shell/status_banner.dart` - the bottom status banner overlay. The browser-storage
  durability warning (`storage_warning.dart`, `storageIsDurableProvider`) was removed in commit
  `4d465f0` alongside the dropped web platform target; `status_banner.dart` is now the only banner
  in the shell.

## Module interactions

`Ledger._mutate` runs, in order: the domain mutator (throws `LedgerError` on rejection), the debug
invariant sweep, then `_commit`: for a non-empty batch it increments `Ledger.revision`,
publishes one atomic batch, and notifies listeners (`ledger.dart`). `revision` starts at zero and
counts committed batches, including sync batches, rather than individual changes. Empty commits
leave the revision unchanged and publish and notify nothing
(`app/test/ledger/ledger_revision_test.dart`). Local `Ledger` mutations publish unstamped
`LedgerPublication` values (no stamps).
A cascade such as `addPocket` publishes the pocket upsert and the updated parent
account as one batch. A throwing mutator publishes nothing. An empty change list publishes
nothing, even with stamps present (`event_bus.dart:publish`). Delivered publications wrap
`changes` (and `stamps`, when present) in unmodifiable views under the existing debug-only
assert discipline, so a subscriber cannot mutate a batch in flight. An empty stamps map counts
as unstamped: `LedgerPublication.hasStamps` is false and the processor keeps the `enqueue` bump
path (`ledger_publication.dart`, `persistence_processor.dart:_forward`).

`Ledger.applySyncBatch(changes, stamps)` (`ledger.dart`) is the sync apply boundary for an
already-decided remote batch. `SyncCoordinator` calls it after synchronous finalization accepts
the remote changes and stamps (`app/lib/sync/sync_coordinator.dart`). It copies all six tables
into a candidate `LedgerState`, applies the batch there, and calls `candidate.assertInvariants` directly
outside `assert` - structural clauses only, no mutator clause 12 monotonicity, so a legitimate
remote lifecycle transition this device never observed still passes. Only then it adopts the
candidate into the live object (`LedgerState.adopt`) and calls `_commit`. A non-empty sync batch
advances the revision, publishes one stamped `LedgerPublication`, and notifies once; an empty
batch still adopts the candidate but leaves the revision unchanged and publishes and notifies
nothing (`ledger.dart:applySyncBatch`, `_commit`). A validation failure throws before adoption or
commit, so the live tables, the bus, and the listeners are untouched.

The bus connects `PersistenceProcessor` and `AnalysisCache`; UI reacts through Ledger and cache
listeners. `PersistenceProcessor.start` attaches during boot before the Ledger reaches the UI.
`ledgerSessionProvider` attaches the cache when the session is first acquired for a ready Ledger.
Its source-revision getter reads `Ledger.revision`, so the first refresh includes commits made before
subscription (`app/lib/boot/app_boot.dart`, `app/lib/boot/providers.dart:ledgerSessionProvider`).

`ledgerSessionProvider` is a `Provider<LedgerSession?>` that watches `ledgerProvider` and returns
null while the Ledger is unavailable. A ready session pairs that Ledger with a non-null
`AnalysisCache`, started on its bus before the session returns. The provider owns the cache and
registers `ref.onDispose(cache.dispose)`; a replacement Ledger rebuilds the session and disposes
the outgoing cache. Boot does not acquire or start the cache (`app/lib/boot/providers.dart`,
`app/lib/ledger/ledger_session.dart`; provider identity and retry coverage in
`app/test/boot/ledger_session_provider_test.dart`). `analysisComputeRunnerProvider` supplies the
watched `ComputeRunner`, defaults to `isolateComputeRunner`, and supports a `syncComputeRunner`
override while preserving session lifecycle wiring (`app/lib/boot/providers.dart`,
`app/test/boot/ledger_session_provider_test.dart`). `AnalysisCache.start` is idempotent for its
current bus and rejects rebinding to a different bus (`analysis_cache.dart:AnalysisCache.start`).

`LedgerBackedNotifier` watches `ledgerSessionProvider`, throws `StateError` when the session is
null, and exposes the Ledger and cache from that same session
(`app/lib/ui/common/ledger_backed_notifier.dart`).
`AnalysisNotifier.build`, `CategoryDetailNotifier.build`, `BudgetsListNotifier.build`, and
`BudgetDetailNotifier.build` capture that Ledger and cache in `_ledger` and `_cache`. Each build
attaches listeners, registers removal against the captured instances, and awaits the initial
cache refresh. Later notifications refresh the captured `_cache`; session replacement rebuilds
the consumers through their watched dependency (`app/lib/ui/stats/analysis/analysis_view_model.dart`,
`app/lib/ui/stats/category_detail/category_detail_view_model.dart`,
`app/lib/ui/budgets/budget_list/budgets_list_view_model.dart`,
`app/lib/ui/budgets/budget_detail/budget_detail_view_model.dart`).

`AnalysisCache.revision` counts received publications, ignoring stamps. `refresh(state,
sourceRevision: ...)` chooses the explicit source revision, then the bound Ledger getter, then the
publication counter. It captures all six LedgerState tables, including `binnedEntries`, before
running `Accounting.analysisItems` through `isolateComputeRunner`; `syncComputeRunner` is an injectable
test seam (`app/lib/ledger/analysis_cache.dart:refresh`, `isolateComputeRunner`,
`syncComputeRunner`). Requests for the same pending source revision share one Future, and a request
for the accepted source revision does no work. A completion replaces `items` only when its source
revision exceeds `itemsSourceRevision`; acceptance stores an unmodifiable item list, stamps the
source revision, increments `itemsRevision`, and notifies once. Older work may be accepted while
newer work remains pending, but cannot overwrite a newer accepted result
(`analysis_cache.dart:_run`; `app/test/ledger/analysis_cache_source_revision_test.dart`).

A failed computation preserves accepted items and records `lastFailure` as an
`AnalysisCacheFailure` containing the error, stack trace, and source revision. It emits no listener
notification and permits retry at the same revision. Failures at or below the accepted source
revision are inert; an older failure cannot replace a newer retained failure. Acceptance clears
a failure at or below its revision (`analysis_cache.dart:_run`;
`app/test/ledger/analysis_queries_test.dart:olderFailureAfterNewerFailureKeepsTheNewerFailure`).
`dispose` synchronously disables bus handling and late computation
acceptance before awaiting subscription cancellation
(`analysis_cache.dart:dispose`; `app/test/ledger/analysis_cache_source_revision_test.dart`).

## Analysis queries

`AnalysisQueries` is the single shared app-layer read service, exposed by
`analysisQueriesProvider` and bound to one Ledger and its cache. Its pure helpers and result types
live under `app/lib/ledger/analysis/`; `CardStatement` and `cardStatement` are domain-owned
(`packages/domain/lib/src/analysis/card_statement.dart`). It requests refresh on
construction and every Ledger notification, independently of ViewModels. Failed evaluations are a
set of memo keys that each embed the Ledger revision they failed at; every Ledger notification
clears the set (`_onLedgerChanged`), so it only ever holds keys of the current revision. `retry()` clears the failed
evaluations, requests refresh at the current revision, and notifies listeners once when that
request starts new work. That includes an already current cache, where `AnalysisCache.refresh`
returns a completed future without invoking the runner. It does not notify when a refresh for the
revision is already in flight; a later Ledger notification also recovers from a cache failure. Reads and failed refreshes start no recursive work. Disposal removes
its Ledger/cache listeners and suppresses late notifications; cache ownership remains with the
session (`app/lib/ledger/analysis_queries.dart`; `app/test/ledger/analysis_queries_test.dart`).

`analysisQueriesProvider` is a nullable, non-autoDispose `ChangeNotifierProvider` that watches
`ledgerSessionProvider`. It returns null until a ready session exists, creates queries from that
session, and owns their disposal. Session replacement replaces queries with the new Ledger/cache
pair. It reads `todayProvider` initially and listens for changes through `setToday`, so day rollover
updates the existing query object without a cache computation
(`app/lib/boot/providers.dart:analysisQueriesProvider`;
`app/test/boot/analysis_queries_provider_test.dart`).

`readToday()`, `readPeriod(window:, sourceIDs:)`, `readWeeks(window:, sourceIDs:)`,
`readCategoryBreakdown(period:, mode:, kind:, level:)`, and
`readScopedTrend(period:, mode:, kind:, mainBucketID:, scope:)` return
`AnalysisQueryResult<T>` with nullable `value`, `ready`/`loading`/`failed` state, and nullable
`sourceRevision`. These reads mix Ledger state with
analysis items and evaluate only when `cache.itemsSourceRevision == ledger.revision`. While
pending or failed, a previously read query retains its last successful value and that value's
revision, provided its identity is still retained (see the memo bound below); a query without a
successful value returns null for both. A calculation exception fails
only that query. The service notifies on every Ledger notification and day change, so reads that
do not wait for the cache update at once, and notifies again when the cache accepts the current
Ledger revision or that revision's refresh fails. Interim publications and older completions emit
no query notification
(`app/lib/ledger/analysis_queries.dart:_readMixed`, `_onLedgerChanged`, `_onCacheChanged`,
`_requestRefresh`;
`app/test/ledger/analysis_queries_test.dart`, `app/test/ledger/analysis_queries_memo_test.dart`).

Successful mixed results are memoized by query identity, normalized today, Ledger revision, and
accepted cache source revision. Period identity uses normalized window endpoints and a normalized,
deduplicated, sorted source-ID set; null scope and empty scope are distinct. `setToday` normalizes
the calendar day, ignores same-day changes, and notifies on every day change. For mixed reads, a day
change during pending work retains the old value until coherent evaluation can resume.

Memoized results are bounded by `_maxRetainedIdentities` (256 identities). Each read moves its
identity to the most recent position (`_touch`), and storing a result evicts the least recently
read identities beyond the cap (`_retain`). An evicted identity loses its last successful value,
so a later pending or failed read of it returns no previous value
(`app/lib/ledger/analysis_queries.dart`; `app/test/ledger/analysis_queries_memo_test.dart`;
`app/test/ledger/analysis_queries_retention_test.dart`:
`readingMoreThanTheCapEvictsTheOldestIdentity`,
`aRecentlyReadIdentitySurvivesWhileTheOldestIsEvicted`,
`stalePreviousValueSurvivesALedgerChangeWithinTheCap`; retry notification in
`analysis_queries_test.dart`: `retryNotifiesListenersWhenItStartsNewWork`).

`TodaySummary` contains the normalized day, that day's analysis-gated expense total, and an
optional daily guide. The guide uses the applicable unscoped budget's effective monthly limit,
including overrides, divided by calendar days in the month and rounded half-up to whole dollars.
It is null without an applicable budget; multiple applicable unscoped budgets fail evaluation
(`app/lib/ledger/analysis/today_summary.dart`; `app/test/ledger/analysis_today_period_test.dart`).

`PeriodSummary` contains the normalized requested `[start, end)` window, an effective window equal
to it, expense/income totals, `net = income - spent`, and absolute transfer volume `moved`. Totals
are committed amounts: every entry dated in the window counts, including entries dated after today,
so the current month's figure includes bills already logged for later days. An empty window has
zero totals; reversed endpoints fail evaluation.
Without a source scope, totals use cached analysis items. A scope selects active entries touching
any selected source and classifies them against the complete Ledger source set; an empty scope
selects nothing. `moved` counts each qualifying active transfer once, regardless of analysis gates;
treat-as-expense transfers can contribute to both spending and moved volume
(`app/lib/ledger/analysis/period_summary.dart`; `app/test/ledger/analysis_today_period_test.dart`).

`readRegisterDays`, `readRecent`, `readUpcoming`, `readSearch`, `readCalendarDays`,
`readCardStatement`, `readFirstRecordMonth`, `readMonthCompleteness`, and `readWeekCompleteness`
evaluate against the current Ledger without waiting for analysis items.
Successful results carry `Ledger.revision`; memo keys include normalized query parameters and
revision, plus today for day-dependent reads. Exceptions fail only the affected query and retain
its previous successful value if it is still retained (`analysis_queries.dart:_readLedgerOnly`;
`app/test/ledger/analysis_service_test.dart`: `ledgerOnlyReadsComputeWhileMixedReadsStayPending`,
`equivalentReadsReuseAcrossNormalizedScopes`, `queryFailuresAreIsolatedAndRetryRecovers`).

- `readRegisterDays(window:, sourceIDs:, kind:)` returns newest-first populated days, with
  entries in reverse Ledger insertion order within each day. `registerDays` is the shared seam
  for History day groups and calendar selected-day totals. Its `Accounting.totals` semantics
  intentionally include excluded-category entries that analysis totals omit; entry-level
  `includeInAnalysis` still gates totals. Rows remain visible regardless of those flags
  (`app/lib/ledger/analysis/register.dart`: `registerDays`, `registerTotals`;
  `app/test/ledger/analysis_service_test.dart`: `registerPreservesDaySectionsAccounting`,
  `registerTotalsMatchPeriodFixtureAndHistoryEqualsSelectedDay`).
- `readRecent(limit: 4, sourceIDs:)` excludes dates after today and sorts by date descending,
  breaking ties by reverse insertion order. `readSearch(query:, window:, sourceIDs:, kind:)`
  searches trimmed, case-insensitive entry, category, parent-category, source, and destination
  names and returns newest-first month groups with register totals. `registerDays` and
  `searchEntries` build the complete source set once per read and pass it as `complete` to
  `registerDay`/`registerTotals` rather than rebuilding it per day or month (`app/lib/ledger/analysis/register.dart`,
  `app/lib/ledger/analysis/search.dart`; `analysis_service_test.dart`).
- `readUpcoming(window:, sourceIDs:)` defaults to `[today, today + 42 days)` and merges future
  recorded entries, projected plan occurrences, and the next card statement. Same-day ties sort
  statement, plan, entry, then by stable ID. `readCalendarDays(window:, sourceIDs:)` returns
  oldest-first populated days containing recorded entries and projected plans. Both use the same
  cursor-aware projection without mutating Ledger state. Upcoming statements filter by source
  scope before computing `cardStatement`, so out-of-scope cards cost no statement work; see
  [recurring-plans-and-accounting.md](recurring-plans-and-accounting.md)
  (`app/lib/ledger/analysis/upcoming.dart`, `app/lib/ledger/analysis/calendar.dart`; `analysis_service_test.dart`).
- `readWeeks(window:, sourceIDs:)` returns Monday-based full weeks intersecting the requested
  window, including days outside its endpoints. Each effective window is the full week, and totals
  are committed: entries dated after today count, so future weeks can hold spending. A week that
  crosses a month boundary has the same range and amount when read through either month, so a
  month's week rows can add up to more than its period total. Spending and counts use expense
  analysis items; scoped reads classify touching active entries against all source IDs. Every
  scope uses the same cache-revision gate (`app/lib/ledger/analysis/weeks.dart`, `analysis_queries.dart:readWeeks`;
  `analysis_service_test.dart`: `weeksTotalAcrossMonthBoundaryWithCounts`).
- `readFirstRecordMonth()` returns the UTC first day of the month holding the earliest active
  entry of any kind, including system entries and entries excluded from analysis, or null for an
  empty ledger. `readMonthCompleteness(month:)` and `readWeekCompleteness(containingDay:)`
  normalize to the month or Monday-start week and classify it with `classifyPeriod`: preRecord
  before firstRecordMonth (always on an empty ledger), complete once the window ends on or before
  today, otherwise incomplete. Their memo keys include today, so day rollover reclassifies without
  runner work (`app/lib/ledger/analysis/completeness.dart`; `analysis_completeness_test.dart`).
- Completeness reads publish the current Ledger revision while `readWeeks` and `readPeriod` keep
  their previous value during a pending cache refresh. A consumer that combines them treats the
  pair as coherent only when both `sourceRevision` values are non-null and equal, and shows
  loading otherwise (`analysis_completeness_test.dart`:
  `deletingEarliestEntryDuringPendingRefreshSplitsCompletenessFromTotalsUntilAcceptance`).
- `readMonthSpread(endMonth:, kind:)` is a mixed read returning twelve chronological month slots
  ending at `endMonth` for expense or income. Each slot holds only its month, window, committed
  whole-month total and item count; the current-month slot equals `readPeriod` for that month.
  Slots carry no display state: an empty month, before or after the first record, is a zero total
  with item count 0, and the spread has no qualifier text. Completeness is used only by usual and
  insight comparisons. `earliestSpreadEndMonth` bounds backward navigation in 12-month pages
  anchored at the current month. It is computed from firstRecordMonth inside the gated
  evaluation, so it and the totals share one revision. An end month after the current month fails
  the read.
  `MonthSpread` compares its slots element-wise (`app/lib/ledger/analysis/month_spread.dart`;
  `analysis_month_spread_test.dart`).
- `readYearSpread(endYear:, kind:)` is a mixed read returning three chronological calendar-year
  slots ending at `endYear`. Each slot holds its year, `[1 January, next 1 January)` window,
  committed total and item count, including entries dated after today, with no matched-month
  filtering and no display state; an empty year is a zero total. `earliestSpreadEndYear` bounds
  backward navigation in 3-year pages anchored at the current year and is computed from
  firstRecordMonth inside the gated evaluation. An end year after the current year fails the read
  (`app/lib/ledger/analysis/year_spread.dart`; `analysis_year_spread_test.dart`).
- `readCategoryBreakdown(period:, mode:, kind:, level:)` is a mixed read returning
  `AnalysisQueryResult<PeriodBreakdown>` through `_readMixed`, using the pure `categoryBreakdown`
  helper to group `AnalysisItem`s of one kind within one window into ranked `BreakdownRow`s.
  It normalizes `period` with `startOfDayUtc`; month mode covers its calendar month and year mode
  covers `[1 January, next 1 January)`. Both use committed amounts without clipping to today,
  so entries dated after today count. A future period is accepted and yields an empty breakdown
  unless entries are dated there. Row totals equal the matching expense or income total from
  `readPeriod` for that window and the matching month or year spread slot when available.
  Query identity includes mode, window start, kind and level; revision gating, retained values
  and retry follow the shared mixed-read pattern
  (`app/lib/ledger/analysis_queries.dart:readCategoryBreakdown`;
  `app/test/ledger/analysis_category_breakdown_query_test.dart`:
  `mayBreakdownMatchesPeriodAndMonthSlotAtBothLevels`,
  `yearBreakdownCoversCalendarYearAndCountsFutureDecember`, `periodInputsNormaliseToUtcMidnight`,
  `memoIdentitySeparatesByKindLevelModeAndPeriod`, `breakdownFollowsMixedMemoAndRevisionGate`,
  `failedRefreshRetainsBreakdownAndRetryRecovers`, `futurePeriodsAreReadyAndEmptyUnlessBooked`).
  `BreakdownLevel.categories` uses `Accounting.rollUp`; `subcategories` keeps leaf rows and marks
  a main's directly booked items as an `isDirect` 'Direct to <Main>' row when any child exists in
  `state.categories`, regardless of that child's lifecycle or `includeInAnalysis` flag. A childless
  main remains an ordinary row, as do synthetic transfer, uncategorized and unresolved buckets.
  Only positive-amount rows remain, ranked by amount descending, then normalized `bucketID` with
  null last, then non-direct before direct. `total` sums the items filtered by kind and window;
  each row carries a Decimal `sharePercent` of the whole period total, not its parent total,
  to 1 decimal place. Exact-Decimal largest-remainder allocation distributes 1000 tenths so
  a nonempty breakdown's shares sum to exactly 100.0. Equal remainders break by the same bucket
  identity order used for ranking, independent of amount rank. A positive row can have a 0.0 share
  and remains present; an empty breakdown has no rows (`app/lib/ledger/analysis/category_breakdown.dart`;
  `analysis_category_breakdown_test.dart`).
- `readScopedTrend(period:, mode:, kind:, mainBucketID:, scope:)` is a mixed read returning
  `AnalysisQueryResult<ScopedTrend>` through `_readMixed` around the pure `scopedTrend` helper.
  It normalizes `period` with `startOfDayUtc`; month mode anchors at the period's month start,
  and year mode anchors at December 1 of the period's year. Memo identity includes mode, anchor,
  kind, main (`bucket:<id>` or `uncategorized` for null), and scope (`all`, `direct`, or `sub:<id>`).
  Period, anchor, main ID, and subcategory ID are normalized before identity construction;
  `SubCategoryScope` normalizes its ID on construction. Revision gating, retained values, and
  retry follow the shared mixed-read pattern. A future month or year, or a subcategory scope that
  is not a child of the main, returns a failed result only for its own identity
  (`app/lib/ledger/analysis_queries.dart:readScopedTrend`, `_readMixed`;
  `app/test/ledger/analysis_scoped_trend_query_test.dart`:
  `memoIdentitySharesEquivalentInputs`, `memoIdentitySeparatesByKindModePeriodMainAndScope`,
  `trendFollowsMixedMemoAndRevisionGate`, `failedRefreshRetainsTrendAndRetryRecovers`,
  `invalidTrendFailsOnlyItsIdentity`). The helper filters items for a nullable,
  normalized main bucket using `AnalysisCategoryScope`: `all` matches `Accounting.mainBucketID`,
  `direct` matches the raw normalized bucket, and `subcategory` matches its raw normalized bucket
  after checking that it names a real child of the supplied main; invalid child/main pairs throw
  `ArgumentError`. Unknown, synthetic and null mains yield zero when unmatched. It computes no first record month
  (`scopedTrend` passes `firstRecordMonth: null`). It reuses pure
  `monthSpread` and returns a `ScopedTrend` with 12 chronological `MonthSlot`s of the requested kind.
  `AnalysisPeriodMode.month` covers the 12 months ending at the period's month; a future month
  throws `ArgumentError`. `year` covers January through December of the period's year, anchored
  at December; a future year throws `ArgumentError`. Year mode covers every entry dated in the
  selected calendar year as committed amounts, including entries dated after today; months with
  no entries are zero with itemCount 0. Scopes and results have value equality, including element-wise slots
  (`app/lib/ledger/analysis/analysis_category_scope.dart`,
  `scoped_trend.dart`; `app/test/ledger/analysis_scoped_trend_test.dart`:
  `month mode all scope sums children and direct`, `invalid child parent pairs throw`,
  `includes months after today in year mode`, `independent equal trends are equal`).
- `readComparedWithUsual(month:, kind:)` is a mixed read for a pace comparison. The observed
  total covers the selected month up to today for the current month, or the whole month for a past
  month. The usual is the mean of the same elapsed days in exactly the three calendar months before
  it, each clipped to its own length; it is `available` only when all three months are complete
  under D8, otherwise `notEnoughData`, which screens show as 'Not enough data'. `baselineTotal` is
  exact and `usualMean` is its third at scale 12, so comparisons should use
  `observedTotal * 3` against `baselineTotal`. The headline figure stays the committed
  whole-month total. A selected month after the current month fails the read. The pure
  `previousCompleteMonthWindows` helper is shared with insights and does not reject future
  selections (`app/lib/ledger/analysis/compared_with_usual.dart`;
  `analysis_compared_with_usual_test.dart`).
- `readMatchedDayInsights()` and `readWeekSoFar()` are parameterless mixed reads at today with fixed
  `InsightRules` (optional constructor argument, not part of the memo key). Defaults: usual at least
  10, change at least 20, relative change at least 20%, at least 5 baseline expenses, at most 2
  category changes; every gate is inclusive and decided by exact cross-products on `3 * observed -
  baseline`, never on the rounded `usualMean`. Category changes compare day 1 to today with the same
  days of the three previous complete months (`previousCompleteMonthWindows`), roll expenses up to
  main categories, and count the 5 expenses per rolled-up category across its three baseline
  windows. They rank by absolute change, ties by bucket ID with null last. A missing baseline
  gives `historyNeeded` with no windows or changes; a complete baseline is `available` even with no
  changes. Week so far compares Monday to today with the same weekdays of the three preceding full
  weeks, each complete under D8 before clipping; a week without expenses counts as zero, and fewer
  than 5 aggregate baseline expenses gives `historyNeeded` with evidence kept and `qualifies`
  false. Results carry bucket IDs, windows and numbers only; `difference` and `usualMean` are
  thirds at scale 12 and `relativeChangePercent` is null for a zero baseline
  (`app/lib/ledger/analysis/insight_rules.dart`, `matched_day_insights.dart`, `week_so_far.dart`;
  `analysis_insights_test.dart`, `analysis_insights_queries_test.dart`).
- `readCardStatement(accountID:)` wraps the domain query at today. An ineligible account returns
  a ready result with null value and the current Ledger revision (`analysis_queries.dart`;
  `analysis_service_test.dart`: `ineligibleCardIsReadyNullWithRevision`).

## Boot order

Exact and verified against `app_boot.dart`:

1. Create the store; any throw → `failed`.
2. `store.setErrorHandler(handler)` before seeding, so a failing seed save surfaces through the
   banner.
3. `store.seedIfFirstLaunch(sampleSeedChanges)`.
4. `state = await store.load()`; throw → `failed`.
5. Read and project the sync metadata snapshot; a read or decode failure yields
   `HostedSyncUnavailable` without blocking ledger readiness.
6. Create the `EventBus`.
7. Create `PersistenceProcessor(store, bus)` and call `processor.start()`.
8. Create `Ledger(state, bus)`.
9. Wire `ledger.onPlanError = showPlanError`.
10. Phase → `ready(ledger, processor)`.

Any uncaught boot error lands in `failed(error)`; there is no partial-ready state. Provider
dependency direction is `appBootProvider → appPhaseProvider → ledgerProvider →
ledgerSessionProvider`; `persistenceProcessorProvider` also derives from the phase. The cache
follows Ledger identity across retries, while `bannerStateProvider` is read by boot independently
(`app/lib/boot/providers.dart`). `ledgerDatabaseProvider` is
the sole boot owner of the shared `LedgerDatabase`; `storeProvider` builds `DriftLedgerStore`
from it, and `syncMetadataStoreProvider` builds `SyncMetadataStore` from that same instance.
`AppBoot.onRetry` invalidates `ledgerDatabaseProvider` and `syncMetadataStoreProvider` alongside
`storeProvider` and `databaseConnectionProvider`, ensuring a retry can reopen the database after
a failed lazy connection. Source: `app/lib/boot/providers.dart` - provider definitions and
`appBootProvider`'s `onRetry`.

`appBootProvider` supplies `AppBoot.readSyncSnapshot` from the shared `SyncMetadataStore`.
`AppBoot.syncStatus` starts as `HostedSyncUnavailable`, and each restart resets it to that value
before reading a new snapshot after ledger load and before creating the event bus.
`hostedSyncStatusProvider` exposes the projected value. `refreshSyncStatus()` rereads metadata
after later changes. Each start or refresh advances a generation so an older read cannot overwrite
a newer status. Source:
`app/lib/boot/app_boot.dart` - `AppBoot.start`, `_loadSyncStatus`, `refreshSyncStatus`;
`app/lib/boot/providers.dart` - `appBootProvider`, `hostedSyncStatusProvider`.

## Boot phase machine

`AppPhase` is `loading` (spinner), `ready` (root shell with the ledger injected and the banner
overlay active), or `failed(error)` (headline "Couldn't load your data", error description, and a
Retry button that resets phase to `loading` and re-runs the whole boot).

## Lifecycle hooks

`AppBoot` (a `ChangeNotifier` with `WidgetsBindingObserver`) acts only when phase is `ready`: on
`AppLifecycleState.resumed` it calls `ledger.resolvePlans(now())`; on `inactive`/`paused`/`hidden`
it calls `persistence.flush()` (fire-and-forget). `resolvePlans` is called once explicitly inside
`start()` when entering `ready`, and again on each lifecycle resume
(`AppBoot.start`, `AppBoot.didChangeAppLifecycleState`). `now` is `AppBoot`'s injectable
`DateTime Function()` field, defaulting to the `@visibleForTesting` static
`AppBoot.utcNowFor([DateTime? localNow]) => startOfDayUtc(localNow ?? DateTime.now())` - UTC midnight of the *local*
calendar day, not merely "a UTC instant." Before commit `26f6cd4`, the default was
`DateTime.now().toUtc()`, which preserves the wall-clock instant rather than the calendar day: for
any device with a positive UTC offset, this shifted the resolved day back by one for part of each
local day, delaying a recurring plan's due occurrence (issue #41). `utcNowFor`'s `localNow`
parameter exists solely so a test can supply a fixed local `DateTime` crossing a day boundary,
since the real system clock's offset cannot be controlled deterministically in this repo's test
suite. Backgrounding `flush()` is the load-bearing durability moment: it pushes the debounced
store's pending batch to disk before the OS can kill the process.

## Clock seam

`clockProvider` (defaulting to `DateTime.now`) and `todayProvider`
(`startOfDayUtc` of the clock) give every screen one notion of today. A
`DayTicker` owned by `AppShell` invalidates `todayProvider` on app resume and
at each local midnight through a re-arming one-shot timer, cancelled on
dispose. `selectedMonthProvider` is a nullable user override and
`effectiveMonthProvider` falls back to the month of today, so an unset month
follows a day rollover into a new month while a chosen month stays. Many
ViewModels (transactions, accounts, budgets, plans, the entry form) still read
`DateTime.now()` directly and do not follow the clock seam or a pinned
`clockProvider` in tests. Source: `app/lib/boot/providers.dart` - `clockProvider`,
`todayProvider`; `app/lib/ui/shell/day_ticker.dart` - `DayTicker`;
`app/lib/ui/shell/shell_providers.dart` - `selectedMonthProvider`,
`effectiveMonthProvider`; `app/lib/ui/shell/app_shell.dart` -
`_AppShellState`; `app/test/boot/clock_test.dart`.

## `resolvePlans` + `onPlanError`

`resolvePlans(now)` runs `state.resolvePlans(now)` inside `mutate`; the materialized entries,
updated plan cursors, and retired-plan changes land as one batch. Failures do not abort the
mutation - successful occurrences still commit. After `mutate` completes, if failures are
non-empty, `onPlanError?.call(failures)` runs. `PlanFailure` carries `planID`, `occurrence`, and
`error` (an entry-validation failure, distinct from a plan silently reaching its `endDate`).

## Banners

`StatusBanner` is bottom-anchored inside a `SafeArea` with a 16 dp minimum bottom inset. A hosted
sync repair banner takes precedence whenever `hostedSyncStatusProvider` is
`HostedSyncBindingRepair` or `HostedSyncSessionReauth`. It is persistent, tappable, non-dismissible,
and exposes button semantics. A tap opens Settings and calls `SettingsRootNotifier.requestRepair()`
only when `enrollmentFlowOpenProvider` is false, so an open fresh route awaiting binding authorization
remains the single route. It hides while either a fresh enrollment or repair route is open and
Settings is open. Its position uses the same bottom anchoring as the timed pill. Source:
`app/lib/ui/shell/status_banner.dart` - `StatusBanner.build`, `_RepairBanner.build`.

When no repair banner is displayed, the single banner slot shows `planError ?? saveStateMessage`,
with plan error taking precedence. These timed messages remain in `BannerState` while repair is active
and show again after repair ends. Save-state messages come from the store's error handler
(`persistence.md` §1): `retrying` → "Couldn't save changes, retrying"; `failedWillRetry` →
"Couldn't save changes, will retry shortly"; `clear` → no banner. Plan-error message is
count-aware over distinct plan IDs ("A recurring plan couldn't add its entry" / "N recurring plans
couldn't add their entries"), auto-dismisses after 4 seconds, and a re-fire cancels the prior
dismissal timer. Source: `app/lib/ui/shell/status_banner.dart`, `app/lib/boot/banner_state.dart`.

## Seeding contract

`store.seedIfFirstLaunch(changes)` is gated on the store-meta `hasSeeded` flag, never on database
emptiness - a user who deletes everything is not re-seeded. On first launch it sets `hasSeeded =
true` first, then `enqueue(changes)`, then `await flushNow()`, so the seed is on disk before
`load()` runs and a crash mid-seed does not double-seed. The seed changes are produced by building
the sample dataset through the real Ledger mutation APIs into a fresh `LedgerState`, then taking
`seedChanges` - every money source, category, entry, and plan as an upsert, in the order
moneySources, categories, entries, plans. The Dart seed builder asserts/throws in debug, unlike
Swift's `try?`, so a validation tightening thins the seed loudly. The sample dataset covers a
transfer without category, an uncategorized expense, subcategory entries, a prev/current/next-month
spread, card-vs-checking sourcing, and two live plans (`app/lib/boot/seed_data.dart`).

Seed data is unchanged by these reads and remains independent of query presentation. Query contracts use controlled test
fixtures; mockup and sample-seed figures are not calculation targets
(`app/lib/boot/seed_data.dart`, `app/test/ledger/analysis_service_test.dart`,
`app/test/ledger/analysis_today_period_test.dart`).

## Gotchas and invariants

- `AnalysisCache.itemsSourceRevision` starts at -1, so the first refresh computes even when
  `Ledger.revision` is zero. Cache publication counts can lag Ledger revisions when acquisition
  follows earlier commits; use the bound source revision for snapshot identity
  (`app/lib/ledger/analysis_cache.dart`, `app/lib/boot/providers.dart:ledgerSessionProvider`).
- `resolvePlans` has no calendar parameter; `ledger_state_plans.dart` works in fixed UTC, so the
  caller must pass UTC midnight of the correct *calendar day* at boot, on resume, and after plan
  creation - not merely any UTC-zoned instant. `.toUtc()` alone is the wrong normalizer here: it
  preserves the wall-clock instant, which shifts the day for a positive UTC offset. Use
  `startOfDayUtc(localDateTime)` (`calendar_day.dart`) on a local, non-UTC `DateTime` instead -
  `AppBoot.utcNowFor` is the boot-layer's instance of this pattern (see Lifecycle hooks above); the
  same pattern is applied at `EntryFormViewModel.save` and three budget ViewModels (#38).
- With `sync: true`, a subscriber callback runs inside `mutate`; subscribers must never call back
  into `Ledger.mutate` (Dart's sync controller throws on reentrant `add`). Neither ported
  subscriber does.

## Requirements

- `todayProvider` advances on resume and at local midnight; an unset month
  follows today into a new month while a chosen month stays.
  (`app/test/boot/clock_test.dart`)
- `Ledger` is the only object allowed to touch `LedgerState`; views never hold a `LedgerState`
  reference. (`ledger.dart`)
- Every successful non-empty commit increments `Ledger.revision` before publication and listener
  notification; rejected and empty commits leave all three unchanged
  (`app/lib/ledger/ledger.dart:_commit`, `app/test/ledger/ledger_revision_test.dart`).
- Persistence attaches during boot; the nullable session provider owns and attaches the cache
  on acquisition for its ready Ledger and obtains source revisions from that Ledger
  (`app/lib/boot/app_boot.dart`, `app/lib/boot/providers.dart:ledgerSessionProvider`).
- Seeding is gated on `hasSeeded`, not emptiness, and the flag commits atomically with the seed
  data. (`persistence.md` §7)
- `resolvePlans` is called on entering `ready` and on resume, always with UTC midnight of the
  correct local calendar day, never a `.toUtc()`-shifted instant. (`AppBoot.utcNowFor`,
  `AppBoot.start`, `AppBoot.didChangeAppLifecycleState`,
  test `utcNowForKeepsTheLocalCalendarDayInsteadOfShiftingItViaToUtc`)
