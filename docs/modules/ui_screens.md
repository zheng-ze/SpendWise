# UI Module — Behavior Spec (Screens + View Models)

**Scope:** everything under `SpendWise-SwiftUI/SpendWise/View/` and `ViewModel/` (Previews excluded),
plus the UI-facing half of `SpendWiseApp.swift` (boot screen, banners). Every behavior below was
verified against that code on 2026-08-08. Reference screenshots:
`../../../SpendWise-SwiftUI/docs/screenshots/{Transactions,Stats,Accounts}.png`.

**Sibling specs (referenced, not restated):**

| Doc | What this spec leans on it for |
|---|---|
| `domain_models.md` | `Entry`, `MoneySource`, `TransactionCategory`, lifecycle machine, mutator/validation contracts, `LedgerError` |
| `plans_and_accounting.md` | `Accounting.*` pure functions (balances, net worth, analysisItems, rollUp, fraction), `RecurringPlan.occurrences/nextOccurrence` |
| `ledger_runtime.md` | `Ledger` public API, `EventBus`, `AnalysisCache` (revision/generation guard), boot phase machine §5, seeding contract §6 |
| `persistence.md` | `SaveBannerState` values and when the store emits them |
| `../Flutter_Port_Tech_Doc.md` (master) | stack decisions (§3), UI port map (§4.4), hazards (§5), phase order (§6) |

**Architecture rule for the port (master doc §4.4 + critique Con 3/4):** every computation listed
under a "Pure functions to extract" heading below moves OUT of widgets into plain Dart functions or
Riverpod providers, with unit tests from the first screen. Widgets render and dispatch; nothing else.

---

## 0. Cross-cutting conventions

### 0.1 State ownership: Swift VM → Riverpod (fixes critique Con 4)

In V1, view models are `@Observable` classes constructed **inline in view bodies**
(`RootView` does `TransactionsView(viewModel: .init(ledger: ledger))`; child VMs are minted by
factory methods like `viewModel.entryFormViewModel()` at presentation time). VM lifetime therefore
hangs off SwiftUI view identity — fragile, untestable, and the reason V1 shipped zero VM tests.

**Flutter mapping — do not copy the lifetime model:**

| Swift VM | Flutter owner |
|---|---|
| `TransactionsViewModel` | `NotifierProvider` (family-keyed by optional source-scope) holding `selectedDate`, `mode`; derived lists are pure functions of `(LedgerState, params)` |
| `TransactionsTableViewModel` | no provider needed — thin call-through; fold into the transactions controller |
| `EntryFormViewModel` | short-lived form controller created per sheet (Riverpod `autoDispose`), seeded with `(defaultDate, prefillSourceID, Entry?)` |
| `StatsViewModel` / `CategoryDetailViewModel` | providers watching the `AnalysisCache` provider (`ledger_runtime.md` §3) |
| `AccountsViewModel` | provider; sections/net-worth are derived pure functions |
| `AccountFormViewModel`, `SourceEditViewModel` | per-sheet `autoDispose` controllers |
| `SettingsViewModel`, `CategorySettingsViewModel`, `PlanSettingsViewModel`, `RecycleBinViewModel` | providers (they are stateless facades over `Ledger` — mostly become plain provider reads) |

Screen state that must survive rebuilds (selected month, active sub-tab, expanded account) lives in
providers, never in widget-local state that a shell rebuild can reset.

### 0.2 Formatting rules (used by every screen)

- **Currency:** V1 formats everything with `.currency(code: "SGD")` → `$3,200.00` (grouping, 2 dp,
  `$` symbol). Single-currency assumption is baked in. Flutter: one shared
  `formatCurrency(Decimal)` via `intl` `NumberFormat.currency(symbol: '\$', decimalDigits: 2)`;
  keep it in one place so a future multi-currency change is one edit.
- **Amount sign display (transaction cells):** magnitude is always shown absolute, then:
  income → `+$X` in blue; expense → `-$X` in red; transfer → `$X` unsigned in gray.
- **Net-amount color rule** (`Color.netAmount`): `> 0` blue, `< 0` red, `== 0` gray. Used for day
  headers, month rows, account balances use a simpler "red if negative else default".
- **`colorHex`:** parse `#RRGGBB` or `RRGGBB`; **malformed input falls back to gray** (test this).
  Writing back (color picker) emits `#RRGGBB` uppercase, components clamped 0–255, alpha dropped.
- **Plain amount editing format** (`AmountFormat.plain`): Decimal rounded to 2 dp, plain rounding,
  no grouping, no symbol — this is what pre-fills text fields.
- **Amount input sanitizer** (`AmountFormat.sanitize`): strips everything except digits and one `.`;
  max 2 fraction digits (extra digits dropped, not rounded); optional single leading `-` only when
  `allowsNegative` (only the balance field in Edit Account/Subpocket allows it). Applied on every
  keystroke. Port as a pure function + `TextInputFormatter`, unit-tested.
- **Dates:** day-section header = big day number + secondary `"Jul 2026 Tue"` (abbrev weekday,
  abbrev month, year — locale-ordered); month/year selector label = `MMM yyyy` or `yyyy`; week
  range = `"6 Jul - 12 Jul"` (interval end is exclusive → subtract one day before formatting);
  plan next-occurrence = `"Next: 14 Jul 2026"`.
- **Percentages:** fraction formatted `.percent`, 0 fraction digits (`64%`). `Accounting.fraction`
  guards the zero-total case (see `plans_and_accounting.md`).
- **Hardcoded `.black` / `.blue` / `.red`:** V1 hardcodes `.black` for "Total" values and label
  colors in `ColumnText` — broken in dark mode. **Do not copy.** Use theme `onSurface` for neutral
  text; keep semantic blue/red/gray for amounts (theme-aware shades).

### 0.3 SF Symbol → Material icon mapping (build task)

`TransactionCategory.symbol` stores SF Symbol names (master doc §5 hazard 4). Two mapping surfaces:

1. **UI chrome symbols** (fixed set, used by widgets directly):
   `text.book.closed`, `chart.pie`, `wallet.bifold`, `gearshape` (tabs); `plus`,
   `square.and.pencil`, `trash`, `arrow.uturn.backward`, `multiply`, `checkmark`,
   `chevron.left/right/down`, `repeat`, `repeat.circle.fill`, `tray`, `banknote`, `tag`,
   `minus.circle.fill`, `plus.circle`, `chart.bar.xaxis`, `arrow.left.arrow.right` (transfer),
   `questionmark.circle` (uncategorized), `smallcircle.filled.circle` (Direct bucket),
   `circle.circle` (fallback). Map each to a fixed Material `IconData` at build time.
2. **Category catalog** (`CategorySymbols`): 9 sections × 10 symbols (Food & Drink, Transport,
   Home & Bills, Shopping, Health, Leisure, Work & Education, Money, Other). Build a
   `Map<String, IconData>` covering all ~90 names **plus a fallback icon** for unknown strings
   (imported/synced data). The symbol picker (§6.3) shows the same catalog with Material icons;
   the stored string stays the SF-Symbol name so data round-trips with the native app.

**Deliverable:** `symbol_map.dart` + a test asserting every `CategorySymbols` name resolves.

### 0.4 Shared components (port once, reuse)

| V1 component | Behavior contract | Flutter primitive |
|---|---|---|
| `TopTabBar` | 2 equal-width text tabs, animated 3 pt underline slides between them, bold when active | `TabBar` or custom row + `AnimatedPositioned` |
| `MonthYearSelector` | `‹ MMM yyyy ›` (or `yyyy` in year mode); chevrons step ±1 month/year; sits in the app bar | custom row widget; state in the screen's provider |
| `ColumnText` | N equal-width columns of caption-over-value (Income/Expenses/Total bars) | `Row` of `Expanded` columns |
| `AmountField` | text field with `$` prefix shown only when non-empty; sanitizer per §0.2; decimal keyboard (`numbersAndPunctuation` when negatives allowed) | `TextField` + formatter |
| `CategoryIcon` | circular chip, icon at 44% of chip size, category color at 15% opacity bg / full-color glyph; selected variant inverts (white glyph on solid color + 2 pt ring) | `Container` + `Icon` |
| `ExpandingFAB` | see §2.4 | custom; `FloatingActionButton` + overlay |
| `TwoColumnPickerSheet` | see §2.6 | modal bottom sheet, two `ListView`s |
| `FormScaffold` | sheet-hosted form: title, Cancel (dismiss, no confirmation), Save (disabled until `canSave`); used by account/category/plan/source-edit forms | sheet + `AppBar` actions |
| `ErrorSection` | red caption section that appears only when a save threw; message pattern `"Could not save …: <error>"` | conditional form row |
| `Color.platformGray6` | subtle gray fill (day headers, expanded pocket rows, trend card bg) | `surfaceContainerHighest`-ish theme token |

---

## 1. Shell — RootView (+ boot chrome)

### 1.1 V1 behavior

- `TabView` with 4 tabs, in order: **Transactions** (`text.book.closed`), **Stats** (`chart.pie`),
  **Accounts** (`wallet.bifold`), **Settings** (`gearshape`).
- Transactions, Stats, Settings are each wrapped in their **own** `NavigationStack`. Accounts owns
  its stack internally (path-based, §4). Tab switches preserve each tab's nav state.
- Above the shell, `AppRootView` (in `SpendWiseApp.swift`) runs the boot phase machine — full
  contract in `ledger_runtime.md` §5. UI obligations only:
  - `loading` → centered spinner.
  - `failed(error)` → **load-failure retry screen**: headline "Couldn't load your data", secondary
    line with the error description, prominent "Retry" button that re-enters `loading` and re-runs
    boot.
  - `ready` → shell, with a **bottom-aligned status banner overlay** (capsule, thin material,
    footnote text) showing, in priority order: plan-error message if set, else save-state message.
    - Save messages (`persistence.md`): `retrying` → "Couldn't save changes, retrying";
      `failedWillRetry` → "Couldn't save changes, will retry shortly"; `clear` → no banner.
    - Plan error: "A recurring plan couldn't add its entry" (1 plan) / "N recurring plans couldn't
      add their entries" (N distinct plan IDs); auto-dismisses after 4 s, timer resets on a new
      failure batch.
- First launch seeds sample data before `load()` (seeding contract + dataset:
  `ledger_runtime.md` §6). **First-run UI is therefore never empty** — Transactions/Stats/Accounts
  all render seeded content; the empty states in this spec are still reachable (delete everything,
  filtered months) and must be built.

### 1.2 Flutter mapping (master doc §4.4)

- Adaptive shell decided up front: `NavigationBar` (4 destinations, same order/labels) on compact
  width; `NavigationRail` on wide (desktop/web/tablet). Each destination keeps its own `Navigator`
  (or go_router `StatefulShellRoute`) so per-tab stacks survive switching.
- Banner overlay: a root-level `Stack` layer driven by two providers (save-banner state from the
  store's error handler; plan-error string with its 4 s auto-dismiss). Don't use transient
  `SnackBar`s for the save banner — it must persist while the state is non-clear.
- Boot: phase provider `loading / ready / failed`; retry re-invokes boot.

---

## 2. Transactions tab

Top-level layout, top to bottom: `TopTabBar` (**Daily | Monthly**) → divider → **income/expense
bar** → divider → content (day list or month breakdown). App bar: title "Transactions" (inline) +
`MonthYearSelector` trailing. `ExpandingFAB` bottom-trailing overlay.

State: `selectedDate` (defaults to now) and `mode` — switching to Daily sets mode `.month`,
Monthly sets `.year`. The selector's chevrons step by the mode's unit. The income/expense bar and
both content views all derive from `interval(mode, selectedDate)`.

**Reused with scope:** the same screen renders account-scoped transactions (§4.4) with a custom
title and `sourceIDs` filter; everything below applies there too.

### 2.1 Income/expense bar

Three columns via `ColumnText`: **Income** (blue), **Expenses** (red), **Total** = income − expenses
(neutral). Values are the sums of the visible day sections' income/expenses (§2.2 rules) over the
current interval — month interval on Daily, whole year on Monthly.

> **Open decision — do not preempt (critique Con 2, master doc §1 defect 2):** these totals apply
> only **entry-level** `includeInAnalysis`. Stats additionally applies category include-gates and
> treat-as-expense transfer reclassification, so Transactions and Stats can disagree for the same
> month. The ruling (route both through `Accounting`'s gates vs. document as intentional Realbyte
> parity) is made once, at the domain level, and recorded in the master doc — this screen just
> calls whatever shared function results. Build it calling the V1-parity function; keep the call
> site singular so the ruling is a one-line swap.

### 2.2 Daily view — day-sectioned list

**`daySections` — pure function to extract** (this exact algorithm, ported from
`TransactionRow.daySections` + `TransactionDaySection`):

1. Take all entries; if a source scope is set, keep only entries **touching** any scoped id
   (source or destination).
2. Resolve each entry to a row (§2.3); filter rows to the date interval (when given).
3. Group by `startOfDay(row.date)`; within a day sort rows by timestamp **descending**; sort days
   **descending** (newest first).
4. Per-section aggregates: `income` = Σ signed amounts of income rows **with
   `includeInAnalysis == true`**; `expenses` = Σ **negated** signed amounts of qualifying expense
   rows (expenses are stored negative → `expenses` is a positive magnitude). Transfers and
   excluded entries count in neither.

Interval containment in the Dart port is **half-open `[start, end)`** everywhere — a flagged
sanctioned deviation from Swift's end-inclusive `DateInterval.contains` (master plan §5 hazard 8;
detail in `plans_and_accounting.md` §5.5).

**Day header row** (gray band): bold day number + secondary `"Jul 2026 Tue"` + trailing **net**
(= income − expenses) colored by the net-amount rule. Headers are pinned section headers in V1's
plain list — keep sticky headers in Flutter (`SliverList` + pinned header or equivalent).

**Empty state:** tray icon + "No transactions" (secondary), centered — shown when the interval
has no sections.

**Interactions:**
- Tap row → entry form sheet, opening **read-only** (§2.5).
- Swipe row leading-to-trailing (trailing edge) → red **Delete** action → confirmation dialog:
  title **"Delete this transaction?"**, message = the entry's note, falling back to its title when
  the note is empty; destructive **Delete** (calls `ledger.deleteEntry`) / **Cancel**.

### 2.3 Row resolution (`TransactionRow` — pure function to extract)

Resolves an entry against `LedgerState` so cells never touch state:

| Field | Non-transfer | Transfer |
|---|---|---|
| title | category name; `"Parent/Child"` when nested; `"Uncategorized"` when no category | `"Transfer"` |
| account line | source name (`"Unknown"` if unresolvable) | `"Source > Destination"` |
| symbol | category symbol, else `questionmark.circle` | `arrow.left.arrow.right` |
| color | category `colorHex` | none → gray chip |
| amount | signed; rendered per §0.2 | positive magnitude, unsigned gray |

`TransactionRow.note` = `Entry.name` (the free text the user typed); `title` derives from the
category. There is **no** `Entry.note` field in V1 (persistence reserves a drift column for it,
unused until V2).

Cell layout: 36 pt `CategoryIcon` chip · title / optional note (caption) / account line (caption,
secondary) · trailing amount (semibold). Golden-test this cell (master doc Phase 5).

### 2.4 ExpandingFAB

- Single action (normal Transactions tab): behaves as a plain FAB — tap fires **Add Transaction**
  (new-entry sheet) directly, no expansion.
- Multiple actions (account-scoped screen adds **"Edit \<account/pocket name\>"** → source edit
  sheet, §4.6): tap toggles expansion — the `+` rotates 45° to an `×`, labelled capsule buttons
  (title + icon) stack above with a spring/slide-fade transition, and an invisible full-screen
  backdrop collapses on outside tap. Choosing an action collapses first, then fires.

### 2.5 Entry form (create / view / edit) — sheet

The single most stateful form. **Read-only-first for existing entries** (this shipped design is a
memory-pinned fact — don't "improve" it into edit-first).

**Modes & chrome:**

| Mode | Title | Leading | Trailing |
|---|---|---|---|
| New | "New Entry" | ✕ Back → dismiss | ✓ Save (disabled until valid) |
| View existing | "Entry" | ‹ Back → dismiss | ✎ Edit → switches to edit mode |
| Edit existing | "Edit Entry" | ✕ Back → **revert fields to persisted values, drop back to view mode** (sheet stays open) | ✓ Save |

All fields are disabled (visually normal, non-interactive) in view mode.

**Fields, in order:**
1. **Kind** — segmented Expense / Income / Transfer. Changing kind **clears the selected
   category** (categories are kind-bound).
2. **Amount** — `AmountField`, no negatives (sign is derived from kind at save).
   **Name** — plain text. **Date** — date-only picker; on the same row, **recurrence button**
   (new entries only): repeat glyph, secondary when off; when a frequency is chosen the glyph
   fills, tints accent, and shows the frequency name as a caption under it. Tapping opens the
   recurrence sheet (§2.7).
3. When new + recurrence set: **End date** toggle; when on, an "Ends" date picker constrained to
   `>= date`.
4. **Source pickers** — row "Account" (or "From" when transfer) showing the selected holder's name
   or "Select"; transfers add a "To" row; non-transfers instead show **Category** row with the
   resolved label ("Parent/Child" for nested, "None" when unset). Each opens its sheet (§2.6).
5. **Include in Analysis** toggle, default on.
6. `ErrorSection` (appears on save failure: `"Could not save entry: <error>"` — the mutation can
   throw validation errors per `domain_models.md` §3.3).
7. Existing entry in edit mode only: full-width destructive **Delete Entry** → deletes and
   dismisses. **No confirmation dialog on this path** (the list-swipe path is the confirmed one) —
   V1 parity; keep as-is.

**Validation (`canSave` — extract as pure function):** amount parses and ≠ 0, name non-empty,
source selected; transfers additionally require destination selected and ≠ source. (Deeper rules —
category-kind match, holder existence — are the domain validator's job and surface via the error
section.)

**Save semantics (controller logic, from `EntryFormViewModel`):**
- Sign is applied from kind: income `+|amount|`, expense `−|amount|`, transfer `+|amount|`
  (with `destinationID` set, `categoryID` nil).
- Edit existing → `updateEntry` (same id), then **stay open** and flip back to read-only mode.
- New without recurrence → `addEntry`, dismiss.
- New **with** recurrence → build `EntryTemplate` from the fields and `addPlan` with
  `anchor = date`, optional `endDate`, and **`lastResolvedDate = date − 1 s`** (so the anchor
  day itself resolves), then immediately call `resolvePlans` — due occurrences (including the
  anchor, if not future-dated) appear in the list at once. Dismiss. See `plans_and_accounting.md`
  for occurrence semantics; keep the "−1 s cursor" contract via a date-only equivalent per master
  doc §5 hazard 3.
- Prefill: on the account-scoped screen, a new entry's source pre-selects the scoped holder.

### 2.6 Picker sheets — TwoColumnPickerSheet + wrappers

**TwoColumnPickerSheet** (shared master/detail picker; medium/large detents):
- Left column: parent rows. Right column: children of the expanded parent (empty pane when none
  expanded).
- Tap parent **with children, not yet expanded** → expands it into the right column (row gets a
  gray "active" background). Tap a **childless parent**, or an already-expanded parent **a second
  time** → selects the parent itself and dismisses.
- Tap child → selects it, dismisses.
- Currently-selected row (either column) gets a blue-tinted background.
- Toolbar: **Cancel** (dismiss, no change) and — only when `allowsNone` — a **None** confirm
  button that clears the selection and dismisses.

**SourcePickerSheet** (title "Account"/"From"/"To"): groups = active accounts (each with its
active pockets as children); plain-text labels. No "None". Selecting the account itself is how
you post to the parent holder; pockets are children.

**CategoryPickerSheet** (title "Category", `allowsNone: true`): groups = parent categories of the
current kind with their children (grouping from `EntryFormViewModel.categoryGroups`, ordering per
`ledger_runtime.md` §1.3 — roots A–Z, children A–Z under each root); labels =
`CategoryIcon` (28 pt parent / 24 pt child) + name. Transfers never show this picker.

### 2.7 RecurrencePickerSheet

Medium-detent sheet, title "Repeat", Cancel toolbar. Fixed rows: **One time** (= nil) then
Weekly, Biweekly, Monthly, Quarterly, Yearly. Selected row shows a trailing checkmark. Tapping any
row sets the binding and dismisses. (Reused by the plan edit form with a non-optional binding —
there "One time" is a no-op, §6.5.)

### 2.8 Monthly view — MonthBreakdownView

**`monthSummaries` — pure function to extract** (with tests; from `TransactionsViewModel`):
- Months of the selected year, **only up to and including the current calendar month** (future
  months are omitted; a fully past year shows all 12; a **future year renders zero month rows** —
  `upperBound = min(yearEnd, currentMonthEnd)` precedes yearStart). Listed **newest first**.
- Per month: income/expenses via the same section-totals rules (§2.2), `isCurrentMonth` flag, and
  its **weeks**: every week-of-year interval overlapping the month, **kept at full week range even
  when spilling into neighboring months** (a spillover week appears under both months, with the
  same full-week totals). Weeks listed newest first. `isCurrentWeek` flag.

**Rendering:**
- Month row: chevron (right/down), wide month name ("July"), bold + light-blue background when
  current month; trailing **net** (income − expenses) — red when negative, else primary.
- Tap month row → expand/collapse its weeks; **only one month expanded at a time**.
- Week row (gray background): 3 pt blue leading bar + highlight when current week; range text
  `"6 Jul - 12 Jul"`; trailing net, same coloring.
- **Tap a week → jumps to Daily view of that week's month** (sets `selectedDate` to the month,
  switches sub-tab to Daily). It does not scroll to the week — month-level jump only.

### 2.9 Provider tests (minimum)

`daySections` grouping/sorting/scoping, section income/expense include-rules, interval totals,
`monthSummaries` year-cutoff + spillover weeks, entry-form `canSave` matrix, save-sign matrix,
plan-creation wiring (anchor/endDate/cursor), kind-change-clears-category.

---

## 3. Stats tab

Layout: `TopTabBar` (**Income | Expense**, default **Expense**) → divider → scrollable column:
total line, donut, divider, category list. App bar: `MonthYearSelector` leading;
trailing **range menu** — a dropdown toggling **Monthly | Annually** (switches `mode` between
month/year; selector label and window follow).

> V1 wrapped that toolbar in `#if os(iOS)` — macOS shipped with **no** date/range controls on
> Stats. That is a platform gap, not a design decision: Flutter renders the full toolbar on every
> platform.

Data source: `AnalysisCache` (`ledger_runtime.md` §3) — the screen calls `refresh()` on appear and
re-renders when the cache revision changes. All amounts here are **post-analysis-gate** items
(category include-gates, treat-as-expense transfers → the Uncategorized bucket), which is exactly
why Stats can differ from Transactions (§2.1 ruling).

### 3.1 Total line

Caption "Total income" / "Total expenses" + 30 pt bold amount, blue for income / red for expense.
Total = Σ analysis items of the active kind within the window.

### 3.2 Donut + slices

**Slices — pure function to extract** (from `StatsViewModel.slices`): filter cache items by kind +
window → `Accounting.rollUp` to main-category buckets (subcategory amounts fold into their
parent; `nil` bucket = **Uncategorized**, which includes treat-as-expense transfers) → one slice
per bucket with `fraction = amount/total`, **sorted by amount descending**. Slice color = category
`colorHex`; Uncategorized = gray.

**Donut geometry** (V1 custom `Canvas`; Flutter: `fl_chart` `PieChart` or a custom painter —
whichever reproduces this):
- Ring: outer radius = 60% of half the shorter side (leaving a label margin), inner radius = 58%
  of ring-outer. Slices start at 12 o'clock, clockwise, in list order (largest first).
- 1.5° gap between slices (no gap when only one slice).
- **Leader-line labels:** from each slice's mid-angle, a line runs outward to an elbow 14 pt past
  the ring, then 12 pt horizontally away from center; label = `Name  NN%` (10 pt semibold; name in
  primary, percent in slice color), anchored just past the line end and clamped to stay on-canvas.
  If `fl_chart` can't do leader lines cleanly, a custom painter is the expected implementation.
- Zero/negative slice values are clamped out of the ring.

**Empty state** (no slices in window): `chart.pie` glyph + "No income in this period" / "No
expense in this period" — replaces donut and list, total line still shows `$0.00`.

### 3.3 Category list (legend)

One row per slice, same descending order: 34 pt `CategoryIcon` · name + percent caption · trailing
amount (semibold, monospaced digits) · chevron. Tap → pushes **Category Detail** for that main
category. The **Uncategorized row is not navigable** (no chevron, no push). Dividers indented past
the icon.

### 3.4 Category Detail screen (drill-down)

Pushed with `(mainID, kind, mode, initialDate)`. Has its **own date state** (`detailDate`, seeded
from Stats' date) but **inherits mode fixed** — the toolbar has the `MonthYearSelector` only, no
range menu. Title = main category name.

Layout = one `TransactionsTableView` whose header stack contains: **scope total** → **subcategory
table** (only when the category has children) → **trend card** → "ENTRIES" caption; then the
day-sectioned entry list (full §2.2/§2.3 behavior: tap-to-view sheet, swipe-delete with the same
confirmation).

**Scope selection state:** `all` (default) | `sub(id)` | `direct` —
- Caption over the total: `"Food"` / `"Food › Hawker"` / `"Food › Direct"`; amount colored
  blue/red by kind.
- **Subcategory table rows:** first **"All \<Main\>"** row (main symbol/color, fraction 100%,
  amount = main+children total; view-side, always first); then the child slices **and the
  "Direct" slice sorted together** by amount descending — the **"Direct"** row (id nil,
  `smallcircle.filled.circle`, parent's color) lands wherever its amount ranks, and exists
  **only when** main-total − Σ children > 0 — entries logged on the parent itself. Selected row: blue-tint background + bold name. Tapping a
  row sets scope; everything below rescopes.
- **Fractions in this table are of the main-category total** (not the tab total).

**Trend card** (gray rounded card):
- Title `"<scope short name> trend"`; right side shows either the hint ("last 6 months" in month
  mode, "this year" in year mode) or, while a point is selected, that point's `MMM yyyy` + amount.
- **Trend windows — pure function to extract** (`trendMonths`): month mode = the 6 months ending
  at (and including) `detailDate`'s month, ascending; year mode = all 12 months of `detailDate`'s
  year. Per-month amount = scope total for that month (all → main+children; sub → that id;
  direct → parent-id-only bucket).
- Chart: smoothed line + point markers in the main category's color; y-domain `0…max(points, 1)`;
  x-axis labelled with abbreviated month names. Horizontal tap/drag selects the **nearest** month;
  a vertical rule + capsule amount annotation marks it. (fl_chart `LineChart` + touch callbacks.)

**Scoping/lookup logic worth porting exactly** (from `CategoryDetailViewModel`):
- `matchingCategoryIDs(id, isMain)`: main scope → `{main} ∪ children`; sub scope → `{id}`;
  no category → `{null}`. Drives both totals and entry filtering. Note the Swift set is
  `Set<UUID?>` — in Dart model the null-bucket case explicitly (master doc §4.1's sealed-result
  advice applies).
- Entry lists reuse `daySections` then filter rows by the entry's `categoryID` ∈ matching set
  (direct scope: `categoryID == mainID` exactly), dropping now-empty sections.
- **Memoization to keep:** the detail VM caches its kind+bucket-filtered item scan keyed on the
  cache's `itemsRevision`, applying the interval filter per call. In Flutter this is a provider
  that recomputes only when `AnalysisCache` bumps its revision — same guard, idiomatic form.
  (Per-render scan memoization beyond this is explicitly deferred — master doc §7.)

### 3.5 Provider tests (minimum)

rollUp slice ordering + Uncategorized bucketing, fraction math incl. zero total, subSlices
direct-bucket threshold (`> 0`), trendMonths both modes (year boundary, Jan), matchingCategoryIDs
matrix, revision-keyed memoization invalidates on bump.

---

## 4. Accounts tab

Owns its own navigation stack. Root screen, top to bottom: **custom header row** (V1 hides the nav
bar on iOS: left-aligned "Accounts" headline + trailing `+` button opening the account form) →
**summary bar** → divider → grouped account list.

### 4.1 Summary bar

`ColumnText`: **Assets** (blue) / **Liabilities** (red) / **Total** = assets − liabilities.
Straight from `Accounting.netWorth` (`plans_and_accounting.md` — asset/liability split,
`includeInNetWorth`, archived-pocket exclusion all live there).

### 4.2 Sections — AccountsViewModel math (pure functions to extract)

- Group **active** accounts by `AccountType`; render sections in the fixed enum order
  **Cash, Checking, Savings, Cards, Prepaid, Investment, Insurance, Other**, skipping empty types.
- Per account row:
  - `display`: card accounts → `card(payable, outstanding)` (§4.3); all others →
    `total(accountTotal)` where `accountTotal` = own balance + active pockets' balances
    (via `Accounting.accountTotal`).
  - `ownBalance` = balance excluding pockets (for the expansion row).
  - pocket sub-rows with individual balances.
- Section header: type name + subtotal. Non-card: Σ row totals, red when negative. **Cards:
  two labelled columns** — "Payable" (red) and "Outstanding" (secondary), each Σ over the card
  rows. (The mixed `subtotal` reduce in V1 subtracts payables for card rows, but card sections
  never render it — port only what renders.)

### 4.3 Card math — payable, outstanding, statement cut

- **Payable** = `max(0, −accountTotal)` — what you owe overall; a card in credit shows 0.
- **Outstanding** = Σ of **negated** amounts of entries where: source is the card account itself
  (pockets excluded — cards can't have pockets anyway), not a transfer, amount < 0, and
  `statementCut ≤ date ≤ now`. I.e. spend since the last statement; transfers (repayments) never
  reduce it, they reduce payable via the balance.
- **Statement cut**: with statement day `d`, anchor month = current month if `today.day ≥ d`,
  else previous month; cut = that month's day `d`.
  - **Known V1 bug — spec the fix (master doc §1 defect 3, §5 hazard 1):** V1 builds this with
    naive date components, which overflows into the next month for `d` = 29–31 on short months.
    The V1 form limits `d` to 1–28 so the UI can't create the bad case, but imported/synced data
    can. **Flutter implementation MUST use the shared `addMonthsClamped`/date-clamp helper:**
    `cutDate = DateTime(y, m, min(d, daysInMonth(y, m)))`. Dart's `DateTime` rolls over silently,
    so an unclamped port is wrong by construction. Test the 28/29/30/31 × {Feb, Feb-leap, 30-day,
    31-day} matrix.
- `outstanding`/`statementCut` are **pure functions with injected `now`** — V1 buried `Date()`
  inside the VM; the port takes `now` as a parameter (testability).

### 4.4 Rows and navigation

- **Account row:** expansion chevron (own hit target, only when the account has pockets) · name ·
  amount display (total, red-if-negative; or the card two-column). Tapping the **row body**
  (not the chevron) pushes the **account transactions screen**: the Transactions screen (§2) with
  title = account name and scope = account id + all its pocket ids.
- **Expanded** (one account at a time), gray-background sub-rows:
  - **"Excluding subpockets"** → pushes scope `[account.id]` only (titled with the account name),
    showing `ownBalance`.
  - One row per pocket → pushes `[pocket.id]`, titled with the pocket name, showing its balance.
- **Swipe-delete** on account rows and pocket rows → dialog **"Delete \<name\>?"** with
  destructive Delete / Cancel. Delete = archive to recycle bin (`domain_models.md` §3.6);
  deleting the expanded account collapses it.
  - V1 computes the referencing-entry count for the dialog but **never displays it** (the alert
    has no message). Flutter: include the count in the dialog body ("N transactions keep this
    name") — cheap fix, matches the recycle-bin copy; note it as a deliberate V1 deviation.

### 4.5 Account form (sheet, `FormScaffold` "New Account"/"New Subpocket")

- **Kind** segmented: Account | Subpocket. Disabled (stuck on Account) when no pocketable
  accounts exist. Pocketable = active, non-card accounts, sorted by name — **cards cannot hold
  pockets** (guarded in both UI and controller).
- Account mode: Name · Type picker (8 types) · **Statement day picker (1–28) shown only for
  Cards** · optional **Opening balance** amount field.
- Subpocket mode: Name · parent Account picker ("Select" placeholder).
- `canSave`: trimmed name non-empty; subpocket also needs a parent.
- Save: `addAccount` (statement day only persisted for cards), then if opening balance ≠ 0,
  `setOpeningBalance` — which posts the synthetic excluded opening-balance entry
  (`domain_models.md`). Subpocket: `addPocket`. Errors → `ErrorSection` "Could not save: …".

### 4.6 Source edit form (sheet — reached only via the scoped-transactions FAB "Edit \<name\>")

Titles "Edit Account" / "Edit Subpocket".
- Name (both). Accounts only: Type picker + statement-day picker (cards).
- **Balance** section: amount field **allowing negatives**, pre-filled with the current derived
  balance. **Editing it does not rewrite history:** on save, if `target − currentBalance ≠ 0`, the
  controller posts a **"Balance adjustment"** entry for the delta with
  `includeInAnalysis: false` — the running balance stays replay-consistent. Spec-critical; port
  exactly (and test: no delta → no entry).
- Toggles: **"Transfers in count as expenses"** (both; footer: "When on, money transferred into
  this holder is treated as spending in analysis." — the treat-as-expense flag,
  `plans_and_accounting.md`); **"Include in net worth"** (accounts only).
- `canSave`: name non-empty and balance parses (empty string counts as 0).
- Save: `updateAccount`/`updatePocket` then the balance adjustment; dismiss; errors inline.

### 4.7 Provider tests (minimum)

Section grouping/order/skip-empty, card payable clamp at 0, outstanding filter matrix (transfer /
positive / pocket-sourced / out-of-window entries excluded), statement-cut anchor month both sides
of `d` + the clamp matrix, balance-adjustment delta logic, pocketable-accounts filter.

---

## 5. Settings tab

Root: a grouped form of navigation links — **Categories** (`tag`), **Recurring Plans** (`repeat`);
second group: **Recycle Bin** (`trash`). Title "Settings".

### 5.1 Category list

- Two sections: **Income**, then **Expense**. Rows come pre-ordered from `categories(of:)`
  (`ledger_runtime.md` §1.3): roots A–Z, each followed by its children A–Z. Child rows are
  indented. Per-section empty text: "No categories yet".
- Row: [edit-mode minus button] · indent for children · 30 pt `CategoryIcon` · name · trailing
  `chart.bar.xaxis` glyph **when the category is excluded from analysis** · on **parent rows**
  (outside edit mode) a `plus.circle` button that opens the form as **"New Subcategory"** with
  parent preset (inherits kind + parent's color).
- Toolbar: **Edit/Done** toggle (shows the red minus-circle delete buttons) + **add** button
  (opens "New Category", default kind expense).
- Tap row → edit sheet. Delete (minus button or trailing swipe) → dialog **"Delete \<name\>?"**
  with message **"N transaction(s) will become Uncategorized."** when referencing entries exist
  (singular/plural handled), else **"This category will be removed."** Destructive Delete →
  archive to bin.

### 5.2 Category form (sheet via `FormScaffold`; titles "New Category" / "New Subcategory" / "Edit Category")

- Name · **Kind** segmented Income|Expense — **locked** when the parent is preset, or when
  editing a category that any entry references (caption: "Type is locked while transactions use
  this category."). Changing kind clears a now-mismatched parent selection.
- **Icon** section: "Symbol" row showing the current `CategoryIcon` → **pushes the symbol picker**
  (§5.3).
- **Color** picker (no opacity) · **Include in analysis** toggle · **Parent** picker (None +
  root categories of the same kind, excluding self) — hidden when parent preset or no options.
  One nesting level is enforced by the domain (`domain_models.md`).
- Defaults (new): symbol `tag`, color blue (or parent's color), include on.
- `canSave`: trimmed name non-empty. Save → add/update (color persisted as `#RRGGBB`); errors
  inline "Could not save category: …".
- Editing only: **Delete Category** button (red, full width) → archive + dismiss, no confirmation
  (the list path is the confirmed one — V1 parity).

### 5.3 Symbol picker (pushed screen "Choose Icon")

Searchable sectioned grid (6 columns) of the `CategorySymbols` catalog (§0.3), rendered as
`CategoryIcon`s in the form's current color; the currently-selected symbol shows the inverted
"selected" chip. Search filters symbol names by substring (case-insensitive, trimmed); sections
with no matches drop out; sticky section headers. Tap → writes selection and pops.

### 5.4 Plan list ("Recurring Plans")

- Rows sorted by **next occurrence ascending; ended plans (nil next) last**. The name tiebreak
  exists **only** between two ended plans; equal non-nil next dates are unspecified order in V1 —
  pick name as the deterministic tiebreak there too (flagged strengthening). `nextOccurrence`
  comes from the domain (`plans_and_accounting.md`).
- Row: name · caption "\<Frequency\> · \<source name\>" · tertiary caption "Next: 14 Jul 2026"
  or **"Ended"** · trailing `|amount|` currency — **green when the template amount is income
  (≥ 0), primary when expense**.
- Toolbar Edit/Done (minus-circle buttons) — only shown when the list is non-empty. Empty text:
  "No recurring plans yet". There is **no add button here** — plans are created from the entry
  form's recurrence flow (§2.5) only.
- Tap → edit sheet. Delete (minus/swipe) → dialog **"Delete \<name\>?"** message **"Already
  generated transactions are kept."** → `deletePlan`.

### 5.5 Plan form (sheet, "Edit Plan")

- Name · Amount (magnitude; **the template's original sign is preserved on save** — an expense
  plan stays an expense) · read-only line "Source: \<name\>" (source is not editable).
- **Repeat** row → `RecurrencePickerSheet` with a non-optional binding (choosing "One time" is
  ignored — a plan can't become one-shot; V1 parity, acceptable to keep) · **First date**
  (anchor) picker · **End date** toggle + picker (no lower-bound constraint here, unlike the
  entry form — domain handles nonsense ranges by generating nothing).
- `canSave`: amount ≠ 0, name non-empty. Save → `updatePlan`, dismiss; errors inline. Editing the
  anchor/frequency does not retro-generate or delete existing entries (cursor semantics:
  `plans_and_accounting.md`).

### 5.6 Recycle bin

Lists archived items in three sections, each hidden when empty — **Accounts** (`banknote` glyph),
**Subpockets** (`tray`), **Categories** (their own colored `CategoryIcon`). Whole-screen empty
text: "Recycle bin is empty".

- Each row: glyph/icon · name (pockets show their qualified display name — `"Parent/Pocket"` when
  the parent still resolves) · trailing badge **"N references"** (count of entries touching the
  holder / referencing the category). Rows within each section sort by **name ascending**.
- **Leading swipe → Restore** (blue, `arrow.uturn.backward`) → domain restore (`domain_models.md`
  §3.7). Restore on a pocket whose parent account is still binned is a **silent no-op** (domain
  rule — restore the account first); port that faithfully. If the dead swipe is judged worth
  fixing, that is a flagged Phase-6 UX change (disable the action or restore-parent-with-
  confirmation), not a port default.
- **Trailing swipe → Delete** (red) → **purge confirmation**: title **"Delete permanently?"**,
  message: *"\<name\> leaves the bin for good. Existing transactions keep the name but it can no
  longer be restored."* — destructive Delete → purge (referenceOnly vs tombstone semantics are
  the domain's, §3.8). **Note:** V1's string interpolation swallowed the space after "good."
  (renders "good.Existing"); the fixed copy above is the spec.
- Purge routing: the controller inspects the id — money source → purgeAccount/purgePocket,
  category → purgeCategory.

### 5.7 Provider tests (minimum)

Category list ordering + kind-lock predicate, delete-copy pluralization, plan-row sort matrix
(nil-next last), plan save sign preservation, bin section membership + reference counts, purge
routing.

---

## 6. Known V1 defects & decisions — DO NOT COPY

| # | V1 behavior | Port ruling |
|---|---|---|
| Con 4 | VMs constructed in view bodies; state lifetime tied to view identity; zero VM tests | Riverpod providers own state (§0.1); controller tests per screen from day one |
| Con 3 | `daySections`, month/week math, `TransactionRow` resolution live in `View/` | Pure functions in application layer (§2.2, §2.3, §2.8) with unit tests |
| Con 2 | Transactions totals ignore category gates; Stats applies them → divergent numbers | **Open decision, decided at domain level** — Transactions screen must call the shared function and not preempt the ruling (§2.1) |
| Defect 3 | `statementCut` naive date math (29–31 overflow; Dart rolls over even worse) | Clamped month math mandatory (§4.3), test matrix |
| Con 10 | No accessibility, no localization | Phase 6 work: `Semantics` on custom widgets (donut needs a text alternative — it's `accessibilityHidden` in V1 with no fallback; FAB, two-column picker, swipe actions need labels/custom actions) + `intl` scaffolding with all §0.2 formats routed through it. Not optional polish; budgeted phases (master doc §6) |
| — | Hardcoded `.black`/light-only colors in `ColumnText`/bars | Theme tokens (§0.2) |
| — | Stats toolbar iOS-only → macOS had no range controls | Full toolbar on all platforms (§3) |
| — | Accounts delete dialog fetches but never shows the entry count | Show it (§4.4) |
| — | Recycle-bin purge copy missing a space | Fixed copy is spec (§5.6) |
| — | Treat-as-expense transfers land in "Uncategorized" | Keep V1 behavior during the port; account-type bucketing is a Phase 6 feature (master doc §1 defect 7) — Stats must not invent it early |

---

## 7. Build checklist (master doc Phase 5 order: shell → Transactions → Accounts → Stats → Settings → boot/banners)

Prereq: Phases 1–4 green (no UI before the domain suite passes — master doc §6 sequencing rule).

1. **Shell**
   - [ ] Symbol map (`symbol_map.dart`) + resolution test (§0.3)
   - [ ] Theme tokens: amount blue/red/gray, gray6 surface, dark mode from day one (§0.2)
   - [ ] Shared components: CategoryIcon, ColumnText, AmountField (+sanitizer tests), TopTabBar, MonthYearSelector, FormScaffold/ErrorSection (§0.4)
   - [ ] NavigationBar/NavigationRail shell, 4 destinations, per-tab navigators (§1.2)
2. **Transactions**
   - [ ] Pure fns + tests: `TransactionRow.resolve`, `daySections`, interval totals (§2.2–2.3, §2.9)
   - [ ] Screen provider (selectedDate/mode/scope); daily list w/ sticky day headers, empty state, swipe-delete dialog
   - [ ] Golden: transaction cell
   - [ ] TwoColumnPickerSheet + Source/Category wrappers (§2.6); RecurrencePickerSheet (§2.7)
   - [ ] Entry form: read-only-first, validation, save/sign/plan-creation matrix + controller tests (§2.5)
   - [ ] ExpandingFAB (§2.4)
   - [ ] Monthly breakdown: `monthSummaries` + tests, expand/collapse, week-jump (§2.8)
3. **Accounts**
   - [ ] Pure fns + tests: sections, accountTotal wiring, payable/outstanding, clamped statementCut (§4.2–4.3)
   - [ ] Root screen: header, net-worth bar, grouped list, expansion rows, card columns; golden: account row
   - [ ] Navigation to scoped Transactions (reusing screen §2 with scope) (§4.4)
   - [ ] Account form; source edit form incl. balance-adjustment entry + tests (§4.5–4.6)
   - [ ] Delete dialogs (with reference counts)
4. **Stats**
   - [ ] Pure fns + tests: slices/rollUp wiring, subSlices+Direct, trendMonths, matchingCategoryIDs (§3.2, §3.4–3.5)
   - [ ] Stats screen: tabs, total, donut (fl_chart/painter w/ leader labels), legend list, empty state; golden: donut
   - [ ] Range menu on ALL platforms (§3)
   - [ ] Category detail: scope selection, trend card w/ point selection, scoped entry list, revision-keyed memoization (§3.4)
5. **Settings**
   - [ ] Category list + form + symbol picker (§5.1–5.3)
   - [ ] Plan list + form (§5.4–5.5)
   - [ ] Recycle bin: restore/purge with fixed copy (§5.6)
6. **Boot / banners / seed**
   - [ ] Boot phase provider: loading spinner, load-failure retry screen (§1.1)
   - [ ] Save banner + plan-error banner (4 s auto-dismiss, plan-error priority) (§1.1)
   - [ ] First-launch seeding wired (`ledger_runtime.md` §6) — verify seeded first-run renders on all four tabs
   - [ ] App lifecycle: resume → resolvePlans, pause → flush (`ledger_runtime.md` §5.3)

Exit: provider tests per screen green, goldens for cell/row/donut committed, and every "do not
copy" row in §6 either fixed or (Con 2, treat-as-expense) explicitly left on V1 behavior with the
decision recorded in the master doc.
