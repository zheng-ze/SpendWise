# Add the stats screen and category drill-down

## Why

The domain classifies every entry into analysis items and rolls them into buckets, and the runtime
caches that work — but nothing displays it. There is no way to see where money went.

This is the fourth screen in the master doc's build order. It is also the screen with the most
derived state in the app: slices, sub-slices, trend windows and category scoping are all computed,
and V1 computed them inside view models constructed in view bodies, untested.

## What Changes

- Add the stats screen: an income/expense tab pair defaulting to expense, a total line, a donut, and
  a category legend, over a month or year window.
- Render the full toolbar on every platform. V1 compiled its date and range controls for iOS only,
  leaving macOS with no way to change the period at all.
- Add slice derivation as a pure function: filter cached analysis items by kind and window, roll them
  up to main buckets, and order by amount descending with fractions of the total.
- Add the donut with leader-line labels, a gap between slices, and zero-or-negative values clamped
  out of the ring.
- Add the legend rows, navigable to a category detail screen except for the uncategorized bucket.
- Add the category detail screen: its own date state with the mode inherited fixed, a scope selector
  across all, a subcategory, or the parent directly, a subcategory table, a trend chart and a
  day-sectioned entry list.
- Add the scoping rules, the trend windows and the direct-bucket threshold as pure functions.
- Keep the revision-keyed memoization so a detail screen rescans only when the analysis cache
  actually changes.

Not **BREAKING**: additive. No domain, runtime or persistence behavior changes.

## Capabilities

### New Capabilities

- `stats-screen`: the kind and period selection, slice derivation, donut presentation and legend.
- `category-detail`: the drill-down — scoping, the subcategory table, the trend window and the scoped
  entry list.

### Modified Capabilities

None.

## Impact

- New code in `app/lib/ui/stats/`, with the derivations kept separate from widgets.
- New tests in `app/test/ui/stats/`, plus a golden test for the donut.
- New dependency on `app/`: `fl_chart` for the trend line, and for the donut if it can render leader
  lines cleanly — otherwise a custom painter.
- No change to `packages/domain/`, the runtime or persistence.
- This screen's totals are post-analysis-gate, so they can differ from the transactions screen for the
  same month. That divergence is the open decision recorded in `add-transactions-ui`; it is not
  resolved here.
