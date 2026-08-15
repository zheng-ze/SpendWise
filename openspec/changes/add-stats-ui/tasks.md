Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ui_screens.md` §3, which is more detailed than the
specs in this change.

Depends on `add-app-shell-and-boot` and `add-transactions-ui` — the detail screen reuses day sections
and the entry sheet.

## 1. Screen frame

- [x] 1.1 Add the screen: income/expense tab pair defaulting to Expense, divider, scrollable column of
      total line, donut, divider, category list
      (`app/lib/ui/stats/stats_screen.dart:32-190`)
- [x] 1.2 Add the app bar: month/year selector leading, range menu trailing toggling Monthly/Annually,
      with the selector label and window following the range
      (`stats_screen.dart:111-133`, window at `87-92`)
- [x] 1.3 Render the full toolbar on EVERY platform — V1 compiled these controls for iOS only, leaving
      macOS unable to change the period (`design.md`)
      (no platform gating in `stats_screen.dart`, verified by reading the file in full)
- [x] 1.4 Read from the `AnalysisCache` provider: request a refresh on appear, re-render when the
      cache bumps its items revision. Do not scan entries directly
      (`stats_screen.dart:38-49`, `refresh()` called every build, no-ops when current)
- [x] 1.5 Add the total line: sum of items of the active kind in the window, labelled per kind and
      colored as gain or loss
      (`stats_screen.dart:94-109, 151-164`)
- [x] 1.6 Test: the default kind; range switching changing both label and window; the total over a
      window
      (`app/test/ui/stats/stats_screen_test.dart`)

## 2. Slices

- [x] 2.1 Add `slices(items, kind, window, state)` as a pure function: filter by kind and window, roll
      up to main buckets, one slice per bucket, sorted by amount descending
      (`app/lib/ui/stats/slices.dart:35-54`, rolls up via `Accounting.rollUp`)
- [x] 2.2 Each slice carries its fraction of the total; the null bucket is Uncategorized and absorbs
      treat-as-expense transfers
      (`slices.dart:62-64` zero-total guard, `Slice.bucketID` doc at line 26)
- [x] 2.3 Slice color from the category, gray for Uncategorized
      (`slices.dart:68-70`, `colorHexFallback`)
- [x] 2.4 Test: ordering; subcategory folding into its parent; Uncategorized bucketing; fraction math
      including the zero-total guard
      (`app/test/ui/stats/slices_test.dart`)

## 3. Donut

- [x] 3.1 Add the donut: ring geometry per the module spec, slices from 12 o'clock clockwise in list
      order, 1.5° gap between slices and no gap when there is only one
      (`app/lib/ui/stats/stats_donut.dart:60-89`, gap logic at `64`)
- [x] 3.2 Clamp zero and negative values out of the ring
      (`stats_donut.dart:28`, filtered before layout)
- [x] 3.3 Add leader-line labels: line from the slice mid-angle to an elbow past the ring, then
      horizontally away from center; label is name plus rounded percent, clamped to stay on canvas
      (`stats_donut.dart:96-156`)
- [x] 3.4 Use `fl_chart` only if it places leader lines cleanly; otherwise write a custom painter
      rather than compromising the labels (`design.md`). Add `fl_chart` to `app/pubspec.yaml`
      (EDIT: `fl_chart` added to `pubspec.yaml` but unused — leader lines with an independently
      positioned elbow and two-tone label text have no clean `PieChartSectionData` path, so
      `stats_donut.dart` is a `CustomPainter` per `design.md`'s own fallback instruction)
- [x] 3.5 Add the empty state replacing donut and list, naming the active kind, with the total line
      still showing zero
      (`stats_screen.dart:168-169, 192-224`)
- [x] 3.6 Golden test the donut, including the single-slice case
      (`app/test/ui/stats/stats_donut_test.dart`, goldens `stats_donut_multi.png`/`stats_donut_single.png`)
- [x] 3.7 Test: the empty state
      (`stats_screen_test.dart`)

## 4. Legend

- [x] 4.1 Add legend rows in the same descending order: category icon, name with percent caption,
      trailing amount, chevron. Dividers indented past the icon
      (`app/lib/ui/stats/stats_legend.dart:46-104`)
- [x] 4.2 Tapping a row pushes the category detail screen for that main category
      (`stats_screen.dart:82-91`, pushes `CategoryDetailScreen` with `mainID`/`_kind`/range/date)
- [x] 4.3 The Uncategorized row is NOT navigable — no chevron, no push. It is a bucket, not a category
      (`stats_legend.dart:36-38`, `onTap: null` when `bucketID == null`)
- [x] 4.4 Test: tapping Uncategorized pushes nothing
      (`app/test/ui/stats/stats_legend_test.dart`, asserts callback not invoked)

## 5. Category detail — scope and totals

- [x] 5.1 Add the detail screen taking the main category, kind, range and an initial date
      (`app/lib/ui/stats/category_detail_screen.dart:28-40`)
- [x] 5.2 Give it its own date state seeded from Stats, with the range INHERITED FIXED — selector only,
      no range menu
      (`category_detail_screen.dart:101-103` seeds `_detailDate`; app bar at `172-182` has only
      `MonthYearSelector`, no range toggle)
- [x] 5.3 Add `matchingCategoryIDs(id, scope)` as a pure function: whole scope matches the main plus its
      children, sub scope matches that id alone, direct scope matches the parent's own id exactly.
      Model the null bucket explicitly rather than as an absent optional (`design.md`)
      (`app/lib/ui/stats/category_scope.dart:28-45`; sealed `CategoryScope` with `SubScope.subID`
      typed `String?` keeps the null bucket distinct from `AllScope`'s no-constraint case)
- [x] 5.4 Add the scope total with its caption per scope, colored by kind
      (`category_detail_screen.dart:161-164, 191-204`, caption via `_scopeCaption` at line 261)
- [x] 5.5 Test the `matchingCategoryIDs` matrix across all three scopes plus the null bucket
      (`app/test/ui/stats/category_scope_test.dart`)

## 6. Subcategory table

- [x] 6.1 Add the table, shown only when the category has children
      (`category_detail_screen.dart:208-217` `if (children.isNotEmpty)`)
- [x] 6.2 First row is the whole category: full proportion, combined total. It is view-side and always
      first — a scope control rather than a slice
      (`_SubcategoryTable` build, `category_detail_screen.dart:355-365`, `fraction: Decimal.one`,
      always emitted before the sorted `rows` list)
- [x] 6.3 Children and the direct row sort TOGETHER by amount descending, so the direct row ranks by its
      own amount rather than being pinned
      (`category_detail_screen.dart:330-350` builds one `rows` list with children and the direct
      entry, `350` sorts by amount descending)
- [x] 6.4 The direct row exists only when the main total minus the sum of children is greater than zero
      (`category_detail_screen.dart:339` `if (directTotal > Decimal.zero)`)
- [x] 6.5 Fractions here are of the category's total, NOT the period total (`design.md`)
      (`category_detail_screen.dart:372-376`, divides by `mainTotal`, not a period total or
      `slices.dart`'s `Slice.fraction`)
- [x] 6.6 Selecting a row sets the scope and rescopes everything below
      (`onSelectScope` wired through `_SubcategoryRow.onTap` to `_setScope`, `category_detail_screen.dart:111`,
      `_scope` feeds total/trend/entry-list all from the same `build`)
- [x] 6.7 Test: the direct-bucket threshold at exactly zero; direct ranking among children; fractions
      relative to the category
      (`app/test/ui/stats/category_detail_screen_test.dart`)

## 7. Trend

- [x] 7.1 Add `trendMonths(detailDate, range, scope)` as a pure function: month range gives the six
      months ending with and including the selected month; year range gives all twelve months of the
      year. Ascending
      (`app/lib/ui/stats/trend.dart:6-20`; EDIT: signature is `trendMonths(detailDate, {isYearRange})`
      — scope does not affect which months are returned, only `monthTotal`'s caller-side item
      filtering does, so scope was dropped from this function's parameters)
- [x] 7.2 Per-month amount is the scope total for that month
      (`trend.dart:22-27` `monthTotal`; caller passes items pre-filtered to the scope's matching set)
- [x] 7.3 Add the trend card: title from the scope's short name, with the range hint on the right
      replaced by the selected point's month and amount while a point is selected
      (`_TrendCard`, `category_detail_screen.dart:506-531`, `_scopeShortName` at line 277)
- [x] 7.4 Add the chart: smoothed line and point markers in the category's color, y-domain from zero to
      at least one, abbreviated month labels
      (`category_detail_screen.dart:537-608`, `maxY` floor at line 504, `isCurved: true` line 599)
- [x] 7.5 Horizontal tap and drag selects the nearest month, marked with a rule and an amount annotation
      (EDIT: no separate vertical-rule widget — `fl_chart`'s own touch line/dot highlighting on the
      selected spot plus the header swap at `508-510` carries the "marked" requirement;
      `touchSpotThreshold: double.infinity` at line 570 makes selection purely horizontal-nearest
      rather than proximity-to-line, since the default threshold missed low-value points)
- [x] 7.6 Test: both ranges, including a January selection crossing the year boundary
      (`app/test/ui/stats/trend_test.dart`)

## 8. Scoped entry list and memoization

- [x] 8.1 Reuse `daySections`, then filter rows by whether the entry's category is in the matching set.
      Drop sections left empty
      (`_ScopedEntryList`, `category_detail_screen.dart:631-636`; filters entries before calling
      `daySections`, so sections with no matching entries never get built rather than being built then
      dropped — same observable result)
- [x] 8.2 Rows keep the transactions list's interactions: tap opens the entry sheet, swipe deletes behind
      the same confirmation
      (`_EntryRow`, `category_detail_screen.dart:673-690`, same `Dismissible`/`showDeleteConfirmation`/
      `showEntryFormSheet` pattern as `daily_transactions_screen.dart`)
- [x] 8.3 Add the memoized scan: cache the kind-and-bucket-filtered items keyed on the analysis cache's
      items revision, applying the window filter per call
      (`app/lib/ui/stats/analysis_scan.dart:7-31`; window filter left to the caller, per file comment)
- [x] 8.4 Test: the memo invalidates when the revision bumps and is reused when it does not — a memo that
      never invalidates would pass every other test in this suite
      (`app/test/ui/stats/analysis_scan_test.dart`, kind/bucket-set changes also force recompute at
      the same revision)

## 9. Close-out

- [x] 9.1 Run `cd app && flutter analyze && flutter test`. Analyzer at zero issues, not just zero errors
      (552/552 green, zero analyzer issues, verified independently at repo root)
- [x] 9.2 Confirm no `double` money reached `app/lib/` — chart coordinates are not money
      (`rg '\bdouble\b' app/lib/ui/stats/` — every hit is a chart angle/radius/threshold, e.g.
      `stats_donut.dart:67,100,101,164`, `category_detail_screen.dart:570`)
- [x] 9.3 Confirm the derivation functions carry no widget imports
      (`slices.dart`, `category_scope.dart`, `trend.dart`, `analysis_scan.dart` — no
      `flutter/material`/`flutter_riverpod` import in any)
- [x] 9.4 Confirm this screen reads the analysis cache and never scans `entries` directly:
      `grep -rn "entries" app/lib/ui/stats/`
      (totals/slices/trend all source from `AnalysisCache.items` via `AnalysisScan`/`slices()` —
      `category_detail_screen.dart:136-164,494`. The two real `state.entries` hits at lines 632/670
      back the scoped ENTRY LIST, which lists `Entry` rows day-sectioned same as the transactions
      screen per the category-detail spec's "Scoped entry list" requirement — a different surface
      from the analysis totals this task guards. `slices.dart:49`'s hit is `Map.entries` iteration
      over rolled-up sums, not `LedgerState.entries`)
