# Stats & Analysis UI

Last reconciled: 2026-09-02

## Feature overview

The Stats tab and its category drill-down. Stats renders analysis items (post-analysis-gate:
category include-gates and treat-as-expense transfer reclassification) as a donut with leader-line
labels and a category legend, and Category Detail drills into a main category with a subcategory
table, a trend card, and a scoped entry list. Data comes from `AnalysisCache`; the screen calls
`refresh()` on appear and re-renders when the cache revision changes.

## Key files

- `app/lib/ui/stats/stats_root_view_model.dart`, `stats_flow.dart` — the tab view model and Flow.
- `app/lib/ui/stats/donut/` — the donut chart (leader-line labels).
- `app/lib/ui/stats/analysis/` — slice/roll-up helpers.
- `app/lib/ui/stats/category_detail/` — the drill-down screen and view model.
- `app/lib/ui/common/day_sectioned_entry_list.dart` — reused entry list with tap-to-view and
  swipe-delete.
- `packages/domain/lib/src/accounting.dart` — `rollUp`, `fraction`, filtering (see
  `recurring-plans-and-accounting.md`).
- `app/lib/ledger/analysis_cache.dart` — the generation-guarded cache.

## Module interactions

Stats watches `AnalysisCache.revision` to trigger `refresh(state)` and `items`/`itemsRevision` for
results. Slices filter cache items by kind + window, `Accounting.rollUp` to main-category buckets,
and sort by amount descending; slice color is the category `colorHex`, Uncategorized is gray. The
Uncategorized bucket includes treat-as-expense transfers. Category Detail memoizes its
kind+bucket-filtered item scan keyed on the cache's `itemsRevision`, recomputing only when the cache
bumps its revision.

## Navigation

The Stats Flow owns this tab's nested navigator. Category Detail is pushed with
`(mainID, kind, mode, initialDate)`; it has its own date state (seeded from Stats' date) but
inherits mode fixed — the toolbar has the `MonthYearSelector` only, no range menu. The Uncategorized
row in the legend is not navigable.

## Screens and flows

- **Stats tab** — `TopTabBar` (Income | Expense, default Expense), a total line (30 pt bold, blue
  income / red expense = Σ analysis items of the active kind in the window), a donut, and a category
  legend. App bar: `MonthYearSelector` leading and a range menu dropdown (Monthly | Annually)
  trailing that renders on every platform, desktop and web included. Slices: filter, roll up, sort
  descending; donut ring starts at 12 o'clock clockwise with a 1.5° gap and leader-line labels
  (`Name  NN%`). Empty state: `chart.pie` glyph + "No income/expense in this period", replacing the
  donut and list while the total still shows `$0.00`.
- **Category Detail** — a `TransactionsTableView` whose header stack is scope total, subcategory
  table (only when the category has children), trend card, and "ENTRIES"; then the day-sectioned
  entry list (full tap-to-view + swipe-delete). Scope selection is `all` | `sub(id)` | `direct`:
  caption over the total ("Food" / "Food › Hawker" / "Food › Direct"), amount colored by kind. The
  subcategory table's first row is "All \<Main\>" (100%); then child slices and the "Direct" slice
  (id nil, parent color) sorted together by amount, the Direct row existing only when
  main-total − Σ children > 0. Fractions are of the main-category total. The trend card shows a
  smoothed line over `trendMonths` (month mode = 6 months ending at detailDate's month; year mode =
  all 12 months of detailDate's year) with nearest-point selection. `matchingCategoryIDs` drives
  both totals and entry filtering, modeling the null bucket as its own sealed case.

## Gotchas and invariants

- Stats can differ from Transactions for the same month because Stats applies category
  include-gates and treat-as-expense reclassification; Transactions applies only entry-level
  `includeInAnalysis`. This is ruled (ADR-0026). `ui_screens.md` §2.1
- Treat-as-expense transfers land in the Uncategorized bucket; Stats must not invent the recorded
  account-type bucketing ahead of the domain implementing it. `ui_screens.md` §6
- Slice fractions guard the zero-total case; zero/negative slice values clamp out of the ring.
  `ui_screens.md` §3.2
- Accessibility and localization are open work, not built: donut, FAB, two-column picker, and swipe
  actions need Semantics labels, and every format in `ui_screens.md` §0.2 must route through `intl`.
  `ui_screens.md` §6

## Requirements

- Data source is `AnalysisCache`; the screen refreshes on appear and on revision change.
  `ui_screens.md` §3
- Slices roll up to main buckets; Uncategorized includes treat-as-expense transfers; sorted by amount
  descending. `ui_screens.md` §3.2
- Category Detail scope selection, subcategory Direct-bucket threshold (`> 0`), trend windows both
  modes, and `matchingCategoryIDs` are pure, tested functions. `ui_screens.md` §3.4–3.5
- The date/range toolbar renders on every platform. `ui_screens.md` §3
