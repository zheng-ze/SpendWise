# Trends & Category Detail UI

Last reconciled: 2026-10-21

## Feature overview

History opens a full-screen Trends page through its own `TransactionsFlow` navigator. Trends currently
shows a header and empty content area. It has no period controls, analysis presentation, or category
drill-down entry point. Category Detail remains available to its retained consumers and shows a
main category's subcategory table, trend card, and scoped entry list. Its analysis data comes from
the ready Ledger's `AnalysisCache` (`app/lib/ui/stats/category_detail/category_detail_view_model.dart`).

## Key files

- `app/lib/ui/stats/trends_flow.dart` and `trends_screen.dart` - the hosted Flow and blank Trends
  page; the optional `onBackPressed` callback controls the History-labelled back button.
- `app/lib/ui/stats/category_detail/` - the retained category drill-down screen and view model.
- `app/lib/ui/stats/analysis/analysis_scan.dart` - memoized category-detail filtering.
- `app/lib/ui/stats/helpers/slices.dart` - category slice and roll-up helpers used by retained
  consumers.
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
(`app/lib/ui/stats/category_detail/category_detail_lifecycle_test.dart`).

Slices filter cache items by kind and window, roll up to main-category buckets with
`Accounting.rollUp`, and sort by amount descending. Slice color comes from the category's
`colorHex`; Uncategorized is gray and includes treat-as-expense transfers
(`app/lib/ui/stats/helpers/slices.dart`). Category Detail's `AnalysisScan` memoizes filtering by
cache identity, `itemsRevision`, kind, and bucket set. Cache identity matters because a replacement
Ledger's cache restarts `itemsRevision` and can match the previous cache's revision
(`app/lib/ui/stats/analysis/analysis_scan.dart:AnalysisScan.scan`,
`app/lib/ui/stats/category_detail/category_detail_view_model.dart:_buildState`,
`app/test/ui/stats/analysis/analysis_scan_test.dart`,
`app/test/boot/category_detail_cache_retry_test.dart`).

## Navigation

`TransactionsFlow` handles `HistoryTrendsRequested`, seeds `selectedMonthProvider` from History's
selected date at UTC month start, and pushes one route containing `TrendsFlow(onEnded: ...)`.
`TrendsFlow` uses its nested navigator and renders `TrendsScreen`. The optional History-labelled
header Back delegates to `FlowBase.goBack`; at the root this ends the Flow and pops the History-owned
route. System Back and the iOS edge swipe pop the enclosing route. `TransactionsFlow` holds its
single-route guard until the matching route's `completed` future (`transactions-ui.md`,
`app/lib/ui/transactions/transactions_flow.dart`, `app/lib/ui/common/base/flow_base.dart`).

Trends currently has no category navigation. Category Detail retains its own date state, seeded by
its caller, and inherits a fixed month or year mode. Its toolbar has the `MonthYearSelector` only;
it has no range menu.

Budgets live in the Money Budgets segment. Trends does not mount `BudgetsFlow`
(`app/lib/ui/money/money_flow.dart`).

## Screens and flows

- **Trends** - app bar titled "Trends", optional History-labelled back control, and empty expanded
  content. It has no Income/Expense tabs, date or range selector, analysis body, or category
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

- Analysis-driven totals can differ from Transactions for the same month because analysis applies
  category include-gates and treat-as-expense transfer reclassification; Transactions applies only
  entry-level `includeInAnalysis`. This is a ruled behavior.
- Treat-as-expense transfers land in Uncategorized; account-type bucketing belongs to the domain.
- Slice fractions guard zero totals.

## Requirements

- Category Detail captures the ready session's Ledger and cache during build, uses that cache for
  listener removal and later refreshes, and scopes memoized scans to cache identity
  (`CategoryDetailNotifier.build`, `AnalysisScan.scan`).
- Slices roll up to main buckets; Uncategorized includes treat-as-expense transfers; slices sort by
  amount descending.
- Category Detail scope selection, subcategory Direct-bucket threshold (`> 0`), trend windows in
  both modes, and `matchingCategoryIDs` are pure, tested functions.
