# SpendWise Flutter — Porting & Development Tech Doc

**Status:** planning. This repo (`SpendWise`) is the Flutter rewrite. The finished native app lives at
`../SpendWise-SwiftUI` (frozen, kept as reference and as the source of truth for behavior).
Every claim in this doc was verified against that repo's code on 2026-08-08, not against memory or old specs.

**Why Flutter:** one codebase, six stable targets (Android, iOS, web, macOS, Windows, Linux), single
renderer so the UI is pixel-identical everywhere, and it is Google's framework. The native project's
README already promised "the domain is pure Swift with no Apple framework imports, which keeps an
Android port a UI-and-storage rewrite rather than a ground-up rebuild" — this doc is that rebuild,
extended to every platform. Interview line: **same domain model, two stacks.**

---

## 1. What V1 shipped (source inventory, verified)

~11.3k lines of Swift; 159 tests (Swift Testing) across ledger mutation, lifecycle, accounting,
analysis, recurring plans, persistence round-trip, and the event bus.

```
View  ──►  ViewModel (@Observable)  ──►  Ledger (@Observable)  ──►  LedgerState (pure value struct)
 ▲                                          │                             │  mutators return [LedgerChange]
 └────────── @Observable re-render ─────────┘                             ▼
                                                                       EventBus
                                              ┌───────────────────────────┴──────────────────┐
                                              ▼                                              ▼
                                    PersistenceProcessor                              AnalysisCache
                                              ▼                                    (off-main recompute)
                                   LedgerStore (protocol)
                        ┌─────────────────────┴─────────────────────┐
                        ▼                                           ▼
            SwiftDataLedgerStore (@ModelActor)             InMemoryLedgerStore
```

Feature surface (all built and persisted in V1):

- **Entries** — income / expense / transfer. Transfers carry NO category (validator enforces
  `categoryKindMismatch`); negative-amount transfers are normalized to positive with source/destination
  swapped. Per-entry `includeInAnalysis`. Opening balance = a synthetic entry with
  `includeInAnalysis: false`.
- **MoneySource = account | pocket** — one table, one id space. 8 account types; card accounts carry
  `statementDay` (1–28 — but only the FORM enforces the range; the domain passes it through, so the
  Dart domain must validate/clamp it itself, since drift rows and the future Realbyte import bypass
  the picker). Account owns `subPocketIDs` (parent → child only). Opening balance is a form-level
  restriction to accounts: the domain `setOpeningBalance` accepts ANY holder, the sample seed gives
  pockets opening balances, and the balance-edit flow posts "Balance adjustment" delta entries for
  pockets too — do not "enforce" the form rule in the domain or the seed silently thins and pocket
  balance-editing breaks. Per-holder `incomingTransfersAsExpenses`, per-account `includeInNetWorth`.
- **Categories** — income/expense kind, one level of nesting (validator + invariant enforced), stored
  `colorHex`, SF Symbol name, per-category `includeInAnalysis` with parent-gate semantics.
- **Recurring plans** — weekly / biweekly / monthly / quarterly / yearly, anchor + optional endDate,
  forward-only `lastResolvedDate` cursor, `resolvePlans` on app-active. Generated entry ids are
  **deterministic UUIDv5 of (planID, occurrence day)** so devices converge under future sync.
  Exhausted plans are retired. Failures surface via `PlanFailure`, not silently dropped.
- **Lifecycle** — `active → archived (recycle bin) → referenceOnly | tombstoned`. Delete = archive,
  never cascade; entries always retained. Purge with references → `referenceOnly` (names still
  resolve); without → `tombstoned` (row removed, pocket also leaves parent's `subPocketIDs` in the
  same step). Deleting the last referencing entry tombstones a dangling `referenceOnly` holder/category.
  11-clause `assertInvariants()` sweep runs after every mutation in debug.
- **Accounting (pure functions)** — balances derived from the entry log (never stored), net worth
  (asset/liability split, archived pockets excluded from parent totals), single-pass
  `analysisItems` classification (treat-as-expense transfers → `bucketID: nil` expense; category
  include gates with parent override), roll-up to main buckets, `AnalysisCache` recomputing off-main
  with a generation guard.
- **Persistence** — `LedgerStore` protocol (`load / start / enqueue / flushNow / setErrorHandler`).
  SwiftData store: ordered ingest stream, 250 ms debounce, per-target coalescing (last write per id
  wins within a batch), 2 retries with backoff, save-banner states (`clear / retrying /
  failedWillRetry`), barrier-based `flushNow`, per-row **version vector** (`bump / dominates /
  isConcurrent` — merge deferred to the sync engine), per-device UUID + `hasSeeded` flag in store meta.
- **UI** — 4 tabs (Transactions, Stats, Accounts, Settings). Month-navigated transaction list with
  day sections + month/week summaries, donut-chart stats with category drill-down, accounts grouped by
  type with pockets and card payable/outstanding, entry/account/pocket/category/plan forms,
  category picker, recurrence picker, recycle bin, sample-data seeding on first launch, save/plan-error
  banners, load-failure retry screen.

### Known defects and gaps in V1 (from code critique v2 — fix during the port, do not port them)

1. **Account-tombstone orphan bug (data integrity).** `entriesReferencing(holder:)` counts only direct
   references, so purging an account whose money lives entirely in its pockets tombstones the parent
   while pockets stay `referenceOnly` → orphan pocket, invariant #3 crash in debug. Fix in the Dart
   domain: a parent account counts as referenced while any of its pockets is alive/referenced.
   Regression test for exactly this shape.
2. **Transactions vs Stats totals diverge.** Transactions applies only entry-level
   `includeInAnalysis`; Stats also applies category gates and treat-as-expense transfers. Decide once:
   route both through the same `Accounting` gates, or write the divergence down as intentional
   Realbyte parity. Decide before building the Flutter Transactions screen.
3. **`statementCut` day-31 overflow.** Statement day 29–31 built via naive date components overflows
   into the next month on short months. Dart date math makes this worse (see §5 hazards) — clamp
   explicitly, test days 28/29/30/31.
4. **View logic in the view layer.** `daySections` aggregation and month-interval math lived in
   `View/` and were called by three view models. In Flutter these are pure functions in the domain
   or application layer from day one.
5. **Zero view-model tests.** The Flutter port writes provider/controller tests from the first screen.
6. **Accessibility + localization never happened.** Budget them as real phases this time (§7).
7. **Treat-as-expense analysis bucket is unfinished** — those transfers land in "Uncategorized"
   (`bucketID: nil`). Recorded decision: bucket by destination **account type**, not holder name.
   Not built in Swift; build it as a feature in Phase 6, not silently during the port. The full
   locked sub-decisions live in `SpendWise_V2_Handover.md` Phase 5 (see Phase 6 below).
8. **`failedWillRetry` is passive** — after the final retry the batch stays pending but nothing
   schedules another attempt; the banner text overpromises. Fix in the port: timed re-flush (same
   backoff cadence, singleton timer) plus flush on next lifecycle event; banner stays
   `failedWillRetry` across timed cycles.
9. **English strings persisted as data** — "Opening balance" and "Balance adjustment" are stored
   entry NAMES, written to disk forever; an `intl` pass cannot retro-localize them. Dart decision:
   keep the port faithful (stored names) BUT mark these entries structurally (system-entry flag or
   subtype) at schema day one so display-time naming can take over later without a data rewrite.

---

## 2. Repo and package structure

Monorepo, one Flutter app, domain extracted as a **pure Dart package** so purity is enforced by
`pubspec.yaml` (no `flutter` dependency possible), the same way the Swift domain had no framework
imports — but compiler-checked this time.

```
SpendWise/
  docs/                       # this doc, screenshots, future design docs
  packages/
    domain/         # pure Dart: models, LedgerState, LedgerChange, Accounting, invariants
      lib/
      test/                   # ported domain + accounting + plan tests (the bulk of the 159)
  app/                        # the Flutter app
    lib/
      ledger/                 # Ledger (mutation hub), EventBus, AnalysisCache
      persistence/            # LedgerStore, InMemoryLedgerStore, PersistenceProcessor, drift store
      ui/                     # screens, by tab, mirroring the SwiftUI View/ layout
      app.dart  main.dart     # boot phase machine (loading / ready / failed), seeding
    test/
```

Keep domain type names identical to Swift: `LedgerState`, `LedgerChange`, `Entry`, `MoneySource`,
`Account`, `SubPocket`, `TransactionCategory`, `RecurringPlan`, `EntryTemplate`, `LifecycleState`,
`Accounting`. The diff between the two domain layers should read as translation, not redesign.

## 3. Stack decisions

| Concern | Swift V1 | Flutter port | Why |
|---|---|---|---|
| Language | Swift 6 | Dart 3 | — |
| State management | `@Observable` + `.environment` | **Riverpod** (Notifier/Provider) | Industry standard, testable without widgets, compile-safe DI replaces `.environment` |
| Persistence | SwiftData `@ModelActor` | **Drift** (SQLite) | Typed schema + migrations, works on ALL six targets incl. web (wasm sqlite3) |
| Money | `Decimal` | **`decimal` package** | Port fidelity; never `double`. Store as TEXT in SQLite |
| IDs | `UUID` | **`String`** (lowercase uuid), `uuid` package | Dart uuids are strings natively; v5 supported out of the box for `OccurrenceID` |
| Charts | Swift Charts donut | **`fl_chart`** (or custom painter) | Donut + drill-down parity |
| Icons | SF Symbols names | **Material Icons** + a symbol-name mapping table | Stored `symbol` strings must be remapped once (see §5) |
| Codegen | none | **drift + build_runner only** | No freezed for domain — hand-written immutable-by-discipline classes keep the package dependency-light and readable; `==`/`hashCode` via hand or `equatable` where tests need it |
| Off-main compute | `Task.detached` | `Isolate.run` / `compute()` | Analysis recompute; note web has no isolates — fall back to sync compute there (personal-scale data makes this fine) |
| Tests | Swift Testing | `package:test` (domain) + `flutter_test` | Port test-by-test; names map 1:1 |

State-shape decision: `LedgerState` stays a **mutable class mutated in place**, owned exclusively by
`Ledger`, exactly like Swift (the contract was "only `Ledger.mutate` touches it"). Enforce with
library privacy: domain mutators are public, but the app never holds a `LedgerState` reference
outside `Ledger`. Views re-render via Riverpod notifications after `mutate`, mirroring `@Observable`.

**Snapshot rule (load-bearing):** in Swift, `AnalysisCache` handing `LedgerState` to `Task.detached`
was safe because the struct copy was a free immutable snapshot. The mutable Dart class loses that.
Rule: `Ledger` exposes an explicit `snapshot()` (cheap clone of the four maps; entries are immutable
value objects so the clone is shallow) and ONLY snapshots cross into `Isolate.run`. The web fallback
computes synchronously on the live object, which is safe only because it is synchronous — never
hand the live object to anything async.

**Currency policy:** single-currency app, deliberate spec cut carried over. Swift hardcodes
`"SGD"` at ~26 call sites plus a literal `"$"` in the amount field — do NOT reproduce that. One
`MoneyFormat` helper owns currency code (constant for now, settings-ready), symbol, and 2-dp
display. Amount INPUT rule: accept dot decimal, truncate to 2 fraction digits (Swift
`AmountFormat.sanitize` parity); locale-separator input is a recorded non-goal until localization.

## 4. Layer-by-layer port map

### 4.1 Domain (`domain`) — port first, no redesign

- `LedgerState` with its dictionaries → `Map<String, MoneySource>` etc. All mutators keep the
  **validate → mutate → return `List<LedgerChange>`** contract, throwing `LedgerError` (a sealed
  class mirroring the Swift enum, 12 cases).
- `LedgerChange` → Dart sealed class with the same 9 cases + `targetID`.
- `assertInvariants()` → same 11 clauses, run in debug (`assert(() { state.assertInvariants(); return true; }())`).
- `OccurrenceID` → `Uuid().v5(namespace, name)`. **Keep the exact namespace UUID
  (`8B9E0C42-5F3A-4D71-9C2E-1A6B7F0D3E85`) and the exact name string format**
  `"<planID-uppercase>|<seconds-since-2001-01-01-of-start-of-day>"` — Swift uses
  `timeIntervalSinceReferenceDate` (epoch 2001-01-01 UTC) and an uppercase `uuidString`.
  **Timezone decision (resolves a real contradiction):** Swift's `startOfDay` is LOCAL-timezone
  (`Calendar.current`), so native ids are device-tz-dependent — the very duplication risk §5
  warns about. The Dart port normalizes occurrence identity to **UTC date-only** (`startOfDay`
  in UTC). Algorithm compat is kept (same namespace, same name format); byte-compat with ids the
  native app minted on a non-UTC device is consciously given up — no data migration from the
  native app is planned, and UTC identity is what sync needs. The pin test states its timezone:
  planID `11111111-2222-3333-4444-555555555555`, day 2026-03-01 **UTC** → seconds `794016000` →
  `cca271e1-a2dc-56cf-9462-a710c0c21922` (verified by running the Swift algorithm with a UTC calendar).
- `RecurrenceFrequency.step` / `occurrences` → reimplement with a **clamped month-add** helper
  (§5 hazard 1). Port the month-end tests (Jan 31 monthly → Feb 28/29) first, then make them pass.
- `Accounting` + `Accounting+Analysis` → top-level pure functions or a namespace class. The
  `UUID??` double-optional trick (`null` = excluded, `Some(null)` = Uncategorized) does not exist in
  Dart — model it explicitly as a small sealed result (`Excluded | Uncategorized | Category(id)`).
  This is clearer than the Swift original; take the win.

### 4.2 Ledger + EventBus (`app/lib/ledger/`)

- `Ledger` → a Riverpod `Notifier` (or plain class exposed by a provider) with the same public
  mutation API. `mutate` runs domain method → debug invariants → `bus.publish(changes)` → notify
  listeners.
- `EventBus` → single `StreamController<List<LedgerChange>>.broadcast(sync: true)`. Swift needed a
  `Mutex` + `AsyncStream` fan-out to guarantee publish ordering across concurrent actors; Dart's
  single-threaded event loop gives ordered, lossless, synchronous fan-out for free. Keep the
  batch-payload contract (a cascade delete lands atomically).
- `AnalysisCache` → a provider that subscribes to the bus, recomputes `analysisItems` via
  `Isolate.run` with the same generation guard (revision captured before compute, result discarded if
  stale), exposes `items` + `itemsRevision`.

### 4.3 Persistence (`app/lib/persistence/`)

- `LedgerStore` abstract class: `load / start / enqueue / flushNow / setErrorHandler` +
  `SaveBannerState`. `InMemoryLedgerStore` for tests. `PersistenceProcessor` subscribes bus → store.
- **Drift schema** mirrors the SwiftData rows 1:1 (this is the persistence model, distinct from
  domain): `accounts`, `sub_pockets`, `categories`, `entries`, `plans` (template flattened into
  columns, as in `SDPlan`), `store_meta` (deviceID, hasSeeded). Every row: `version_data BLOB`
  (encoded version vector), `lifecycle INT`. Amount/decimal columns as TEXT. `load()` filters
  `lifecycle != tombstoned` and rebuilds `LedgerState` by replaying upserts (port
  `LedgerState+Replay`). **Reserve two columns at schema day one** (free now, a migration later):
  `entries.note TEXT` (locked V2 prerequisite — the split wizard writes principal/interest
  breakdown there, distinct from `name`) and the system-entry marker from §1 defect 9.
  **Decode fallback policy:** unknown enum codes fall back as Swift does (`AccountType.other`,
  `CategoryKind.expense`, `LifecycleState.active`, `RecurrenceFrequency.monthly`), but a
  version-vector that fails to decode is an **error**, not an empty vector — Swift's
  `?? VersionVector()` silently resets a row's causal history, which becomes data loss once the
  sync engine exists.
- Keep the store's write pipeline semantics, simplified for a single-threaded runtime: FIFO ingest
  queue, 250 ms debounce (`Timer`), coalesce last-change-per-target, batch stays pending until save
  succeeds, 2 retries with 200 ms backoff, then `failedWillRetry`. Fix critique #6 while here:
  `flushNow` loops until pending is empty, and `clear` is only reported after a non-clear state.
  Fix critique #7 too (§1 defect 8): after `failedWillRetry`, schedule a timed re-flush instead of
  waiting passively for the next mutation.
- `VersionVector` ports as-is (`Map<String, int>`, bump/dominates/isConcurrent). Merge still deferred
  to the sync engine.
- App lifecycle: `AppLifecycleListener` — `resumed` → `ledger.resolvePlans()`; `inactive/paused` →
  `persistence.flush()`. Same contract as `scenePhase`. Note: `resolvePlans` ALSO fires immediately
  after creating a plan from the entry form (which sets `lastResolvedDate = anchor − 1s` so the
  anchor occurrence materializes at once; the sample seed uses `lastResolvedDate = anchor`, anchor
  skipped — pin both conventions in tests).
- Seed builder: Swift's `Ledger.sample()` swallows every mutation failure (`try?`), so a validation
  tightening silently thins the seed. The Dart seed builder throws/asserts in debug — a seed
  regression must be loud.

### 4.4 UI (`app/lib/ui/`)

Screen-for-screen port, phone-first, one adaptive shell decision up front (V1 deferred it; Flutter
makes it cheap):

- Shell: `NavigationBar` (4 destinations) on compact width, `NavigationRail` on wide
  (desktop/web/tablet) — this leapfrogs the SwiftUI adaptive-layout item off the old roadmap.
- Screen-state ownership: selected month, selector mode, stats kind and similar per-tab state live
  in providers, never in widget-local state a rebuild can recreate (the Swift version's VM-lifetime
  fragility, critique #4, fixed structurally). Controllers that window on "now" take an injected
  clock, or the statement/summary tests cannot pin their windows.
- Transactions: month selector, day-sectioned list (income/expense/net day headers), month + week
  summaries, expanding FAB → entry form. `daySections` and month-interval math go in
  application-layer pure functions with tests (fixes critique #4).
- Entry form: amount field, income/expense/transfer segmented kind, source/destination pickers,
  category picker sheet (two-column), recurrence picker, includeInAnalysis toggle. Read-only-first
  detail + edit, as shipped in `EntryFormView`.
- Stats: donut (fl_chart) + legend + month navigation + per-category drill-down (trend + entry list).
- Accounts: grouped by account type, account rows with pocket sub-rows, card payable vs outstanding
  (with the statement-day clamp fix), account/pocket forms, opening-balance flow.
- Settings: category management (list, form, color + icon pickers, one-level nesting), recurring-plan
  list + form, recycle bin (restore / purge with reference-count messaging).
- Boot: phase machine `loading / ready / failed(retry)`, sample-data seed gated on `hasSeeded`,
  save + plan-error banners as a `SnackBar`/banner overlay.

## 5. Porting hazards (things that will silently bite)

1. **Dart date arithmetic does not clamp.** `DateTime(2026, 2, 31)` rolls over to March 3. Foundation's
   `calendar.date(byAdding: .month)` clamps (Jan 31 → Feb 28). Write one `addMonthsClamped` helper,
   use it for recurrence stepping AND statement-cut math, test the 28/29/30/31 × short-month matrix.
   This hazard is also the chance to fix the existing statement-day overflow bug.
2. **No `Decimal` in Dart core.** Any `double` that touches money is a defect. `decimal` package
   everywhere; TEXT in SQLite; lint for accidental `double` in the domain package.
3. **DST and local midnight.** Swift's `calendar.startOfDay` fed the occurrence-id hash. Use UTC dates
   (or date-only `(y, m, d)` normalization) for occurrence identity so a timezone move cannot change
   generated ids. Decide once, write it down here, pin with tests.
4. **SF Symbol names are meaningless in Flutter.** `TransactionCategory.symbol` stores SF Symbol
   strings. Build a mapping table (symbol name → `IconData`) with a fallback icon; new categories
   pick from a curated Material set going forward.
5. **`Set`/`Map` of ids.** Swift `Set<UUID>` → `Set<String>`. Normalize case (lowercase) at every
   boundary; UUID string case mismatches produce phantom "missing holder" bugs.
6. **Web caveats.** Drift on web needs the sqlite3 wasm setup (documented drift recipe); `Isolate.run`
   is unavailable — `AnalysisCache` falls back to synchronous compute on web.
7. **Ordering guarantees.** The Swift store's barrier/ingest design existed to defeat actor
   reordering. Dart's event loop removes the concurrency, but keep `flushNow`'s "everything enqueued
   before this call is on disk" contract and test it — backgrounding on mobile is still the moment
   that matters.
8. **Window boundary semantics.** Foundation's `DateInterval.contains` is end-inclusive and month
   intervals end at the next month's first instant, so an entry timestamped exactly on the boundary
   double-counts in both windows — latent in Swift, easy to fossilize. Pin **half-open
   `[start, end)`** for ALL window filters in the Dart domain, with a boundary test (this is the
   known `<=`-boundary blind spot; substitute extreme values out loud).
9. **Week-start convention.** Swift's week summaries use `Calendar.current` `weekOfYear`, so the
   boundary follows device locale (Sun vs Mon). Dart has no equivalent — the hand-written helper
   must pick a convention (locale-driven via `intl`, or fixed Monday) and test both week-start cases.

## 6. Port phases

Each phase ends green: `dart test` / `flutter test` passing, no analyzer warnings. Domain test parity
with the Swift suite is the port's correctness proof.

- **Phase 0 — toolchain + scaffold.** Install Flutter (`brew install --cask flutter`), `flutter doctor`
  clean for Android + iOS + macOS + web + Windows-later. Scaffold monorepo per §2, wire
  `domain` as a path dependency, CI-ready `analysis_options.yaml` (strict mode).
- **Phase 1 — domain models + LedgerState.** All model types, mutators, validation, lifecycle
  machine, invariants. Port `LedgerStateTests` (1,129 lines — the bulk of the suite) + fix the
  orphan-pocket bug with its regression test.
- **Phase 2 — plans + accounting.** `RecurringPlan`/`occurrences`/`resolvePlans` with clamped date
  math, `OccurrenceID` with the Swift-compat pin test, `Accounting` + analysis classification.
  Port `RecurringPlanTests`, `AccountingTests`, `AccountingAnalysisTests`.
- **Phase 3 — ledger runtime.** `Ledger`, `EventBus`, `AnalysisCache`, `InMemoryLedgerStore`,
  `PersistenceProcessor`. Port `EventDrivenTests`. Riverpod providers + first controller tests.
- **Phase 4 — drift store.** Schema, mappers, write pipeline (debounce/coalesce/retry/flushNow),
  seeding, version-vector bump. Port `PersistenceTests` (round-trip on a real in-memory SQLite).
- **Phase 5 — UI.** Screen order: shell → Transactions (list + entry form) → Accounts (+ forms) →
  Stats (+ drill-down) → Settings (categories, plans, recycle bin) → boot/banners/seed. Provider
  tests per screen; golden tests for the tricky rows (transaction cell, account row, donut).
- **Phase 6 — parity gaps + platform pass.** Treat-as-expense bucket by account type — build it to
  the LOCKED spec in `SpendWise_V2_Handover.md` Phase 5, which the one-liner elides: `loan` +
  `overdraft` APPENDED to `AccountType` (raw values stay stable), eligibility gate
  `allowsTransfersAsExpense` (blocked for cash/checking/card/prepaid, forced false on save),
  deterministic synthetic per-type bucket ids, pocket destination resolves to parent account's
  type, expense-only, slices self-carry name/symbol (grey, non-navigable). Transactions/Stats
  totals decision (§1 defect 2). Scope-aware transfer sign/color (designed in V2 Handover Phase 6,
  never built: transfer out of viewed scope renders red/−, into scope blue/+, both-in or global
  neutral; pocket scope = account + active pockets). Adaptive rail layout polish, localization
  scaffolding (`intl`) + semantics/a11y pass — the two commitments V1 never honored.
- **Phase 7 — release targets.** Android + iOS first (real devices), then macOS, web (drift wasm),
  Windows. Per-platform smoke checklist plus one `integration_test` boot-and-tap smoke per platform
  (the Swift UI-test target was an empty template — zero end-to-end coverage to port); screenshots
  into `docs/`; README for this repo.

Sequencing rule: **no UI work before Phase 3 is green.** The domain suite is what makes the port
trustworthy; UI on top of an unverified domain re-litigates every bug twice.

## 7. Post-port roadmap (future features, in intended order)

Carried over from the V1 README roadmap and the V2 tech doc
(`../job-applications/outputs/apple-eee-ios/SpendWise_V2_Tech_Doc.md`) — decisions there are locked
unless revisited. **Warning:** only the V2 doc's *decisions* are locked; its "shipped surface"
descriptions are stale (they reference deleted types — `Period`, `CalendarConfig`, pre-lifecycle
`deleteCategory`). Behavior always comes from the frozen repo. The frozen repo's own CLAUDE.md is
also pre-EventBus stale — trust code, not either doc.

1. **Budgets** — spending limits over category sets, progress per budget, **rollover** with carry
   derived by walking windows (never stored, cannot drift). Fold-carry per `RolloverMode`.
2. **Amortise + split-payment wizards** — BOTH built on `RecurringPlan` (locked decision: they are
   wizard tools, not engines; `Accounting` holds zero installment logic). Amortise = recognition-only
   spread (cash leaves once, analysis spreads monthly). Split = real monthly deduction, flat-rate and
   reducing-balance interest.
3. **Sync engine** — the payoff of the port: version vectors + deterministic occurrence ids are
   already in every row. CRDT-style merge using `dominates`/`isConcurrent`, conflict surfacing for
   truly concurrent edits, transport TBD (start with file/export sync or self-hosted; evaluate
   Firestore only with the offline-first constraint intact). Cross-platform sync (Android ↔ iOS ↔
   desktop ↔ web) is the headline demo.
4. **Receipt scan** — Flutter equivalent of the on-device pipeline: `google_mlkit_text_recognition`
   (on-device OCR) → past-corrections lookup wins → lightweight classifier for unseen merchants,
   confident pre-fill / unsure leave-uncategorized-and-remember. No network, receipts never leave the
   device.
5. **Realbyte import + export/backup** — CSV/Excel import from Money Manager to migrate real
   history (also the best source of realistic perf-test data), AND an export/backup path — an
   offline-first app across six platforms with no backup story loses data with the device.
6. **Search/filter** — spec-promised Realbyte parity, never built in V1 (the only `.searchable` was
   the symbol picker). Entry search by name/category/holder, at minimum.
7. **Later:** widgets/quick-add, notifications for recurring plans due, per-render scan memoization if
   real data sizes ever demand it (critique #8 — explicitly deferred at personal scale).

## 8. Definition of done for the port

- Domain test suite at parity with the frozen Swift suite (159 `@Test` functions; same scenarios,
  same names where sensible), plus regression tests for the fixed defects (orphan pocket,
  statement-day overflow, flushNow hole, timed retry after failedWillRetry).
- All V1 features in §1 working on Android + iOS + macOS + web.
- No `double` money, no unclamped date math, analyzer-clean under strict mode.
- This doc's §5 decisions (occurrence-id normalization, totals-divergence ruling) recorded inline once made.
