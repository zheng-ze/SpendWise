Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ui_screens.md` §3, which is more detailed than the
specs in this change.

Depends on `add-app-shell-and-boot` and `add-transactions-ui` — the detail screen reuses day sections
and the entry sheet.

## 1. Screen frame

- [ ] 1.1 Add the screen: income/expense tab pair defaulting to Expense, divider, scrollable column of
      total line, donut, divider, category list
- [ ] 1.2 Add the app bar: month/year selector leading, range menu trailing toggling Monthly/Annually,
      with the selector label and window following the range
- [ ] 1.3 Render the full toolbar on EVERY platform — V1 compiled these controls for iOS only, leaving
      macOS unable to change the period (`design.md`)
- [ ] 1.4 Read from the `AnalysisCache` provider: request a refresh on appear, re-render when the
      cache bumps its items revision. Do not scan entries directly
- [ ] 1.5 Add the total line: sum of items of the active kind in the window, labelled per kind and
      colored as gain or loss
- [ ] 1.6 Test: the default kind; range switching changing both label and window; the total over a
      window

## 2. Slices

- [ ] 2.1 Add `slices(items, kind, window, state)` as a pure function: filter by kind and window, roll
      up to main buckets, one slice per bucket, sorted by amount descending
- [ ] 2.2 Each slice carries its fraction of the total; the null bucket is Uncategorized and absorbs
      treat-as-expense transfers
- [ ] 2.3 Slice color from the category, gray for Uncategorized
- [ ] 2.4 Test: ordering; subcategory folding into its parent; Uncategorized bucketing; fraction math
      including the zero-total guard

## 3. Donut

- [ ] 3.1 Add the donut: ring geometry per the module spec, slices from 12 o'clock clockwise in list
      order, 1.5° gap between slices and no gap when there is only one
- [ ] 3.2 Clamp zero and negative values out of the ring
- [ ] 3.3 Add leader-line labels: line from the slice mid-angle to an elbow past the ring, then
      horizontally away from center; label is name plus rounded percent, clamped to stay on canvas
- [ ] 3.4 Use `fl_chart` only if it places leader lines cleanly; otherwise write a custom painter
      rather than compromising the labels (`design.md`). Add `fl_chart` to `app/pubspec.yaml`
- [ ] 3.5 Add the empty state replacing donut and list, naming the active kind, with the total line
      still showing zero
- [ ] 3.6 Golden test the donut, including the single-slice case
- [ ] 3.7 Test: the empty state

## 4. Legend

- [ ] 4.1 Add legend rows in the same descending order: category icon, name with percent caption,
      trailing amount, chevron. Dividers indented past the icon
- [ ] 4.2 Tapping a row pushes the category detail screen for that main category
- [ ] 4.3 The Uncategorized row is NOT navigable — no chevron, no push. It is a bucket, not a category
- [ ] 4.4 Test: tapping Uncategorized pushes nothing

## 5. Category detail — scope and totals

- [ ] 5.1 Add the detail screen taking the main category, kind, range and an initial date
- [ ] 5.2 Give it its own date state seeded from Stats, with the range INHERITED FIXED — selector only,
      no range menu
- [ ] 5.3 Add `matchingCategoryIDs(id, scope)` as a pure function: whole scope matches the main plus its
      children, sub scope matches that id alone, direct scope matches the parent's own id exactly.
      Model the null bucket explicitly rather than as an absent optional (`design.md`)
- [ ] 5.4 Add the scope total with its caption per scope, colored by kind
- [ ] 5.5 Test the `matchingCategoryIDs` matrix across all three scopes plus the null bucket

## 6. Subcategory table

- [ ] 6.1 Add the table, shown only when the category has children
- [ ] 6.2 First row is the whole category: full proportion, combined total. It is view-side and always
      first — a scope control rather than a slice
- [ ] 6.3 Children and the direct row sort TOGETHER by amount descending, so the direct row ranks by its
      own amount rather than being pinned
- [ ] 6.4 The direct row exists only when the main total minus the sum of children is greater than zero
- [ ] 6.5 Fractions here are of the category's total, NOT the period total (`design.md`)
- [ ] 6.6 Selecting a row sets the scope and rescopes everything below
- [ ] 6.7 Test: the direct-bucket threshold at exactly zero; direct ranking among children; fractions
      relative to the category

## 7. Trend

- [ ] 7.1 Add `trendMonths(detailDate, range, scope)` as a pure function: month range gives the six
      months ending with and including the selected month; year range gives all twelve months of the
      year. Ascending
- [ ] 7.2 Per-month amount is the scope total for that month
- [ ] 7.3 Add the trend card: title from the scope's short name, with the range hint on the right
      replaced by the selected point's month and amount while a point is selected
- [ ] 7.4 Add the chart: smoothed line and point markers in the category's color, y-domain from zero to
      at least one, abbreviated month labels
- [ ] 7.5 Horizontal tap and drag selects the nearest month, marked with a rule and an amount annotation
- [ ] 7.6 Test: both ranges, including a January selection crossing the year boundary

## 8. Scoped entry list and memoization

- [ ] 8.1 Reuse `daySections`, then filter rows by whether the entry's category is in the matching set.
      Drop sections left empty
- [ ] 8.2 Rows keep the transactions list's interactions: tap opens the entry sheet, swipe deletes behind
      the same confirmation
- [ ] 8.3 Add the memoized scan: cache the kind-and-bucket-filtered items keyed on the analysis cache's
      items revision, applying the window filter per call
- [ ] 8.4 Test: the memo invalidates when the revision bumps and is reused when it does not — a memo that
      never invalidates would pass every other test in this suite

## 9. Close-out

- [ ] 9.1 Run `cd app && flutter analyze && flutter test`. Analyzer at zero issues, not just zero errors
- [ ] 9.2 Confirm no `double` money reached `app/lib/` — chart coordinates are not money
- [ ] 9.3 Confirm the derivation functions carry no widget imports
- [ ] 9.4 Confirm this screen reads the analysis cache and never scans `entries` directly:
      `grep -rn "entries" app/lib/ui/stats/`
