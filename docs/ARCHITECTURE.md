# SpendWise architecture and behavior spec

SpendWise is a personal finance app built with Flutter, targeting Android, iOS, macOS, Windows,
and Linux from one codebase and one renderer, so the UI is pixel-identical across platforms. This
document describes what the app does and how it is built: the feature surface, the stack decisions
and their rationale, the layer-by-layer architecture, the domain and implementation rules every
change must respect, and the roadmap for future work.

For narrower, per-capability detail, see `docs/knowledge/` (the feature knowledge base, one entry
per feature, holding both the behavior contract and the rationale for each capability). This
document is the wide-angle view that ties those entries together.

## 1. Feature surface

- **Entries** — income, expense, or transfer records. Transfers carry no category; the validator
  rejects one if given. A negative-amount transfer is normalized to a positive amount with its
  source and destination swapped. Every entry has a per-entry `includeInAnalysis` flag. An opening
  balance is a synthetic entry with `includeInAnalysis: false`.
- **MoneySource: account and pocket** — accounts and pockets share one id space and one table.
  There are 10 account types — cash, checking, savings, card, prepaid, investment, insurance,
  other, plus `loan` and `overdraft` — and the latter two treat incoming transfers as expenses, as do
  savings, investment, insurance, and other. A card account carries a `statementDay` (1–28),
  validated and clamped by the domain itself rather than relying on any UI picker to keep it in
  range, because seed data
  and future imports can set it directly. An account owns a list of pocket ids; a pocket belongs to
  exactly one parent account. Opening balance is settable on any money source, not only accounts:
  the seed data gives pockets opening balances, and the balance-edit flow posts a "Balance
  adjustment" delta entry for pockets the same way it does for accounts. Each money source has a
  per-holder `incomingTransfersAsExpenses` flag (see treat-as-expense, below) and each account has
  a per-account `includeInNetWorth` flag.
- **Categories** — labeled income or expense, with one level of nesting. Each category stores a
  color, an icon, and a per-category `includeInAnalysis` flag; a child category's inclusion is
  gated by its parent's.
- **Recurring plans** — weekly, biweekly, monthly, quarterly, or yearly, with an anchor date and an
  optional end date. Each plan tracks a forward-only `lastResolvedDate` cursor, advanced by
  `resolvePlans` whenever the app becomes active. Every generated entry has a deterministic id:
  UUIDv5 over the plan id and the occurrence's calendar day (see ADR-0004), so the same occurrence
  is recognized as the same entry across repeated resolutions rather than re-minted, which matters
  once multiple devices resolve the same plan independently. A plan with no occurrences left is
  retired. A failure during resolution surfaces as a `PlanFailure`, never dropped silently.
- **Lifecycle** — every money source, category, and plan moves through
  `active → archived (recycle bin) → referenceOnly | tombstoned`. Deleting a row archives it; delete
  never cascades, and entries that reference an archived row are always retained. Purging an
  archived row that still has references moves it to `referenceOnly`, where its name still resolves
  for display; purging one with no references tombstones it (the row is removed, and if it is a
  pocket, it also leaves its parent's pocket list in the same step). A parent account counts as
  referenced while any of its pockets is alive or `referenceOnly` — purging the parent first does
  not orphan the pockets. Deleting the last entry that references a dangling `referenceOnly` holder
  or category tombstones that holder or category. A 16-clause `assertInvariants()` sweep runs
  after every mutation in debug builds to catch violations of these rules immediately.
- **Accounting** — implemented as pure functions. Balances are derived from the entry log, never
  stored. Net worth splits assets from liabilities and excludes archived pockets from their
  parent's totals. A single-pass classification (`analysisItems`) resolves each entry to a category
  bucket, applying category inclusion gates (with parent override) and treat-as-expense
  reclassification for transfers. Category totals roll up to their parent bucket.
  `AnalysisCache` recomputes this off the main isolate, guarded by a generation counter so a stale
  result is discarded if a newer mutation has already superseded it.
- **Budgets** — a monthly spending cap rendered as a tab inside Stats, not a shell destination
  (ADR-0044). A budget attaches to at most one category (a null category means "overall", spanning
  every category); its limit is an append-only timeline of `LimitEvent`s — a default plus optional
  per-month `override`s — and `effectiveLimit` resolves the limit for a month by taking a matching
  override or, if none applies, the latest default at or before that month. Budget spend math lives
  in the app layer, not the domain (ADR-0042). A budget is created only from its form (ADR-0046),
  hard-deletes without a tombstone (ADR-0041), and its category rolls up to its parent (ADR-0039).
  See `docs/knowledge/budgets.md` and ADR-0038 onward for the full behavior contract.
- **Receipt scan** — on-device OCR receipt entry, mediated by a `ReceiptEntryCoordinator` that
  owns both the scan and the document-crop steps. Recognition runs on-device through
  `packages/ocr`, a pure Dart package that abstracts the text recognizer behind a per-platform
  seam (native document scanners on Android, ML Kit on iOS — ADR-0051, ADR-0056): the app crops a
  candidate, recognizes its text, looks the result up against past corrections, and pre-fills the
  entry form when confident. No receipt image or extracted text leaves the device. See
  `docs/knowledge/ocr-receipt-entry.md` and ADR-0051, ADR-0052, ADR-0056.
- **Persistence** — a `LedgerStore` contract (`load` / `start` / `enqueue` / `enqueueStamped` /
  `flushNow` / `setErrorHandler`) backed by Drift (SQLite), with an in-memory implementation for tests. Writes
  flow through an ordered ingest queue with a 250 ms debounce and per-`SyncRowID` coalescing, so only the
  last write to a given row within a batch is applied (see `docs/knowledge/persistence.md` for the pipeline). A failed write retries twice with backoff;
  the save-banner state machine (`clear` / `retrying` / `failedWillRetry`) reflects this, and
  `flushNow` provides a barrier that waits until every write enqueued before the call is on disk.
  Each row carries a version vector (`bump` / `dominates` / `isConcurrent`) to support a future sync
  engine; full merge logic is deferred to that engine, while the store already computes the carried
  pointwise maximum for stamped ingestion. Store metadata tracks a per-device id and
  whether the store has been seeded.
- **UI** — five top-level destinations: Overview, History, Trends, Money, and Settings. Overview
  shows Today, Recent entries and Coming up. History shows a month-navigated list grouped into day
  sections, with month and week summaries. Trends
  shows Income and Expense donut charts with category drill-down, plus a Budgets tab. Money groups money sources by account type, with
  pockets nested under their parent and card accounts showing payable and outstanding balances.
  Forms exist for entries, accounts, pockets, categories, and plans, plus a category picker, a
  recurrence picker, and a recycle bin for restoring or purging archived rows. The app seeds sample
  data on first launch and shows save-error and plan-error banners plus a retry screen on load
  failure.

## 2. Repository layout

The domain layer is a pure Dart package, kept dependency-free by `pubspec.yaml` refusing a
`flutter` import — a compiler-enforced boundary, not just a convention.

```
SpendWise/
  docs/                       # this document, the knowledge base, and working procedures
  packages/
    domain/                   # pure Dart: models, LedgerState, LedgerChange, Accounting, budgets, invariants
      lib/
      test/
    ocr/                      # pure Dart: on-device receipt recognition behind a platform seam
      lib/
      test/
  app/                         # the Flutter app
    lib/
      boot/                   # boot phase machine (loading / ready / failed), seeding, banner state
      ledger/                 # Ledger (mutation hub), EventBus, AnalysisCache
      ocr/                    # scan/crop orchestration, delegating recognition to packages/ocr
      persistence/            # LedgerStore, InMemoryLedgerStore, PersistenceProcessor, Drift store
      settings/               # app settings providers
      ui/                      # screens, organized by tab
      main.dart                # bootstrap; boot phase machine lives in boot/
    test/
```

Feature folders stay granular. Each UI feature splits presentation from data and view-model, helper
functions live in their own folders, and `packages/domain/lib/src` is grouped by concept instead of
one flat folder. A change lands in the smallest folder that owns the behavior it touches.

Core domain types: `LedgerState`, `LedgerChange`, `Entry`, `MoneySource`, `Account`, `SubPocket`,
`TransactionCategory`, `RecurringPlan`, `EntryTemplate`, `LifecycleState`, `Budget`,
`LimitEvent`, `EntryKind`, `SystemEntryKind`, `AnalysisItem`, `NetWorth`, `Accounting`.

## 3. Stack decisions

| Concern | Choice | Why |
|---|---|---|
| Language | Dart 3 | — |
| State management | Riverpod (`Notifier`/`Provider`) | Testable without widgets; compile-safe dependency injection |
| Persistence | Drift (SQLite) | Typed schema and migrations, and it runs on every target |
| OCR recognition | `packages/ocr` (platform channel) | On-device text recognition behind a per-platform seam (native scanner on Android, ML Kit on iOS); the package is pure Dart and testable without a device |
| Money | `decimal` package | `double` is never precise enough for currency; stored as `TEXT` in SQLite |
| IDs | `String` (lowercase uuid), `uuid` package | Dart represents uuids natively as strings; the package supports v5 out of the box for occurrence ids |
| Charts | `fl_chart` (or a custom painter) | Donut chart with drill-down |
| Icons | Material Icons, with a stored-symbol-name mapping table | A category's stored icon name is remapped to a `IconData` once at read time, never re-stored |
| Codegen | Drift and `build_runner` only | No codegen for the domain package: hand-written immutable-by-discipline classes keep the package dependency-light and readable; equality is implemented by hand or with `equatable` where tests need it |
| Off-main compute | `Isolate.run` / `compute()` | Used for analysis recompute; tests inject a synchronous runner instead, so a widget pump sees the result without waiting on a real isolate |
| Tests | `package:test` (domain) and `flutter_test` (app) | — |

`LedgerState` is a mutable class, mutated in place, owned exclusively by `Ledger` — nothing else
holds a reference to it. This is enforced with library privacy: domain mutators are public, but the
app never reaches a `LedgerState` reference except through `Ledger`. Widgets re-render through
Riverpod notifications published after each mutation.

**Snapshot rule.** Handing the live `LedgerState` to anything asynchronous is unsafe, because it
can be mutated again before the async work reads it. `AnalysisCache` computes analysis through a
swappable `ComputeRunner`: it runs `Isolate.run`, and the isolate's message serialization
deep-copies the `LedgerState` argument it is handed — that copy is the snapshot, so a mutation
landing mid-compute cannot corrupt the result the compute returns. The synchronous runner tests
inject computes on the live object, which is safe only because that path is synchronous end to end;
the live object must never be handed to anything async. A generation counter (`_lastComputed`
versus the per-batch `revision`) discards a compute whose generation moved on before it finished, so
a stale result never overwrites a fresh one (ADR-0015).

**Currency policy.** SpendWise is single-currency by design. One `MoneyFormat` helper owns the
currency code (a constant today, ready to become a setting), the currency symbol, and two-decimal
display, so the choice lives in one place rather than being hardcoded at each call site. Amount
input accepts a dot as the decimal separator and truncates to two fraction digits; locale-specific
separator input is a recorded non-goal until localization work begins.

## 4. Layer-by-layer architecture

### 4.1 Domain (`packages/domain`)

- `LedgerState` holds its rows in `Map<String, MoneySource>` and equivalent maps for entries,
  categories, plans, and budgets. Every mutator follows the same contract: validate, mutate, then
  return `List<LedgerChange>`, throwing a `LedgerError` (a sealed class with 15 cases) on a
  validation failure — the account/holder/category/entry/plan, exhausted-plan, and unknown-budget
  errors, plus id collisions, inactive references, stale resolution cursors, locked system entries,
  zero amounts, and category depth, kind, or budget-existence conflicts.
- `LedgerChange` is a sealed class with 11 cases — `UpsertAccount`, `UpsertPocket`, `UpsertCategory`,
  `UpsertEntry`, `UpsertPlan`, `UpsertBudget`, `DeleteMoneySource`, `DeleteCategory`, `DeleteEntry`,
  `DeletePlan`, `DeleteBudget` — plus a `targetID`.
- `assertInvariants()` enforces 16 clauses and runs in debug builds via
  `assert(() { state.assertInvariants(); return true; }())`; a separate monotonic-lifecycle check
  runs alongside it in the same assertion, and the sweep stays snapshot-only so a mutation not yet
  checked is never asserted against a later snapshot.
- The model has 10 account types; `loan` and `overdraft`, like savings, investment, insurance, and
  other, treat incoming transfers as expenses (see `AccountType.allowsTransfersAsExpense`).
- **Budgets in the domain.** A `Budget` owns a nullable category, a `createdAtMonth`, and an
  immutable, append-only `List<LimitEvent>`; the pure function `effectiveLimit` resolves the limit
  for a month from that timeline. The domain enforces budget invariants (the category resolves, each
  limit event has a valid shape) but performs no spend math — that stays in the app layer.
- Entries carry an `EntryKind` (income, expense, transfer) and an optional `SystemEntryKind`
  (`openingBalance`, `balanceAdjustment`); system entries are protected from user edits by
  `systemEntryLocked`.
- `OccurrenceID` is `Uuid().v5(namespace, name)`, with a fixed namespace UUID
  (`8b9e0c42-5f3a-4d71-9c2e-1a6b7f0d3e85`) and a name string of the form
  `"<planID-lowercase>|<seconds-since-2001-01-01-of-start-of-day>"`. The plan id is normalized to
  lowercase before it enters the name, so an id-casing difference between two representations of the
  same plan can never change the produced id. Occurrence identity is
  normalized to UTC date-only (`startOfDay` in UTC), so a device's timezone can never change which
  id a given plan and calendar day produce — a real risk if identity were computed from local time,
  since two devices resolving the same plan in different timezones would then mint different ids
  for what should be the same occurrence, defeating deduplication once multiple devices sync. The
  pinned test fixes the id for a given plan id and UTC day and pins the case-insensitive plan-id
  match and the time-of-day collapse (local vs UTC, any time of day) to the same id.
- `RecurrenceFrequency.step` / `occurrences` use a clamped month-add helper (see §5, rule 1) so
  stepping a monthly plan anchored on the 31st lands on the last day of a shorter month instead of
  rolling into the next month.
- `Accounting` and its analysis extension are top-level pure functions (or a namespace class).
  Category resolution is modeled as an explicit sealed result —
  `Excluded | Uncategorized | Category(id)` — rather than a nullable-of-nullable value, which keeps
  the three states unambiguous at every call site. See ADR-0007.

### 4.2 Ledger and event bus (`app/lib/ledger/`)

- `Ledger` is a `ChangeNotifier` exposed by a provider, with a public mutation API. `mutate` runs
  the corresponding domain method, checks invariants in debug builds, publishes the resulting changes
  on the event bus, then notifies listeners.
- `EventBus` is the synchronous broadcast carrying `LedgerPublication` batches; see
  `docs/knowledge/ledger-runtime.md` for the contract. A cascade delete's changes still land as
  one atomic batch.
- `AnalysisCache` is a provider that subscribes to the bus and recomputes `analysisItems` via
  `Isolate.run`, guarded by a generation counter captured before the compute starts; a result is
  discarded if the generation has moved on by the time it finishes. It exposes `items` and
  `itemsRevision`.

### 4.3 Persistence (`app/lib/persistence/`)

- `LedgerStore` is the durable contract backed by Drift; `InMemoryLedgerStore` backs tests.
  See `docs/knowledge/persistence.md` for the contract and `docs/knowledge/ledger-runtime.md`
  for the bus-to-store bridge.
- The Drift schema is the persistence model, distinct from the domain model: `accounts`,
  `sub_pockets`, `categories`, `entries`, `plans` (a plan's template fields are flattened into
  columns), `budgets`, and `store_meta` (device id, `hasSeeded`). Every ledger row (every table
  except `store_meta`) carries a `version_data BLOB`
  (an encoded version vector) and a `lifecycle INT`. The v4 sync-coordination tables
  (`sync_meta`, `sync_acknowledged_vectors`, `sync_pending_acknowledgements`,
  `sync_staged_conflicts`, `sync_staged_siblings`) follow their own keys instead; their table
  doc comments in `app/lib/sync/sync_tables.dart` own that schema, with the coordination
  behavior covered in `docs/knowledge/sync-durable-stores.md`. Amount and other decimal columns are stored as
  `TEXT`. Budgets store an append-only `limit_events` column (a JSON array of `effectiveFromMonth`,
  `value`, and `kind`) alongside a nullable `category_id` and `created_at_month`. `load()` filters
  out rows with `lifecycle == tombstoned` and rebuilds `LedgerState` by replaying upserts.
  `entries.note TEXT` remains reserved ahead of a future split-payment wizard's principal/interest
  breakdown; a `system_kind INT` column, by contrast, is now written (0 opening balance, 1
  balance adjustment, null for a user entry) to mark synthetic entries and protect them from edits,
  so it needs no migration and no longer waits for a feature.
- **Decode fallback policy.** An unknown enum code decodes to a safe default
  (`AccountType.other`, `CategoryKind.expense`, `LifecycleState.active`,
  `RecurrenceFrequency.monthly`). A version vector that fails to decode is treated as an error, not
  silently reset to an empty vector — resetting it would erase a row's causal history, which
  becomes real data loss once the sync engine is in place.
- The write pipeline is a FIFO ingest queue with a 250 ms debounce (`Timer`), coalescing to the
  last change per `SyncRowID` (see `docs/knowledge/persistence.md`). A batch stays pending until its save succeeds, retries twice with 200 ms
  backoff, then settles into `failedWillRetry`. `flushNow` loops until the pending queue is empty,
  and a `clear` banner state is only reported after a preceding non-clear state, so a client
  watching the banner never misses a transition. After `failedWillRetry`, the store schedules a
  timed re-flush on the same backoff cadence rather than waiting passively for the next mutation to
  trigger a retry.
- `VersionVector` is a `Map<String, int>` supporting `bump` / `dominates` / `isConcurrent`. Full merge
  logic is deferred to the sync engine; the store computes only the carried pointwise maximum for stamped ingestion.
- App lifecycle: on `resumed`, the app calls `ledger.resolvePlans()`; on `inactive`/`paused`, it
  calls `persistence.flush()`. `resolvePlans` also fires immediately after a plan is created from
  the entry form — creation sets `lastResolvedDate = anchor − 1s` so the anchor occurrence
  materializes at once, while the sample seed sets `lastResolvedDate = anchor` so the seed's anchor
  occurrence is skipped. Both conventions are pinned by tests.
- The seed builder throws or asserts in debug builds on any mutation failure, so a validation
  tightening that would otherwise silently thin the seed data is caught loudly instead.

### 4.4 UI (`app/lib/ui/`)

The app is phone-first with one shell whose phone or desktop layout is chosen by platform:

- Phone shows a rounded five-position bar (Overview, Trends, centred Add, Money, Settings;
  Add is a never-selected action opening the shared entry presenter). Open shows a vertical
  rail docked bottom right (Overview, History, Trends, Money, Settings, filled Add; 54 dp wide
  with 9 dp right and 10 dp bottom insets, 18 dp radius) over content reserving a 72 dp gutter,
  with the status banner clearing the same gutter. Phone and open share one stable Scaffold,
  content Stack and keyed `IndexedStack` with five fixed destination positions; only chrome and
  the content gutter change between them, so a phone/open switch keeps the selected destination,
  every Flow State, Navigator State and nested route. The mobile History slot materializes
  lazily on first open-mode use or explicit History selection and is retained after; the phone
  bar still shows no History item, and a shell History selected at an open-to-phone switch stays
  selected and visible with a root back control labelled Overview. A History page already pushed
  inside Overview stays on that nested stack across resize. Desktop shows a sidebar (wordmark,
  Overview, History, Trends, Money, an Add entry button, Settings at the bottom) over the same
  five slots. All Add controls open the shared entry presenter; the
  shell captures the top scoped Money route's preferred source only while Money is selected.
  The shared Add presenter opens one root `AppSheetRoute` with a keyed entry form and a live
  presentation resolver: phone spans the bottom at full width, desktop centres a dialog, and open
  docks a full-height surface in the safe right half starting at half the window width behind a
  transparent dismissible barrier. A phone/open resize changes only sheet geometry, alignment and
  chrome, keeping the route, draft, focus and auxiliary picker routes.
  A container-local presentation controller owns one private Add session per request: identity,
  duplicate guard, the exact route, one mount-gated Step subscription and one completion that
  settles at `route.completed`. Add-only `EntryForm.onDismiss` closes exactly that route even
  beneath a picker, and retired sessions reject late picker and crop results.
  Every exit (cancel, save, Back, barrier, route removal, `AppShell` disposal, container disposal)
  converges on one idempotent retirement that closes the subscription, defers receipt-coordinator
  invalidation and releases ownership only at `route.completed`.
  History hosts the unscoped `TransactionsFlow`; its screen-`Step` consumption is gated on the
  enclosing `DestinationActivity`, so a hidden retained instance neither acts on nor clears a
  shared `Step`. `shellLayoutModeProvider` resolves
  `ShellLayoutMode.phone`, `ShellLayoutMode.open` or `ShellLayoutMode.desktop` from fixed
  platform facts plus the current logical window size: web, macOS, Windows and Linux always use
  desktop; on iOS and Android the window is open exactly when at least 600 dp wide and at least
  480 dp high (both inclusive), otherwise phone, following runtime size changes with no
  hysteresis. Phones are locked to portrait where the platform honours the request (iPhone `UISupportedInterfaceOrientations` lists portrait only; Android `MainActivity` requests portrait through `requestedOrientation` while `smallestScreenWidthDp` is below 600 and re-applies on configuration change), but Android multi-window can ignore the request and still present a landscape-shaped window; tablets and unfolded foldables keep every orientation, and the 600 x 480 dp rule and its landscape-window tests are unchanged and still cover those cases. The inspected Flutter 3.47.4 iOS embedder reports no display features, and the
  rule ignores display features on every platform. One fixed destination list resolves every
  stack index. The
  shared `buildShellAppContent` app builder reads the root window size before `SafeArea` and
  feeds a retained binding scope, so resize keeps the selected destination and provider
  container identity.
  `ShellPaneScope` supplies mode, safe body width and whether the existing Add route is presented.
  `ShellPaneHost` calls its page builder with bounded constraints and
  `ShellPagePresentation.fullPage` or `singleColumn`. In open mode, for safe body width W, the page
  is W/2 wide when a detail or Add occupies the right half and W - 72 dp wide otherwise. A visible
  detail starts at W/2 and is W/2 - 72 dp wide; the rail gutter is reserved once. `ShellDetail`
  requires stable identity, title, body builder and Close callback, with optional subtitle and
  header actions. The host retains the page child at one element location, owns the divider and
  pinned detail header, and leaves scrolling to page and detail body builders. It retains hidden
  detail offstage with feature selection intact and never pushes or pops routes. A supplied
  floating action appears only on the active, current open page while Add is closed, at 10 dp from
  the bottom and 3 dp from the usable page's right edge, or 75 dp from the full body's right edge.
  Each feature owns `selectedDetailId` and selected-detail state in its ViewModel, independent of
  mode. Phone and open actions update the same selection. The retained feature Flow owns at most one
  managed phone detail route whose content observes the latest selection. One post-frame
  reconciliation coalesces mode and selection changes. Entering open removes only the tracked
  route through that Flow's Navigator as a presentation-only removal. Entering phone pushes one
  route when selection exists and no managed route exists; a selection change updates that route.
  User Back or Close clears selection, while presentation-only removal preserves it. Route identity
  prevents an outgoing route from clearing replacement selection. Preserve unrelated routes and
  defer a missing phone detail until its feature page is exposed. Exactly one exposed detail matches
  the latest selection. Desktop detail presentation remains feature-owned.
  `showShellConfirmation<T>` pushes on the root Navigator and returns the caller's result; dismissal
  returns null. Open mode centers a dialog up to 308 dp over both panes, blocks the full window
  with a transparent barrier, and paints dim only over the pane region before the 72 dp rail
  gutter. Phone and desktop keep full-window centering. Delete and purge helpers map dismissal to
  false.
- Screen-level state — selected month, selector mode, stats kind, and similar per-tab state — lives
  in providers, never in widget-local state that a rebuild can silently recreate. Controllers that
  window on "now" take an injected clock, so statement and summary window logic can be pinned in
  tests.
- **Flow widgets are self-contained.** A flow or feature widget works in isolation: it does not hold
  a `Navigator` reference, does not know about sibling flows, and communicates with the outer screen
  only through injected callbacks or the event bus. It never reads the outer screen's state or
  widgets directly, so a flow stays testable and reusable without coupling to the screen that hosts
  it.
- **MVVM split.** Each UI feature is three files: a screen widget that binds state to widgets, a
  `_view_model` that holds the feature's state, and a `_logic` that owns the pure transform methods
  that move the view model (ADR-0057, ADR-0058). Flows own their own nested Navigator and are driven
  by a step stream, so deep routes push inside the flow and a back gesture reaches the flow's own
  navigator first (ADR-0059). This keeps the transform logic testable without widgets and couples a
  view only to the interface of methods that drive it, not to their implementation.
- Transactions: a month selector, a day-sectioned list with income/expense/net day headers, month
  and week summaries. Add lives in the shell; Transactions has no local Add or Edit source control. `daySections` and
  month-interval math are pure, tested functions in the application layer, not view logic.
- Entry form: an amount field, an income/expense/transfer segmented control, source and destination
  pickers, a two-column category picker sheet, a recurrence picker, and an `includeInAnalysis`
  toggle. Read-only-first detail view, with a separate edit mode.
- Stats: three tabs — Income and Expense, each a donut chart (`fl_chart`) with a legend, month
  navigation, and per-category drill-down showing a trend and an entry list, and Budgets, which
  renders the budget list, form, and detail.
- Accounts: grouped by account type, with account rows showing pocket sub-rows, card accounts
  showing payable versus outstanding (statement-day clamped per §5 rule 1), account and pocket
  forms, and the opening-balance flow.
- Settings: category management (list, form, color and icon pickers, one level of nesting),
  recurring-plan list and form, and the recycle bin (restore, or purge with a reference-count
  message).
- Boot: a sealed `AppPhase` machine (`Loading` / `Ready` / `Failed`) living in `boot/`, with
  `Ready` carrying the `Ledger` and `PersistenceProcessor`; sample-data seeding gated on
  `hasSeeded`; a retry that invalidates the prior provider (ADR-0047); and save/plan-error banners
  shown as a persistent overlay (ADR-0025).

## 5. Domain and implementation rules

These rules hold across the codebase; each one exists because violating it produces a real,
observed class of bug.

1. **Date arithmetic clamps, it never rolls over.** `DateTime(2026, 2, 31)` in Dart rolls over to
   March 3 rather than raising an error, so every place that adds months — recurrence stepping and
   statement-cut math — goes through one `addMonthsClamped` helper instead of raw `DateTime` math.
   A monthly plan anchored on the 31st lands on the last day of a shorter month (Jan 31 monthly
   stepped to February lands on Feb 28, or Feb 29 in a leap year), and a statement day of 29, 30,
   or 31 clamps the same way rather than overflowing into the next month.
2. **Money is `Decimal`, never `double`.** Any `double` that touches money in the domain package is
   a defect. The `decimal` package is used everywhere money is represented, money is stored as
   `TEXT` in SQLite, and the domain package is linted against accidental `double` use.
3. **Occurrence identity is UTC-normalized.** An occurrence id is derived from a plan id and a
   UTC date-only value (see §4.1), so a device's local timezone or a DST transition can never
   change which id a given occurrence produces.
4. **Icon names are Material Icons, not free-form strings.** A category's stored icon name is
   looked up in a mapping table to a Flutter `IconData`, with a fallback icon for an unmapped name.
   New categories pick from a curated Material icon set.
5. **Ids are lowercase, normalized at every boundary.** An id read from storage, from user input, or
   computed from a hash is lowercased immediately. A case mismatch between two representations of
   the same id is a common source of phantom "missing holder" bugs, so normalization happens once,
   at the boundary, rather than being assumed downstream.
6. **The synchronous runner is a test seam.** `AnalysisCache` dispatches to `Isolate.run` on every
   platform the app ships to. A test injects `syncComputeRunner` to compute on the live object
   instead, which is safe only because that path is synchronous end to end.
7. **`flushNow` is a real barrier.** Every write enqueued before a `flushNow` call is guaranteed to
   be on disk before the call returns. This is tested directly, because backgrounding on mobile is
   exactly the moment this guarantee has to hold.
8. **Window filters are half-open, `[start, end)`, everywhere.** A boundary instant belongs to the
   window that starts there, not the one that ends there, so a single entry can never be counted in
   two adjacent windows (for example, two consecutive months) at once. This is pinned with a
   boundary test using extreme values.
9. **Week start is a fixed, explicit convention.** Week-based summaries pick one week-start
   convention (driven by `intl` locale data, or a fixed Monday) rather than an implicit
   platform default, and both week-start cases are covered by tests.

## 6. Roadmap

Future work, in intended order:

1. **Sync engine.** Version vectors and deterministic occurrence ids are already in place on every
   row specifically to support this. The plan is a CRDT-style merge using `dominates` and
   `isConcurrent`, with conflict surfacing for edits that are genuinely concurrent. Transport is not
   yet decided — starting with file or export-based sync, or a self-hosted option, and evaluating a
   hosted backend only if it can preserve the app's offline-first behavior. Cross-platform sync
   (Android, iOS, and desktop all converging) is the goal.

The engine-agnostic backend transport contract this engine uses is specified in `docs/sync-protocol.md`,
which is reachable through the required reading order in `docs/NAVIGATION.md`.
2. **Realbyte import and export/backup.** CSV/Excel import from Money Manager, to migrate existing
   transaction history (and to generate realistic data for performance testing), plus an
   export/backup path — an offline-first app with no backup story loses data whenever a device is
   lost.
3. **Search and filter.** Entry search by name, category, or holder, at minimum.
4. **Later.** Home-screen widgets and quick-add, notifications for recurring plans coming due, and
   per-render scan memoization if real data sizes ever demand it (not needed at the app's current,
   personal scale).
