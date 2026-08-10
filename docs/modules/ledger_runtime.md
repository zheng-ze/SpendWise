# Module Spec — Ledger Runtime

**Scope:** `Ledger`, `EventBus`, `AnalysisCache`, `PersistenceProcessor`, boot phase machine,
lifecycle hooks, banners, sample seed. Maps to Phase 3 of the master plan
(`docs/Flutter_Port_Tech_Doc.md`) plus the boot/banner slice of Phase 5.

**Source of truth (verified 2026-08-08):**

| Swift source | Dart home |
|---|---|
| `SpendWise/Repository/Ledger.swift` | `app/lib/ledger/ledger.dart` |
| `SpendWise/Repository/EventBus.swift` | `app/lib/ledger/event_bus.dart` |
| `SpendWise/Services/AnalysisCache.swift` | `app/lib/ledger/analysis_cache.dart` |
| `SpendWise/Repository/Persistence/PersistenceProcessor.swift` | `app/lib/persistence/persistence_processor.dart` |
| `SpendWise/SpendWiseApp.swift` (AppRootView) | `app/lib/app.dart` + `main.dart` |
| `SpendWise/Repository/Ledger+Sample.swift` | `app/lib/ledger/sample.dart` |
| `SpendWiseTests/EventDrivenTests.swift` | `app/test/ledger/event_driven_test.dart` |

This doc defines **expected behavior** of the Dart implementation. Where Dart's runtime makes a
Swift mechanism unnecessary, the *guarantee* is kept and the mechanism is replaced — both are
spelled out.

---

## 1. Ledger — the sole mutation hub

`Ledger` is the only object in the app allowed to touch `LedgerState`. Views and view models never
hold a `LedgerState` reference; they read via `Ledger` and mutate via its API. (Master doc §3:
`LedgerState` is a mutable class owned exclusively by `Ledger`.)

### 1.1 `mutate` contract

Every public mutation runs the same private pipeline, in this exact order:

1. **Run the domain mutator** against the owned `LedgerState`. The mutator validates first and
   throws `LedgerError` on rejection; on success it applies the mutation and returns
   `List<LedgerChange>` (the facts).
2. **Debug invariant sweep** — `assert(() { state.assertInvariants(); return true; }())`. Runs
   after *every* successful mutation in debug builds, stripped in release. (Swift: `#if DEBUG`.)
3. **Publish the changes to the bus** — `bus.publish(changes)` as one batch.
4. **Notify Riverpod listeners** (the Dart replacement for `@Observable` re-render — see §8).

Failure semantics: if the domain mutator throws, **nothing** happens — no state change, no
invariant sweep, no bus publish, no listener notification. The throw propagates to the caller
(pinned by test `rejectedMutationPublishesNothing`).

A cascade (e.g. `addPocket` returns the pocket upsert *plus* the updated parent account) publishes
as **one atomic batch**, never split.

### 1.2 Public API surface

Exact surface of Swift `Ledger`. Every method forwards to the same-named `LedgerState` domain
mutator through `mutate`. Throwing vs non-throwing mirrors Swift (`try mutate` vs `mutate`).

| Ledger method | Forwards to (domain) | Throws? | Notes |
|---|---|---|---|
| `addAccount(Account)` | `state.addAccount` | yes | |
| `updateAccount(Account)` | `state.updateAccount` | yes | |
| `addPocket(SubPocket, to: accountID)` | `state.addPocket(_, to:)` | yes | Cascade: pocket upsert + parent account upsert |
| `updatePocket(SubPocket)` | `state.updatePocket` | yes | |
| `addEntry(Entry)` | `state.addEntry` | yes | |
| `updateEntry(Entry)` | `state.updateEntry` | yes | |
| `setOpeningBalance(Decimal, for: holderID, on: date = now)` | `state.setOpeningBalance` | yes | Synthetic entry, `includeInAnalysis: false` |
| `addCategory(TransactionCategory)` | `state.addCategory` | yes | |
| `updateCategory(TransactionCategory)` | `state.updateCategory` | yes | |
| `deleteAccount(id)` | `state.deleteAccount` | no | Delete = archive (recycle bin); entries retained |
| `deletePocket(id)` | `state.deletePocket` | no | |
| `deleteCategory(id)` | `state.deleteCategory` | no | |
| `deleteEntry(id)` | `state.deleteEntry` | no | May tombstone a dangling `referenceOnly` holder/category |
| `restoreAccount(id)` | `state.restoreAccount` | no | |
| `restorePocket(id)` | `state.restorePocket` | no | |
| `restoreCategory(id)` | `state.restoreCategory` | no | |
| `purgeAccount(id)` | `state.purgeAccount` | no | Referenced → `referenceOnly`; unreferenced → `tombstoned` |
| `purgePocket(id)` | `state.purgePocket` | no | Tombstoned pocket also leaves parent's `subPocketIDs` in same step |
| `purgeCategory(id)` | `state.purgeCategory` | no | |
| `addPlan(RecurringPlan)` | `state.addPlan` | yes | |
| `updatePlan(RecurringPlan)` | `state.updatePlan` | yes | |
| `deletePlan(id)` | `state.deletePlan` | no | Hard delete — plans have no recycle bin |
| `resolvePlans(now = now, calendar)` | `state.resolvePlans` | no | See §1.4 |
| `categories(of: CategoryKind)` | read-only query | no | See §1.3 |

There is **no** `restoreEntry`, `purgeEntry`, `restorePlan`, or `purgePlan` on the hub. Do not
invent them.

Non-mutating exposure: `ledgerState` is readable (Swift: `private(set)`); `bus` is exposed for
subscriber wiring; `onPlanError` is a settable callback (§1.4).

### 1.3 `categories(of: kind)` ordering contract

Returns **active** categories of the given kind (filter by `state.activeCategories` membership
AND `kind` match), ordered:

- Roots (`parentID == null`) sorted by `name`.
- Each root immediately followed by its children, themselves sorted by `name`.
- Children whose parent is not in the active/kind-filtered set are dropped (Swift groups children
  by parent and flatMaps from roots only — orphaned children never appear).

Swift sorts with plain `<` on `String`. Use the same ordinal comparison (`compareTo`) in Dart, not
locale-aware collation, so ordering is identical across platforms.

### 1.4 `resolvePlans` + `onPlanError`

Called on app-active (§5.3). Behavior:

1. Runs `state.resolvePlans(now, calendar)` inside `mutate`. The domain returns
   `(List<LedgerChange> changes, List<PlanFailure> failures)`; the changes go through the normal
   publish pipeline (materialized entries + updated plan cursors + retired-plan changes land as
   **one batch**).
2. Failures do **not** abort the mutation — successful occurrences still commit and publish.
3. **After** `mutate` completes (state committed, invariants checked, batch published), if
   `failures` is non-empty, invoke `onPlanError?.call(failures)`.

`PlanFailure` carries `planID`, `occurrence` (date), `error`. It means an occurrence failed
validation (e.g. template pointing at a purged account) — distinct from a plan silently reaching
its `endDate`, which is expected and reported nowhere.

The injected `calendar` is the **fixed UTC calendar** (per `plans_and_accounting.md` §3.3 /
master plan §4.1 occurrence-identity decision) — everywhere: boot-time, lifecycle-resumed (§5.3),
and post-plan-creation calls. Never a device-local calendar, which would re-create the
timezone-dependent occurrence ids that decision kills.

`onPlanError` is a nullable callback field set once at boot (§5.2). No error if unset.

---

## 2. EventBus

### 2.1 The guarantee (what Swift had to fight for)

Swift's `EventBus` is a `Mutex`-protected map of `AsyncStream` continuations with **unbounded**
buffers. `publish` synchronously snapshots the continuations and `yield`s to each — the yield
appends to each subscriber's buffer *inside the publish call*, in publish order. That design
exists to defeat Swift-concurrency Task reordering: if delivery hopped through Tasks, two rapid
publishes could reach a subscriber out of order, and persistence would apply an old upsert over a
new one (`laterUpsertWinsWhenBatchesArriveInOrder` is the pinning test).

The guarantee to preserve, verbatim:

- **Ordered:** every subscriber sees batches in exact publish order.
- **Lossless:** publishing before a subscriber starts *consuming* drops nothing (buffered).
  Subscribing **after** a publish misses that publish — subscription time is the cut, consumption
  time is not.
- **Atomic batches:** one `publish(list)` = one delivery of that whole list. Never flattened,
  never merged with another batch.
- **Fan-out:** every subscriber sees every batch.
- **Empty-batch suppression:** `publish([])` delivers nothing to anyone.

### 2.2 Dart spec

Per master doc §4.2: one `StreamController<List<LedgerChange>>.broadcast(sync: true)` — the
single-threaded event loop gives ordering for free, `sync: true` makes delivery happen inside
`publish` exactly like Swift's synchronous yield.

```dart
class EventBus {
  final _controller = StreamController<List<LedgerChange>>.broadcast(sync: true);

  void publish(List<LedgerChange> changes) {
    if (changes.isEmpty) return;          // empty-batch suppression
    _controller.add(changes);
  }

  Stream<List<LedgerChange>> subscribe() => _controller.stream;
}
```

Behavior contract for the Dart version:

| Contract point | Spec |
|---|---|
| Ordering | Listener callbacks run synchronously in `publish`, in publish order |
| Batch payload | The `List<LedgerChange>` is delivered as-is; a cascade lands atomically. Treat the list as immutable after publish (wrap in `List.unmodifiable` in debug if cheap) |
| Empty batch | `publish(const [])` is a no-op, no delivery |
| Subscribe | `listen()` on the broadcast stream; a new subscriber sees only batches published after its `listen` call |
| Unsubscribe | `StreamSubscription.cancel()`; subsequent publishes are not delivered to it. Mirrors Swift's `onTermination` cleanup |
| No subscribers | Publish is a silent no-op (broadcast controller discards) |

**Difference from Swift, accepted:** Swift buffers between `subscribe()` and the first `await`;
a Dart sync broadcast stream delivers only to *attached listeners*. This is fine because the
lossless-before-consumption property only ever mattered for Swift's `for await` startup latency,
which Dart doesn't have — `listen` attaches synchronously. **Wiring rule that preserves the
intent: every runtime subscriber (PersistenceProcessor, AnalysisCache) must call `listen` before
the first `mutate` is possible — i.e. during boot, before the `Ledger` is handed to the UI (§5.2
ordering enforces this).**

Reentrancy note (new hazard, Dart-specific): with `sync: true`, a subscriber callback runs inside
`mutate`. Subscribers must **never** call back into `Ledger.mutate` from their handler (Dart's
sync controller throws on reentrant `add` anyway). Neither ported subscriber does — keep it that
way; the handler's job is enqueue/bump-counter only.

---

## 3. AnalysisCache

Bus-driven cache of `Accounting.analysisItems(state)` so the Stats surface doesn't recompute a
full-ledger scan per frame.

### 3.1 State

| Field | Meaning | Exposure |
|---|---|---|
| `items` | Last computed `List<AnalysisItem>` | read-only; listeners notified on change |
| `revision` | Bus-driven input counter, +1 per delivered batch | read-only; observed by views to trigger `refresh` |
| `itemsRevision` | +1 each time `items` is replaced | read-only; downstream memo key (drill-downs etc. recompute only when this moves) |
| `lastComputed` | Highest revision a compute has been *started* for; initial `-1` | private |

Initial values: `items = []`, `revision = 0`, `itemsRevision = 0`, `lastComputed = -1`. Note the
initial `revision (0) != lastComputed (-1)` gap is deliberate: the **first** `refresh` always
computes even though no bus event has arrived yet (that's how the boot-loaded state gets its first
analysis pass).

### 3.2 `start(bus)`

Subscribes to the bus; each delivered batch bumps `revision` by exactly 1 (batch count, not change
count). Idempotent: a second `start` call is a no-op — one subscription, one bump per batch
(pinned by `startIsIdempotent`). Provide a `dispose()` cancelling the subscription (Swift used
`deinit`; Riverpod's `ref.onDispose` is the natural home).

### 3.3 `refresh(state)` — the generation guard

```
refresh(state):
  if lastComputed == revision: return          // no recompute when revision unchanged
  target = revision                            // capture the generation
  lastComputed = target                        // claim it BEFORE compute starts
  computed = await <off-main compute>(analysisItems(snapshot of state))
  if target != lastComputed: return            // a newer refresh started; discard stale result
  items = computed
  itemsRevision += 1
  notifyListeners()
```

Contract points, each load-bearing:

- **No recompute when revision unchanged.** Calling `refresh` twice with no intervening bus event
  computes once.
- **Claim-before-compute.** `lastComputed = target` is set synchronously before the async compute
  begins, so re-entrant `refresh` calls during an in-flight compute are no-ops unless `revision`
  moved again.
- **Stale-result discard.** If a newer `refresh` claimed a higher generation while this compute
  was in flight, the completed result is thrown away — `items` only ever moves forward.
- **`itemsRevision` bumps only on an accepted result**, never on a discarded one.
- `refresh` returns immediately (fire-and-forget); callers never await items.

### 3.4 Off-main compute and the snapshot problem

Swift ran the compute on a detached task and hopped back to `MainActor` to commit — and got a
free **value-copy snapshot** because `LedgerState` is a struct. Dart's `LedgerState` is a mutable
class (master doc §3), so the port must be explicit:

- **Native (mobile/desktop):** `Isolate.run(() => Accounting.analysisItems(state))`. The isolate
  send performs a deep copy of the captured state, which *is* the snapshot — a `mutate` landing
  mid-compute cannot corrupt the computation (its bus event bumps `revision`, and the follow-up
  `refresh` recomputes; the stale result is discarded by the guard).
- **Web:** no isolates — compute **synchronously** on the event loop (master doc §5 hazard 6;
  personal-scale data makes this fine). Synchronous compute reads live state, but since nothing
  can interleave during a synchronous call on a single-threaded runtime, it is still a consistent
  snapshot. The generation guard then trivially passes.

Gate on `kIsWeb` (or an injected `ComputeRunner` so tests can force either path).

**Main-thread contract (critique fix, made explicit here):** Swift's version had an implicit,
unenforced rule that `revision`/`lastComputed`/`items` are only touched on the main thread — the
critique flagged it. In Dart the single-threaded event loop **dissolves the hazard**: all cache
fields are touched only from event-loop turns (bus callback, `refresh` body, post-`await`
continuation); the isolate only ever receives a copy and returns a value. The contract still gets
stated in code (doc comment on the class: "all members event-loop-confined; the isolate never
sees `this`") and the interleaving tests in §7.2 pin the observable consequences.

---

## 4. PersistenceProcessor

The single pipe from bus to store. Total behavior — resist adding to it:

1. `start()`:
   - Subscribe to the bus **synchronously, immediately** (before any awaiting — this is what
     guarantees no mutation escapes persistence, given the §5.2 boot order).
   - `await store.start()` (spins up the store's ingest pipeline).
   - Forward every delivered batch to `store.enqueue(changes)` — as-is, same batch boundaries,
     no filtering, no coalescing (coalescing is the store's job, inside its debounce window).
2. `flush()` → `await store.flushNow()`. Pure passthrough. Contract inherited from the store:
   "everything enqueued before this call is on disk when it returns" (master doc §5 hazard 7).

In Dart the subscribe-then-await-start sequencing must preserve ordering: buffer batches that
arrive between `listen` and `store.start()` completing, or (simpler, preferred) make the Drift
store's `enqueue` safe to call before `start` by having `start` own the drain — decide in
implementation, but the observable contract is: **no batch published after `processor.start()`
returns is ever lost or reordered into the store.** With the §5.2 boot order (`start()` completes
before `Ledger` exists), the pre-start window contains only seed traffic already handled by the
store itself, so the simple version suffices — but the test `committedFactsReachTheStore`
publishes immediately after `start()` and must pass.

No unsubscribe in V1 (processor lives for the app's life). Add `dispose()` only if hot-restart
hygiene demands it.

---

## 5. Boot phase machine, lifecycle, banners (from `SpendWiseApp.swift`)

### 5.1 Phases

```
sealed class AppPhase {}
class Loading extends AppPhase {}
class Ready   extends AppPhase { final Ledger ledger; final PersistenceProcessor persistence; }
class Failed  extends AppPhase { final Object error; }   // UI offers retry
```

- `loading` → spinner (indeterminate progress).
- `ready` → root shell with the ledger injected; banner overlay active (§5.4).
- `failed(error)` → "Couldn't load your data" + the error description + **Retry** button.
  Retry sets phase back to `loading` and re-runs the whole boot sequence from scratch.

### 5.2 Boot order — exact, verified against `AppRootView.start()`

1. Create the store (Swift: `ModelContainer` + `SwiftDataLedgerStore`; Dart: Drift database +
   `DriftLedgerStore`). Any throw here → `failed`.
2. `store.setErrorHandler(handler)` — wired **before** seeding, so a failing seed save already
   surfaces through the save banner.
3. `store.seedIfFirstLaunch(sampleSeedChanges)` — see §6.
4. `state = await store.load()` — throw → `failed`.
5. Create the `EventBus`.
6. Create `PersistenceProcessor(store, bus)`; call `processor.start()`.
7. Create `Ledger(state, bus)`.
8. Wire `ledger.onPlanError = showPlanError`.
9. Phase → `ready(ledger, processor)`.

Ordering rationale (do not shuffle): the processor subscribes at step 6, the `Ledger` exists only
from step 7, so **every** mutation ever published has a persistence subscriber attached — the
Dart sync-broadcast "no buffering" difference (§2.2) is thereby harmless. `AnalysisCache.start`
joins the bus at provider initialization, which must likewise complete before the first mutate
(Riverpod wiring, §8).

Any step throwing lands in `failed(error)` — there is no partial-ready state.

### 5.3 Lifecycle hooks

Swift switched on `scenePhase`, guarded on `ready`. Dart: `AppLifecycleListener` (master doc
§4.3), same guard — do nothing unless phase is `ready`.

| Event | Swift | Flutter | Action |
|---|---|---|---|
| App becomes active | `.active` | `onResume` (and initial ready — see note) | `ledger.resolvePlans()` |
| App leaves foreground | `.background`, `.inactive` | `onInactive` / `onPause` (and `onHide` on desktop) | `persistence.flush()` (fire-and-forget async) |

Note: iOS fires an initial `scenePhase → .active` after launch, but that transition races the
async boot and is usually swallowed by the `ready` guard — V1 frequently does **not** resolve
plans on a cold start (they materialize on the next foregrounding). Flutter does not fire
`onResume` for the initial launch either — call `ledger.resolvePlans()` once explicitly when
entering `ready`, then rely on `onResume` for subsequent foregrounds. The explicit resolve on
entering `ready` fixes that latent V1 race — a flagged deviation, strictly more reliable. Every
`resolvePlans()` call here (initial-ready and `onResume` alike) passes the fixed UTC calendar
(§1.4) — never the device-local calendar.

`flush()` on backgrounding is the load-bearing durability moment (master doc §5 hazard 7): the
debounced store may hold a pending batch; backgrounding must push it to disk before the OS can
kill the process.

### 5.4 Banners

One banner slot overlaid at the bottom of the ready shell (Swift: capsule footnote text;
Flutter: a lightweight overlay/`SnackBar`-style widget — visual freedom, semantic parity).

**Displayed message = `planError ?? saveStateMessage`** — plan-error text takes precedence over
the save banner while both are active.

Save-state banner — driven by the store's error handler (`SaveBannerState`):

| State | Message |
|---|---|
| `clear` | *(no banner)* |
| `retrying` | "Couldn't save changes, retrying" |
| `failedWillRetry` | "Couldn't save changes, will retry shortly" |

The banner text tracks the state; it clears when the store reports `clear` (per master doc §4.3,
the Drift store only reports `clear` after a non-clear state — critique fix).

Plan-error banner — driven by `onPlanError(failures)`:

- Message is **count-aware over distinct plan IDs**, not failure count:
  - 1 plan → "A recurring plan couldn't add its entry"
  - n plans → "n recurring plans couldn't add their entries"
- Auto-dismisses after **4 seconds**.
- **Re-fire cancels the pending dismissal** and starts a fresh 4 s window (Swift cancelled the
  prior dismissal `Task`; Dart: cancel the previous `Timer` before arming a new one). A cancelled
  dismissal must not clear the newer message.

### 5.5 Flutter wiring

Boot state lives in a Riverpod provider (e.g. an `AsyncNotifier<(Ledger, PersistenceProcessor)>`
or a hand-rolled `Notifier<AppPhase>` — hand-rolled preferred so `failed` keeps the retry
affordance explicit). `AppLifecycleListener` is owned by the root widget (or the notifier via
`WidgetsBinding`), and only acts when the phase provider is `ready`. Banner state
(`SaveBannerState`, `planError` string, its timer) is a small root-level notifier fed by the two
callbacks wired at boot.

---

## 6. Sample data + seeding contract (`Ledger+Sample.swift`)

### 6.1 The seeding contract

`store.seedIfFirstLaunch(changes)`:

- Gated on the store-meta **`hasSeeded` flag — NOT on emptiness.** A user who deletes everything
  is not re-seeded. (Verified: `SwiftDataLedgerStore.seedIfFirstLaunch` checks `meta.hasSeeded`,
  never `isEmpty`.)
- On first launch: set `hasSeeded = true` **first**, then `enqueue(changes)`, then
  `await flushNow()` — the seed is fully on disk before `load()` runs, and a crash mid-seed does
  not cause a double-seed on next boot (partial seed is the accepted worst case).
- Seed changes are produced by building the sample dataset **through the real Ledger mutation
  APIs** into a fresh `LedgerState` (throwaway in-memory bus), then serializing the final state
  via `seedChanges`: every money source, category, entry, and plan as an upsert change (order:
  moneySources, categories, entries, plans — order is irrelevant to replay, but keep it). Building
  through the real APIs guarantees the seed satisfies the same invariants as user-entered data.
- The Dart seed builder **asserts/throws in debug** (master plan §4.3 decision). Swift's
  `Ledger.sample()` swallowed failures via `try?`, so a validation tightening could silently thin
  the seed — a seed regression must be loud.

### 6.2 Sample dataset (port faithfully; dates relative to `today`)

All construction uses the calendar helpers `day(offset)` = today ± days and
`month(offset, day: d)` = today shifted by months with day-of-month set to `d` (use the clamped
month-add helper from master doc §5 hazard 1). Deliberate deviation: Swift's
`calendar.date(bySetting: .day, ...)` searches **forward** and can leave the target month (today
= Aug 30: `month(-1, day: 25)` → Aug 25, not Jul 25); the clamped helper stays in the shifted
month, so seed dates may differ from V1 for runs late in the month.

Accounts (3):
- "DBS Checking" — checking
- "OCBC Savings" — savings, with 2 pockets: "Emergency Fund", "Holiday"
- "Amex Card" — card, `statementDay: 15`

Opening balances, all dated `month(-2, day: 1)`: checking 5000, savings 1200, Emergency Fund
8000, Holiday 650.

Categories (6): expense roots Groceries (`#34C759`, cart), Dining (`#FF9500`, fork.knife),
Transport (`#5856D6`, tram.fill); income root Salary (`#007AFF`, dollarsign.circle); Groceries
children Supermarket (`#30D158`, cart.fill) and Fresh Market (`#63E6BE`, carrot.fill) — the
children exist so the Stats drill-down has a breakdown. Symbols are SF Symbol names — run them
through the icon mapping table (master doc §5 hazard 4).

Entries (15):

| When | Amount | Name | Category | Source → Dest |
|---|---|---|---|---|
| day(0) | +3200 | Monthly salary | Salary | checking |
| day(0) | −42.50 | FairPrice groceries | Supermarket | card |
| day(0) | −3.20 | MRT to work | Transport | card |
| day(0) | +500 | To savings | *(transfer, no category)* | checking → savings |
| day(−1) | −28.90 | Dinner with friends | Dining | card |
| day(−1) | −18.60 | Tekka wet market | Fresh Market | checking |
| day(−1) | −12.40 | Cold Storage | Groceries | checking |
| day(−2) | −6.80 | Grab home | Transport | card |
| day(−2) | −55.00 | Lunch at Maxwell | Dining | card |
| month(−1, 25) | +3200 | Monthly salary | Salary | checking |
| month(−1, 18) | −74.20 | Weekly groceries | Groceries | card |
| month(−1, 12) | −18.00 | Grab to airport | Transport | card |
| month(−1, 5) | −96.50 | Birthday dinner | Dining | card |
| month(+1, 3) | −1200 | Rent | *(uncategorized)* | checking |
| month(+1, 8) | −33.40 | Cold Storage | Groceries | card |

Plans (2), both monthly, both with `lastResolvedDate` = anchor so they do not backfill on first
resolve:
- Netflix: −19.98, Dining, card, anchor `month(0, day: 20)`
- Monthly salary: +3200, Salary, checking, anchor `month(0, day: 25)`

The dataset deliberately covers: transfer without category, uncategorized expense, subcategory
entries, prev/current/next-month spread (exercises month navigation and future entries), card vs
checking sourcing (exercises statement math), and two live plans.

---

## 7. Test inventory

### 7.1 Ported 1:1 from `EventDrivenTests.swift` (16 tests)

Port names and scenarios; replace Swift's `collect`/`eventually` async helpers with direct
expectations where Dart's synchronous delivery allows (most of these stop needing timeouts —
delivery happens inside `publish`).

**EventBus**

| Test | Pins |
|---|---|
| `subscriberReceivesPublishedBatch` | Basic delivery |
| `batchArrivesAtomicallyNotFlattened` | One publish = one list, contents intact |
| `ordersBatchesInPublishOrder` | 3 publishes arrive in order |
| `everySubscriberSeesEveryBatch` | Fan-out to 2 subscribers |
| `bufferingIsLosslessBeforeConsumptionStarts` | **Adapt:** Swift pinned buffer-before-consume; Dart pins "listen before publish loses nothing" — publish twice after `listen`, both arrive in order. Document the semantic shift in the test comment |
| `emptyBatchIsNotDelivered` | `publish([])` suppressed; next real batch is the first seen |

**Ledger publishing**

| Test | Pins |
|---|---|
| `mutationPublishesItsFacts` | `addAccount` → one `[upsertAccount]` batch |
| `cascadeMutationPublishesAllFactsInOneBatch` | `addPocket` → 1 batch, 2 changes (pocket + parent) |
| `rejectedMutationPublishesNothing` | Throwing `addEntry` emits no batch; next success is first batch |
| `sequentialMutationsPublishInOrder` | Two mutations, two ordered batches |

**PersistenceProcessor** (against `InMemoryLedgerStore`)

| Test | Pins |
|---|---|
| `committedFactsReachTheStore` | Publish after `start()` → `load()` shows both facts |
| `laterUpsertWinsWhenBatchesArriveInOrder` | Two upserts of same id → second wins (ordering through the pipe) |
| `ledgerMutationPersistsThroughTheBus` | End-to-end: `ledger.addAccount` → store |
| `flushCompletesWithoutLosingPriorFacts` | `flush()` returns; prior facts still loadable |

**AnalysisCache subscription**

| Test | Pins |
|---|---|
| `busEventBumpsRevision` | One batch → `revision + 1` |
| `startIsIdempotent` | Double `start`, one batch → `revision + 1` exactly |

### 7.2 New tests this module owes (beyond the Swift suite)

Per master doc (§4.2 generation guard, §5 hazard 6/7, §1 critique list) — Swift never unit-tested
`refresh`; Dart must, since the single-threaded runtime makes the interleavings deterministic and
therefore testable:

| Test | Pins |
|---|---|
| `refreshComputesOnFirstCallWithoutBusEvent` | Initial `revision(0) != lastComputed(-1)` → first refresh computes, `itemsRevision` → 1 |
| `refreshIsNoOpWhenRevisionUnchanged` | Second refresh with no bus event: no recompute, `itemsRevision` unchanged |
| `refreshRecomputesAfterBusEvent` | Bus batch → refresh recomputes |
| `staleComputeResultIsDiscarded` | Force the async path with a controllable compute runner: start refresh A, bump revision + start refresh B, complete A after B claimed — A's result discarded, `itemsRevision` bumped once by B, `items` = B's result |
| `itemsRevisionBumpsOnlyOnAcceptedResult` | Companion assertion to the above |
| `syncFallbackComputesInline` | Web path: injected sync runner → `items` populated when `refresh` returns |
| `reentrantMutateFromSubscriberThrows` (or is impossible by construction) | Documents the sync-broadcast reentrancy rule (§2.2) |
| `processorSubscribesBeforeStoreStartCompletes` | Batch published immediately after `processor.start()` returns is not lost (§4) |
| Boot-order integration test | Fake store: assert `setErrorHandler` → `seedIfFirstLaunch` → `load` call order; seed gated on `hasSeeded` not emptiness (seed once, delete all, reboot → no re-seed) |
| Plan-error banner unit tests | Distinct-plan-count message; 4 s auto-dismiss; re-fire cancels prior timer and the old timer cannot clear the new message |

The Swift **main-thread contract** tests the critique asked for are *not* ported as
thread-assertions — the single-threaded Dart runtime dissolves the contract (§3.4). What remains
testable is the observable half (stale-discard, no-double-compute), covered above; the
confinement itself is a one-line doc comment, not a test.

### 7.3 Provider/controller tests (critique #5)

First controller tests land in this phase: phase-machine notifier transitions
(`loading → ready`, `loading → failed → retry → ready`), and "mutate through the provider →
listeners notified" (§8) — using `InMemoryLedgerStore` and a real bus, no widgets.

---

## 8. Riverpod mapping (architectural, no widget code)

| Swift | Flutter |
|---|---|
| `@State phase` in `AppRootView` | `appPhaseProvider` — `Notifier<AppPhase>`, owns the boot sequence (§5.2) and retry |
| `.environment(ledger)` | `ledgerProvider` — exposes the `Ledger` from the `ready` phase; unavailable (guarded) otherwise |
| `@Observable Ledger` re-render | `Ledger.mutate` step 4 notifies; views watch a ledger-revision provider (a counter the Ledger bumps per successful mutate) or the Notifier itself — **one notification per mutate**, after publish |
| `@Observable AnalysisCache` | `analysisCacheProvider` — created in `ready` wiring, calls `start(bus)` on init, `dispose()` via `ref.onDispose`; Stats views watch `revision` to trigger `refresh(state)` and watch `items`/`itemsRevision` for results |
| `@Environment(\.scenePhase)` | `AppLifecycleListener` owned at the root, acting only when phase is `ready` (§5.3) |
| Banner `@State`s | Small root-level notifier holding `SaveBannerState` + `planError` + its timer, fed by the two callbacks wired at boot (§5.4) |

Rules:

- Views never receive `LedgerState`; they call query methods on `Ledger` (e.g. `categories(of:)`)
  or read derived providers.
- View models (per-screen controllers) become plain Riverpod notifiers taking `Ledger` (and
  `AnalysisCache` where relevant) via `ref` — compile-safe DI replacing `.environment`.
- The bus is internal wiring: only `PersistenceProcessor` and `AnalysisCache` subscribe. UI never
  touches the bus; it reacts to Riverpod notifications. Keep it that way — new subscribers need a
  reason strong enough to write into this doc.
- Provider dependency direction: `appPhase → (ledger, persistence, analysisCache, banners)`.
  Nothing below `appPhase` outlives a retry — a failed→ready cycle rebuilds the whole graph, so
  no subscriber survives with a stale bus reference.
