# Ledger Runtime

Last reconciled: 2026-09-02

## Feature overview

The app-layer runtime that wraps the domain: `Ledger` (the sole mutation hub), `EventBus`
(synchronous broadcast of change batches), `AnalysisCache` (a generation-guarded cache of analysis
items), `PersistenceProcessor` (the pipe from bus to store), the boot phase machine, the save/plan
banners, and first-launch seeding. These live in `app/lib/ledger/` and `app/lib/boot/`.

## Key files

- `app/lib/ledger/ledger.dart` — the only object permitted to touch `LedgerState`; every public
  method forwards to a domain mutator through `mutate`.
- `app/lib/ledger/event_bus.dart` — one `StreamController<List<LedgerChange>>.broadcast(sync: true)`.
- `app/lib/ledger/analysis_cache.dart` — bus-driven cache of `Accounting.analysisItems`, with a
  revision counter and a generation guard.
- `app/lib/persistence/persistence_processor.dart` — subscribes to the bus and forwards batches to
  the store.
- `app/lib/boot/app_boot.dart`, `app_phase.dart`, `banner_state.dart`, `providers.dart`,
  `seed_data.dart` — boot state machine, banner state, Riverpod wiring, and the sample dataset.
- `app/lib/ui/shell/status_banner.dart`, `storage_warning.dart` — the bottom status banner overlay.

## Module interactions

`Ledger.mutate` runs, in order: the domain mutator (throws `LedgerError` on rejection), the debug
invariant sweep, `bus.publish(changes)` as one atomic batch, then Riverpod listener notification
(`ledger.dart`). A cascade such as `addPocket` publishes the pocket upsert and the updated parent
account as one batch. A throwing mutator publishes nothing.

The bus is internal wiring subscribed by exactly two consumers: `PersistenceProcessor` and
`AnalysisCache`. UI never touches the bus; it reacts to Riverpod notifications. Every subscriber
must `listen` before the first `mutate` is possible — during boot, before the `Ledger` is handed to
the UI — because a sync broadcast stream delivers only to attached listeners (`persistence.md` §4).

`AnalysisCache.start(bus)` subscribes and bumps `revision` by one per delivered batch;
`refresh(state)` computes off the main isolate (or synchronously on web) under a generation guard
so a stale result is discarded when a newer refresh has already claimed a higher revision.

## Boot order

Exact and verified against `app_boot.dart`:

1. Create the store; any throw → `failed`.
2. `store.setErrorHandler(handler)` before seeding, so a failing seed save surfaces through the
   banner.
3. `store.seedIfFirstLaunch(sampleSeedChanges)`.
4. `state = await store.load()`; throw → `failed`.
5. Create the `EventBus`.
6. Create `PersistenceProcessor(store, bus)` and call `processor.start()`.
7. Create `Ledger(state, bus)`.
8. Wire `ledger.onPlanError = showPlanError`.
9. Phase → `ready(ledger, processor)`.

Any throwing step lands in `failed(error)`; there is no partial-ready state. Provider dependency
direction is `appPhase → (ledger, persistence, analysisCache, banners)`; nothing below `appPhase`
outlives a retry, so a failed→ready cycle rebuilds the whole graph.

## Boot phase machine

`AppPhase` is `loading` (spinner), `ready` (root shell with the ledger injected and the banner
overlay active), or `failed(error)` (headline "Couldn't load your data", error description, and a
Retry button that resets phase to `loading` and re-runs the whole boot).

## Lifecycle hooks

An `AppLifecycleListener` owned at the root acts only when phase is `ready`: on becoming active it
calls `ledger.resolvePlans(now)` with a UTC `now`; on leaving foreground it calls
`persistence.flush()` (fire-and-forget). `resolvePlans` is called once explicitly when entering
`ready` and on each `onResume`; every call passes a UTC instant, never a device-local
`DateTime.now()`. Backgrounding `flush()` is the load-bearing durability moment: it pushes the
debounced store's pending batch to disk before the OS can kill the process.

## `resolvePlans` + `onPlanError`

`resolvePlans(now)` runs `state.resolvePlans(now)` inside `mutate`; the materialized entries,
updated plan cursors, and retired-plan changes land as one batch. Failures do not abort the
mutation — successful occurrences still commit. After `mutate` completes, if failures are
non-empty, `onPlanError?.call(failures)` runs. `PlanFailure` carries `planID`, `occurrence`, and
`error` (an entry-validation failure, distinct from a plan silently reaching its `endDate`).

## Banners

One banner slot at the bottom of the ready shell. Displayed message is `planError ?? saveStateMessage`,
with plan error taking precedence. Save-state messages come from the store's error handler
(`persistence.md` §1): `retrying` → "Couldn't save changes, retrying"; `failedWillRetry` →
"Couldn't save changes, will retry shortly"; `clear` → no banner. Plan-error message is
count-aware over distinct plan IDs ("A recurring plan couldn't add its entry" / "N recurring plans
couldn't add their entries"), auto-dismisses after 4 seconds, and a re-fire cancels the prior
dismissal timer.

## Seeding contract

`store.seedIfFirstLaunch(changes)` is gated on the store-meta `hasSeeded` flag, never on database
emptiness — a user who deletes everything is not re-seeded. On first launch it sets `hasSeeded =
true` first, then `enqueue(changes)`, then `await flushNow()`, so the seed is on disk before
`load()` runs and a crash mid-seed does not double-seed. The seed changes are produced by building
the sample dataset through the real Ledger mutation APIs into a fresh `LedgerState`, then taking
`seedChanges` — every money source, category, entry, and plan as an upsert, in the order
moneySources, categories, entries, plans. The Dart seed builder asserts/throws in debug, unlike
Swift's `try?`, so a validation tightening thins the seed loudly. The sample dataset covers a
transfer without category, an uncategorized expense, subcategory entries, a prev/current/next-month
spread, card-vs-checking sourcing, and two live plans (`seed_data.dart`, `ledger_runtime.md` §6).

## Gotchas and invariants

- The initial `AnalysisCache.revision (0) != lastComputed (-1)` gap is deliberate: the first
  `refresh` always computes so the boot-loaded state gets its first analysis pass.
- `resolvePlans` has no calendar parameter; `ledger_state_plans.dart` works in fixed UTC, so the
  caller must pass a UTC `now` at boot, on resume, and after plan creation.
- With `sync: true`, a subscriber callback runs inside `mutate`; subscribers must never call back
  into `Ledger.mutate` (Dart's sync controller throws on reentrant `add`). Neither ported
  subscriber does.

## Requirements

- `Ledger` is the only object allowed to touch `LedgerState`; views never hold a `LedgerState`
  reference. (`ledger.dart`)
- Every mutation runs the four-step `mutate` pipeline; a throwing mutator publishes nothing.
  (`ledger.dart`, test `rejectedMutationPublishesNothing`)
- Every runtime subscriber subscribes to the bus before the first `mutate`. (`app_boot.dart` §5.2)
- Seeding is gated on `hasSeeded`, not emptiness, and the flag commits atomically with the seed
  data. (`persistence.md` §7)
- `resolvePlans` is called on entering `ready` and on resume, always with a UTC `now`.
  (`app_boot.dart` §5.3)
