# UI Module — Behavior Spec (Screens + View Models)

**Scope:** everything under `app/lib/ui/` (screens, view models, and boot/banner UI). This doc is
the current behavior spec for the Dart implementation.

**Sibling specs (referenced, not restated):**

| Doc | What this spec leans on it for |
|---|---|
| `domain_models.md` | `Entry`, `MoneySource`, `TransactionCategory`, lifecycle machine, mutator/validation contracts, `LedgerError` |
| `plans_and_accounting.md` | `Accounting.*` pure functions (balances, net worth, analysisItems, rollUp, fraction), `RecurringPlan.occurrences/nextOccurrence` |
| `ledger_runtime.md` | `Ledger` public API, `EventBus`, `AnalysisCache` (revision/generation guard), boot phase machine §5, seeding contract §6 |
| `persistence.md` | `SaveBannerState` values and when the store emits them |
| `../ARCHITECTURE.md` | stack decisions (§3), UI architecture (§4.4), domain and implementation rules (§5) |

**Architecture rule:** every computation listed under a "Pure functions to extract" heading below
lives OUT of widgets, in plain Dart functions or Riverpod providers, with unit tests from the first
screen. Widgets render and dispatch; nothing else.

---

## 0. Cross-cutting conventions

### 0.1 State ownership

Screen state lives in Riverpod providers, never in widget-local state that a shell rebuild can
reset. State that must survive rebuilds — selected month, active sub-tab, expanded account, an
in-progress form — is owned by a provider or controller, not by a widget's own field.

**Provider ownership by screen:**

| Provider / controller | Owns |
|---|---|
| Transactions `NotifierProvider` (family-keyed by optional source-scope) | `selectedDate`, `mode`; derived lists are pure functions of `(LedgerState, params)` |
| Transactions controller | table/row call-through logic, folded into the same controller rather than split into a separate provider |
| `EntryFormController` | short-lived form controller created per sheet (Riverpod `autoDispose`), seeded with `(defaultDate, prefillSourceID, Entry?)` |
| Stats / Category Detail providers | watch the `AnalysisCache` provider (`ledger_runtime.md` §3) |
| Accounts provider | sections and net-worth, as derived pure functions |
| Account form / source edit controllers | per-sheet `autoDispose` controllers |
| Settings / category-settings / plan-settings / recycle-bin providers | stateless facades over `Ledger` — mostly plain provider reads |

### 0.2 Formatting rules (used by every screen)

- **Currency:** one shared `formatCurrency(Decimal)` helper, via `intl`
  `NumberFormat.currency(symbol: '\$', decimalDigits: 2)`, renders every amount as `$3,200.00`
  (grouping, 2 dp, `$` symbol). The single-currency assumption is deliberate (`../ARCHITECTURE.md`
  §3); keeping the format in one helper means a future multi-currency change is one edit.
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
  keystroke as a pure function plus a `TextInputFormatter`, unit-tested.
- **Dates:** day-section header = big day number + secondary `"Jul 2026 Tue"` (abbrev weekday,
  abbrev month, year — locale-ordered); month/year selector label = `MMM yyyy` or `yyyy`; week
  range = `"6 Jul - 12 Jul"` (interval end is exclusive → subtract one day before formatting);
  plan next-occurrence = `"Next: 14 Jul 2026"`.
- **Percentages:** fraction formatted `.percent`, 0 fraction digits (`64%`). `Accounting.fraction`
  guards the zero-total case (see `plans_and_accounting.md`).
- **Neutral vs. semantic color:** "Total" values and other label text use theme `onSurface`, so they
  adapt correctly in dark mode; semantic blue/red/gray for amounts use theme-aware shades of the
  same three colors, never a fixed hex.

### 0.3 Symbol-name to Material icon mapping (build task)

`TransactionCategory.symbol` stores an icon name as a string, looked up in a mapping table to a
Flutter `IconData` (`../ARCHITECTURE.md` §5 rule 4). Two mapping surfaces:

1. **UI chrome symbols** (fixed set, used by widgets directly): symbols for the four tabs (book,
   pie chart, wallet, gear), for add/edit/delete/undo/dismiss/confirm actions, for navigation
   chevrons, for recurrence and category glyphs (repeat, tray, banknote, tag, plus/minus circle,
   bar chart, transfer arrows), for the uncategorized bucket (question mark), for the Direct bucket
   (filled small circle), and a generic fallback circle. Map each name to a fixed Material
   `IconData` at build time.
2. **Category catalog** (`CategorySymbols`): 9 sections × 10 symbols (Food & Drink, Transport,
   Home & Bills, Shopping, Health, Leisure, Work & Education, Money, Other). Build a
   `Map<String, IconData>` covering all ~90 names **plus a fallback icon** for unknown strings
   (imported/synced data). The symbol picker (§5.3) shows the same catalog with Material icons.

**Deliverable:** `symbol_map.dart` + a test asserting every `CategorySymbols` name resolves.

### 0.4 Shared components

| Component | Behavior contract | Flutter primitive |
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

- Adaptive shell with 4 destinations, in order: **Transactions**, **Stats**, **Accounts**,
  **Settings**. `NavigationBar` on compact width, `NavigationRail` on wide (desktop/web/tablet).
  Each destination keeps its own `Navigator` (or go_router `StatefulShellRoute`) so per-tab stacks
  survive switching — Accounts additionally owns its stack internally (path-based, §4).
- Above the shell, a boot phase provider tracks `loading` / `ready` / `failed` — full contract in
  `ledger_runtime.md` §5. UI obligations:
  - `loading` → centered spinner.
  - `failed(error)` → **load-failure retry screen**: headline "Couldn't load your data", secondary
    line with the error description, prominent "Retry" button that re-invokes boot and re-enters
    `loading`.
  - `ready` → shell, with a **bottom-aligned status banner overlay** — a root-level `Stack` layer
    driven by two providers (save-banner state from the store's error handler; plan-error string
    with its own auto-dismiss timer), rendered as a capsule with thin material and footnote text,
    showing in priority order: plan-error message if set, else save-state message. Don't use
    transient `SnackBar`s for this banner — it must persist while the state is non-clear.
    - Save messages (`persistence.md`): `retrying` → "Couldn't save changes, retrying";
      `failedWillRetry` → "Couldn't save changes, will retry shortly"; `clear` → no banner.
    - Plan error: "A recurring plan couldn't add its entry" (1 plan) / "N recurring plans couldn't
      add their entries" (N distinct plan IDs); auto-dismisses after 4 s, timer resets on a new
      failure batch.
- First launch seeds sample data before `load()` (seeding contract + dataset:
  `ledger_runtime.md` §6). **First-run UI is therefore never empty** — Transactions/Stats/Accounts
  all render seeded content; the empty states in this spec are still reachable (delete everything,
  filtered months) and must be built.

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

> **Ruled divergence (ADR-0026):** these totals apply only **entry-level** `includeInAnalysis`.
> Stats additionally applies category include-gates and treat-as-expense transfer reclassification,
> so Transactions and Stats can show different numbers for the same month — this is intentional,
> not a bug. This screen calls a single shared function for its totals, so a future decision to
> unify the two calculations stays a one-line swap rather than a hunt through widgets.

### 2.2 Daily view — day-sectioned list

**`daySections` — pure function to extract:**

1. Take all entries; if a source scope is set, keep only entries **touching** any scoped id
   (source or destination).
2. Resolve each entry to a row (§2.3); filter rows to the date interval (when given).
3. Group by `startOfDay(row.date)`; within a day sort rows by timestamp **descending**; sort days
   **descending** (newest first).
4. Per-section aggregates: `income` = Σ signed amounts of income rows **with
   `includeInAnalysis == true`**; `expenses` = Σ **negated** signed amounts of qualifying expense
   rows (expenses are stored negative → `expenses` is a positive magnitude). Transfers and
   excluded entries count in neither.

Interval containment is **half-open `[start, end)`** everywhere (`../ARCHITECTURE.md` §5 rule 8;
ADR-0008; detail in `plans_and_accounting.md` §5.5), so an entry timestamped exactly on a day
boundary belongs to exactly one day section, never zero or two.

**Day header row** (gray band): bold day number + secondary `"Jul 2026 Tue"` + trailing **net**
(= income − expenses) colored by the net-amount rule. Headers are sticky (`SliverList` + pinned
header or equivalent).

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
category. `Entry` itself has no `note` field — persistence reserves a schema column for it
(`../ARCHITECTURE.md` §4.3), unused until a future feature needs it.

Cell layout: 36 pt `CategoryIcon` chip · title / optional note (caption) / account line (caption,
secondary) · trailing amount (semibold). Golden-test this cell.

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
   dismisses. **No confirmation dialog on this path** — the list-swipe path (§2.2) is the
   confirmed one.

**Validation (`canSave` — extract as pure function):** amount parses and ≠ 0, name non-empty,
source selected; transfers additionally require destination selected and ≠ source. (Deeper rules —
category-kind match, holder existence — are the domain validator's job and surface via the error
section.)

**Save semantics (controller logic):**
- Sign is applied from kind: income `+|amount|`, expense `−|amount|`, transfer `+|amount|`
  (with `destinationID` set, `categoryID` nil).
- Edit existing → `updateEntry` (same id), then **stay open** and flip back to read-only mode.
- New without recurrence → `addEntry`, dismiss.
- New **with** recurrence → build `EntryTemplate` from the fields and `addPlan` with
  `anchor = date`, optional `endDate`, and **`lastResolvedDate = date − 1 s`** (so the anchor
  day itself resolves), then immediately call `resolvePlans` — due occurrences (including the
  anchor, if not future-dated) appear in the list at once. Dismiss. See `plans_and_accounting.md`
  for occurrence semantics and `../ARCHITECTURE.md` §4.3 for the cursor convention.
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
month/year; selector label and window follow). This toolbar, date selector included, renders on
every platform — desktop and web get the same range controls as mobile.

Data source: `AnalysisCache` (`ledger_runtime.md` §3) — the screen calls `refresh()` on appear and
re-renders when the cache revision changes. All amounts here are **post-analysis-gate** items
(category include-gates, treat-as-expense transfers → the Uncategorized bucket), which is exactly
why Stats can differ from Transactions (§2.1 ruling).

### 3.1 Total line

Caption "Total income" / "Total expenses" + 30 pt bold amount, blue for income / red for expense.
Total = Σ analysis items of the active kind within the window.

### 3.2 Donut + slices

**Slices — pure function to extract:** filter cache items by kind + window → `Accounting.rollUp`
to main-category buckets (subcategory amounts fold into their parent; `nil` bucket =
**Uncategorized**, which includes treat-as-expense transfers) → one slice per bucket with
`fraction = amount/total`, **sorted by amount descending**. Slice color = category `colorHex`;
Uncategorized = gray.

**Donut geometry** (`fl_chart` `PieChart` or a custom painter — whichever reproduces this):
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

**Scoping/lookup logic:**
- `matchingCategoryIDs(id, isMain)`: main scope → `{main} ∪ children`; sub scope → `{id}`;
  no category → the explicit no-category bucket. This drives both totals and entry filtering. The
  null-bucket case is modeled as its own case, not a bare null that could collide with
  "uncategorized" — the same sealed `CategoryResolution` (`Excluded | Uncategorized |
  Category(id)`) that the domain layer uses for analysis gating (`../ARCHITECTURE.md` §4.1,
  ADR-0007).
- Entry lists reuse `daySections` then filter rows by the entry's `categoryID` ∈ matching set
  (direct scope: `categoryID == mainID` exactly), dropping now-empty sections.
- **Memoization:** the detail provider caches its kind+bucket-filtered item scan keyed on the
  cache's `itemsRevision`, applying the interval filter per call, and recomputes only when
  `AnalysisCache` bumps its revision. Per-render scan memoization beyond this is deferred until
  real data sizes demand it (`../ARCHITECTURE.md` §6) — not needed at the app's current, personal
  scale.

### 3.5 Provider tests (minimum)

rollUp slice ordering + Uncategorized bucketing, fraction math incl. zero total, subSlices
direct-bucket threshold (`> 0`), trendMonths both modes (year boundary, Jan), matchingCategoryIDs
matrix, revision-keyed memoization invalidates on bump.

---

## 4. Accounts tab

Owns its own navigation stack. Root screen, top to bottom: **custom header row** (no standard nav
bar: left-aligned "Accounts" headline + trailing `+` button opening the account form) →
**summary bar** → divider → grouped account list.

### 4.1 Summary bar

`ColumnText`: **Assets** (blue) / **Liabilities** (red) / **Total** = assets − liabilities.
Straight from `Accounting.netWorth` (`plans_and_accounting.md` — asset/liability split,
`includeInNetWorth`, archived-pocket exclusion all live there).

### 4.2 Sections (pure functions to extract)

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
  rows; only these two values render for card sections.

### 4.3 Card math — payable, outstanding, statement cut

- **Payable** = `max(0, −accountTotal)` — what you owe overall; a card in credit shows 0.
- **Outstanding** = Σ of **negated** amounts of entries where: source is the card account itself
  (pockets excluded — cards can't have pockets anyway), not a transfer, amount < 0, and
  `statementCut ≤ date ≤ now`. I.e. spend since the last statement; transfers (repayments) never
  reduce it, they reduce payable via the balance.
- **Statement cut**: with statement day `d`, anchor month = current month if `today.day ≥ d`,
  else previous month; cut = that month's day `d`, clamped into the month rather than rolled over.
  `d` can be 29–31 from imported or synced data even though the account form itself limits new
  entries to 1–28, so the clamp must hold regardless of input source. Statement-cut math goes
  through the shared `addMonthsClamped`/date-clamp helper (`../ARCHITECTURE.md` §5 rule 1):
  `cutDate = DateTime(y, m, min(d, daysInMonth(y, m)))` — `DateTime` rolls over silently otherwise,
  so an unclamped implementation is wrong by construction. Test the 28/29/30/31 × {Feb, Feb-leap,
  30-day, 31-day} matrix.
- `outstanding`/`statementCut` are **pure functions with injected `now`**, so statement-window
  logic is testable without depending on the system clock.

### 4.4 Rows and navigation

- **Account row:** expansion chevron (own hit target, only when the account has pockets) · name ·
  amount display (total, red-if-negative; or the card two-column). Tapping the **row body**
  (not the chevron) pushes the **account transactions screen**: the Transactions screen (§2) with
  title = account name and scope = account id + all its pocket ids.
- **Expanded** (one account at a time), gray-background sub-rows:
  - **"Excluding subpockets"** → pushes scope `[account.id]` only (titled with the account name),
    showing `ownBalance`.
  - One row per pocket → pushes `[pocket.id]`, titled with the pocket name, showing its balance.
- **Swipe-delete** on account rows and pocket rows → dialog **"Delete \<name\>?"** with body
  **"N transactions keep this name"** (matches the recycle-bin copy) and destructive Delete /
  Cancel. Delete = archive to recycle bin (`domain_models.md` §3.6); deleting the expanded account
  collapses it.

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
  `includeInAnalysis: false` — the running balance stays replay-consistent. Spec-critical: test
  that no delta produces no entry.
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
  (the list path, §5.1, is the confirmed one).

### 5.3 Symbol picker (pushed screen "Choose Icon")

Searchable sectioned grid (6 columns) of the `CategorySymbols` catalog (§0.3), rendered as
`CategoryIcon`s in the form's current color; the currently-selected symbol shows the inverted
"selected" chip. Search filters symbol names by substring (case-insensitive, trimmed); sections
with no matches drop out; sticky section headers. Tap → writes selection and pops.

### 5.4 Plan list ("Recurring Plans")

- Rows sorted by **next occurrence ascending; ended plans (nil next) last**, with name as the
  deterministic tiebreak whenever next-occurrence dates are equal — including between two ended
  plans. `nextOccurrence` comes from the domain (`plans_and_accounting.md`).
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
- **Repeat** row → `RecurrencePickerSheet` with a non-optional binding — choosing "One time" is
  ignored, since a plan can't become one-shot — · **First date** (anchor) picker · **End date**
  toggle + picker (no lower-bound constraint here, unlike the entry form — domain handles nonsense
  ranges by generating nothing).
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
  rule — restore the account first). Disabling the action, or a restore-parent-with-confirmation
  flow, is a possible future UX improvement, not required behavior today.
- **Trailing swipe → Delete** (red) → **purge confirmation**: title **"Delete permanently?"**,
  message: *"\<name\> leaves the bin for good. Existing transactions keep the name but it can no
  longer be restored."* — destructive Delete → purge (referenceOnly vs tombstone semantics are
  the domain's, §3.8).
- Purge routing: the controller inspects the id — money source → purgeAccount/purgePocket,
  category → purgeCategory.

### 5.7 Provider tests (minimum)

Category list ordering + kind-lock predicate, delete-copy pluralization, plan-row sort matrix
(nil-next last), plan save sign preservation, bin section membership + reference counts, purge
routing.

---

## 6. Rules this module holds itself to

- **State ownership.** Screen state lives in Riverpod providers, not in widgets constructed inline
  or tied to widget identity, so every screen gets controller tests from day one (§0.1).
- **Pure functions, not view logic.** `daySections`, month/week math, and `TransactionRow`
  resolution are plain Dart functions in the application layer, unit-tested independently of any
  widget (§2.2, §2.3, §2.8).
- **Transactions/Stats totals divergence is a ruled decision, not a bug** — see §2.1 (ADR-0026).
  The Transactions screen calls the single shared totals function rather than reimplementing gates
  locally.
- **Statement-cut date math is clamped, never allowed to overflow into the next month** (§4.3,
  `../ARCHITECTURE.md` §5 rule 1), with a test matrix across short and leap-year months.
- **Theme tokens, not hardcoded colors**, for neutral text; semantic blue/red/gray stay theme-aware
  (§0.2).
- **The Stats date/range toolbar renders on every platform**, with no platform gap (§3).
- **The account/pocket delete dialog shows the referencing-entry count** in its body (§4.4).
- **Treat-as-expense transfers land in the Uncategorized bucket.** This is documented,
  intentionally unfinished behavior — `plans_and_accounting.md` §7 has the full rule and the
  recorded future decision (bucketing by destination account type). Stats must not invent that
  bucketing ahead of the domain layer implementing it.
- **Accessibility and localization are open work**, not yet built: `Semantics` labels for custom
  widgets (the donut chart needs a text alternative; the FAB, two-column picker, and swipe actions
  need labels or custom actions), plus `intl` scaffolding with every §0.2 format routed through it.

---

## 7. Test coverage checklist

- **Shell:** symbol map (`symbol_map.dart`) resolution test (§0.3); theme tokens (amount
  blue/red/gray, gray6 surface, dark mode) (§0.2); shared-component tests — `CategoryIcon`,
  `ColumnText`, `AmountField` sanitizer, `TopTabBar`, `MonthYearSelector`, `FormScaffold`/
  `ErrorSection` (§0.4).
- **Transactions:** `TransactionRow.resolve`, `daySections`, interval totals (§2.2–2.3, §2.9);
  screen provider (selectedDate/mode/scope); daily list with sticky day headers, empty state,
  swipe-delete dialog; golden test for the transaction cell; `TwoColumnPickerSheet` plus
  Source/Category wrappers (§2.6); `RecurrencePickerSheet` (§2.7); entry form read-only-first,
  validation, save/sign/plan-creation matrix (§2.5); `ExpandingFAB` (§2.4); `monthSummaries`,
  expand/collapse, week-jump (§2.8).
- **Accounts:** sections, `accountTotal` wiring, payable/outstanding, clamped `statementCut`
  (§4.2–4.3); root screen — header, net-worth bar, grouped list, expansion rows, card columns;
  golden test for the account row; navigation to scoped Transactions (§4.4); account form and
  source-edit form including the balance-adjustment entry (§4.5–4.6); delete dialogs with
  reference counts.
- **Stats:** slices/`rollUp` wiring, subSlices+Direct, `trendMonths`, `matchingCategoryIDs`
  (§3.2, §3.4–3.5); tabs, total, donut with leader labels, legend list, empty state; golden test
  for the donut; range menu on every platform (§3); category detail scope selection, trend card
  with point selection, scoped entry list, revision-keyed memoization (§3.4).
- **Settings:** category list, form, and symbol picker (§5.1–5.3); plan list and form (§5.4–5.5);
  recycle bin restore/purge (§5.6).
- **Boot / banners / seed:** boot phase provider — loading spinner, load-failure retry screen
  (§1); save banner and plan-error banner, 4 s auto-dismiss with plan-error priority (§1);
  first-launch seeding (`ledger_runtime.md` §6) — verify seeded first-run renders on all four
  tabs; app lifecycle — resume triggers `resolvePlans`, pause triggers flush
  (`ledger_runtime.md` §5.3).

Exit: provider tests per screen green, goldens for cell/row/donut committed, and every rule in §6
covered by a test.
