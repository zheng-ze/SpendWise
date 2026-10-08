# Stats & Analysis UI

Last reconciled: 03903fe

## Feature overview

The Stats tab and its category drill-down. Stats renders analysis items (post-analysis-gate:
category include-gates and treat-as-expense transfer reclassification) as a donut with leader-line
labels and a category legend, and Category Detail drills into a main category with a subcategory
table, a trend card, and a scoped entry list. Data comes from the ready Ledger's `AnalysisCache`;
`AnalysisNotifier` and `CategoryDetailNotifier` refresh during build and on Ledger or cache
notifications (`app/lib/ui/stats/analysis/analysis_view_model.dart`,
`app/lib/ui/stats/category_detail/category_detail_view_model.dart`).

## Key files

- `app/lib/ui/stats/stats_root_view_model.dart`, `stats_flow.dart` - the tab view model and Flow.
- `app/lib/ui/stats/donut/` - the donut chart (leader-line labels).
- `app/lib/ui/stats/analysis/` - slice/roll-up helpers.
- `app/lib/ui/stats/category_detail/` - the drill-down screen and view model.
- `app/lib/ui/common/day_sectioned_entry_list.dart` - reused entry list with tap-to-view and
  swipe-delete.
- `packages/domain/lib/src/accounting.dart` - `rollUp`, `fraction`, filtering (see
  `recurring-plans-and-accounting.md`).
- `app/lib/ledger/analysis_cache.dart` - the source-revision-stamped cache; ownership and acceptance
  contracts are in [ledger-runtime.md](ledger-runtime.md).

## Module interactions

`AnalysisNotifier.build` and `CategoryDetailNotifier.build` obtain the ready Ledger before
reading `analysisCacheProvider` as non-null. Each attaches Ledger and cache listeners, awaits the
initial `cache.refresh(ledger.state)`, and refreshes on subsequent notifications. Cache ownership
follows Ledger identity through `app/lib/boot/providers.dart:analysisCacheProvider`; the ViewModels
read the cache value with `ref.read(analysisCacheProvider)!`, rather than its provider notifier
(`app/lib/ui/stats/analysis/analysis_view_model.dart`,
`app/lib/ui/stats/category_detail/category_detail_view_model.dart`).

Slices filter cache items by kind and window, roll up to main-category buckets with
`Accounting.rollUp`, and sort by amount descending. Slice color comes from the category's
`colorHex`; Uncategorized is gray and includes treat-as-expense transfers
(`app/lib/ui/stats/helpers/slices.dart`). Category Detail's `AnalysisScan` memoizes filtering by
cache identity, `itemsRevision`, kind, and bucket set. Cache identity is essential because a
replacement Ledger's cache restarts `itemsRevision`, which can equal the previous cache's revision
(`app/lib/ui/stats/analysis/analysis_scan.dart:AnalysisScan.scan`,
`app/lib/ui/stats/category_detail/category_detail_view_model.dart:_buildState`;
`app/test/ui/stats/analysis/analysis_scan_test.dart`,
`app/test/boot/category_detail_cache_retry_test.dart`).

## Navigation

The Stats Flow owns this tab's nested navigator. Category Detail is pushed with
`(mainID, kind, mode, initialDate)`; it has its own date state (seeded from Stats' date) but
inherits mode fixed - the toolbar has the `MonthYearSelector` only, no range menu. The Uncategorized
row in the legend is not navigable.

## Screens and flows

- **Stats tab** - `TopTabBar` (Income | Expense, default Expense), a total line (Instrument Sans
  headline, income token / expense token = Σ analysis items of the active kind in the window), a donut, and a category
  legend. App bar: `MonthYearSelector` leading and a range menu dropdown (Monthly | Annually)
  trailing that renders on every platform, desktop and web included. Slices: filter, roll up, sort
  descending; donut ring starts at 12 o'clock clockwise with a 1.5° gap and leader-line labels
  (`Name  NN%`). Empty state: `chart.pie` glyph + "No income/expense in this period", replacing the
  donut and list while the total still shows `S$0.00`.
- **Category Detail** - a `TransactionsTableView` whose header stack is scope total, subcategory
  table (only when the category has children), trend card, and "ENTRIES"; then the day-sectioned
  entry list (full tap-to-view + swipe-delete). Scope selection is `all` | `sub(id)` | `direct`:
  caption over the total ("Food" / "Food › Hawker" / "Food › Direct"), amount in the kind's
  `AmountStyle` colour (the expense token for expense categories, never a category colour). The
  subcategory table's first row is "All \<Main\>" (100%); then child slices and the "Direct" slice
  (id nil, parent color) sorted together by amount, the Direct row existing only when
  main-total − Σ children > 0. Fractions are of the main-category total. The trend card shows a
  smoothed line over `trendMonths` (month mode = 6 months ending at detailDate's month; year mode =
  all 12 months of detailDate's year) with nearest-point selection. `matchingCategoryIDs` drives
  both totals and entry filtering, modeling the null bucket as its own sealed case.

## Gotchas and invariants

- Stats can differ from Transactions for the same month because Stats applies category
  include-gates and treat-as-expense reclassification; Transactions applies only entry-level
  `includeInAnalysis`. This is ruled.
- Treat-as-expense transfers land in the Uncategorized bucket; Stats must not invent the recorded
  account-type bucketing ahead of the domain implementing it.
- Slice fractions guard the zero-total case; zero/negative slice values clamp out of the ring.
- Accessibility and localization are open work, not built: donut, FAB, two-column picker, and swipe
  actions need Semantics labels, and every format in `ui_screens.md` §0.2 must route through `intl`.

## Requirements

- Analysis ViewModels acquire the cache after obtaining a ready Ledger, refresh during build and
  on Ledger/cache notifications, and scope memoized scans to cache identity
  (`AnalysisNotifier.build`, `CategoryDetailNotifier.build`, `AnalysisScan.scan`).
- Slices roll up to main buckets; Uncategorized includes treat-as-expense transfers; sorted by amount
  descending.
- Category Detail scope selection, subcategory Direct-bucket threshold (`> 0`), trend windows both
  modes, and `matchingCategoryIDs` are pure, tested functions.
- The date/range toolbar renders on every platform.
