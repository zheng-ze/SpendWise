# Design — stats screen and category drill-down

## Layout

`app/lib/ui/stats/` keeps the derivations — slices, sub-slices, trend windows, scope matching — as
pure functions of cached items and parameters. Widgets call them. This screen has more derived state
than any other, and V1 computed all of it inside view models built in view bodies, which is why none
of it was tested.

## Decisions

### The toolbar ships on every platform — a V1 platform gap, not a design choice

V1 wrapped the date and range controls in a compile-time iOS check, so the macOS build had no way to
change the period on this screen at all. That is a gap rather than a decision; the port renders the
full toolbar everywhere.

### Stats disagrees with Transactions, and that is the open question

Amounts here are post-gate: category exclusions apply and transfers into treat-as-expense holders are
reclassified as spending. The transactions screen applies only entry-level exclusion. The two can
therefore report different numbers for the same month.

That divergence is a known open decision at the domain level, recorded against `add-transactions-ui`.
This change does not resolve it and does not work around it — it reads the analysis cache, which is
the correct source for a screen about analysis.

### The uncategorized bucket is a bucket, not a category

It has no id, so it has nothing to drill into — its row is not navigable. It also absorbs
treat-as-expense transfers, which genuinely have no category. Modelling the null bucket explicitly,
rather than as an absent optional, is what keeps "uncategorized" distinct from "no constraint" in the
scoping code; the domain made the same call for category resolution.

### The direct row exists conditionally and sorts by amount

A "direct" row represents spending logged on the parent itself rather than a child. It exists only
when the parent's total exceeds the sum of its children — otherwise it would render as a zero row.

It sorts among the children by amount rather than being pinned first or last, because it is one more
way the money was spent and ranking it separately would misrepresent proportion.

The leading "all" row is view-side and always first; it is a scope control, not a slice.

### Fractions in the subcategory table are of the category, not the period

Inside a category, a child holding half the category's spend should read 50%, regardless of what
fraction the category is of the month. Using period-relative fractions here would make the table's
percentages sum to something arbitrary.

### Memoization is keyed on the cache's revision

The detail screen caches its kind-and-bucket-filtered scan against the analysis cache's items
revision, and applies the period filter per call. Changing period is cheap; new data invalidates.

This is the same guard the cache itself uses, in provider form. Anything further — per-render scan
memoization — is explicitly deferred by the master doc at personal data scale.

### Donut rendering may need a custom painter

Leader-line labels with elbows, clamped to the canvas, are the part a charting library is most likely
to refuse. `fl_chart` draws the trend line comfortably; if it cannot place leader lines cleanly, the
donut becomes a custom painter rather than a compromise on the labels.

## Test approach

The derivations carry the weight: slice ordering and uncategorized bucketing, fraction math including
the zero-total guard, the direct-bucket threshold at exactly zero, the trend windows in both ranges
including the January case that crosses a year boundary, and the scope-matching matrix across all
three scopes plus the null bucket.

The memoization needs a test that it invalidates when the cache bumps its revision and reuses when it
does not — a memo that never invalidates passes every other test in the suite.

The donut gets a golden test, since geometry and label placement regress silently.
