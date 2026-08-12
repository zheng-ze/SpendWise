Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app test suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ledger_runtime.md`, which is more detailed than the
specs in this change. Boot order is its §5.2 and must not be reordered.

11 Aug: that doc carried a `resolvePlans(now, calendar)` signature in §1.2, §1.4 and §5.3 that the
domain never had. Corrected to the real one-argument `resolvePlans(now)`, with the fixed-UTC rule
rewritten as a caller-side obligation on `now`. See the note on 3.5.

Depends on `add-domain-accounting` — `AnalysisCache` computes `Accounting.analysisItems`.

## 1. Dependencies and scaffold

- [x] 1.1 Add `flutter_riverpod` to `app/pubspec.yaml`; confirm `packages/domain/pubspec.yaml` still
      has no `flutter:` key
- [x] 1.2 Create `app/lib/ledger/`, `app/lib/persistence/`, `app/lib/boot/`
- [x] 1.3 Confirm `analysis_options.yaml` is strict-mode and `flutter analyze` is at zero issues

## 2. EventBus

- [x] 2.1 Add `EventBus` over `StreamController<List<LedgerChange>>.broadcast(sync: true)`, with
      `publish(changes)` and `subscribe()`
- [x] 2.2 Suppress empty batches in `publish` before touching the controller
- [x] 2.3 Wrap the published list unmodifiable in debug so a subscriber cannot mutate a live batch
- [x] 2.4 Test (port): `subscriberReceivesPublishedBatch`, `batchArrivesAtomicallyNotFlattened`,
      `ordersBatchesInPublishOrder`, `everySubscriberSeesEveryBatch`, `emptyBatchIsNotDelivered`
- [x] 2.5 Test (adapted): `bufferingIsLosslessBeforeConsumptionStarts` — Swift pinned
      buffer-before-consume; Dart pins "listen before publish loses nothing". Record the semantic
      shift in the test's comment
- [x] 2.6 Test: `reentrantMutateFromSubscriberThrows`, or document that construction makes it
      impossible.
      EDIT 11 Aug: it is a real test, not a documented impossibility. Dart's sync controller throws
      `StateError: Cannot fire new event. Controller is already firing an event` and drops the
      reentrant batch, so `reentrantPublishFromSubscriberThrows` at
      `app/test/ledger/event_bus_test.dart:120` asserts both the type and the non-delivery
- [x] 2.7 Test `EventBus.dispose()`. It landed with group 2 ahead of its task because 5.2 and 7.1
      need a closable bus, but it is currently uncovered: assert a cancelled subscriber stops
      receiving, and that publishing after dispose throws rather than silently dropping.
      EDIT 11 Aug: `publishAfterDisposeThrows` was proven against a `dispose` that skips the close,
      and failed

## 3. Ledger hub

- [x] 3.1 Add `Ledger` owning a `LedgerState` and holding the bus; expose state read-only
- [x] 3.2 Add the private `mutate` pipeline in exact order: domain mutator → debug invariant sweep →
      `bus.publish` → notify listeners. A throw from the mutator must skip all three later steps
- [x] 3.3 Add the full mutation surface, one method per domain mutator, throwing where the domain
      throws. Do NOT add `restoreEntry`, `purgeEntry`, `restorePlan` or `purgePlan` — they do not
      exist in the domain
- [x] 3.4 Add `categories(of: kind)`: active-and-matching only, roots by name each followed by its
      own children by name, orphaned children dropped. Ordinal `compareTo`, never locale collation
- [x] 3.5 Add `resolvePlans(now)` and the settable `onPlanError` callback; failures are
      reported only after the successful changes commit and publish.
      EDIT 11 Aug: the domain is `PlanResolution resolvePlans(DateTime now)` at
      `ledger_state_plans.dart:58` — one parameter, no calendar argument anywhere in the package. It
      mutates `_entries` and `_plans` in place like every other mutator, but returns
      `PlanResolution{changes, failures}` rather than a bare change list, so the wrapper publishes
      `changes` and then hands `failures` to `onPlanError`. The fixed-UTC rule is therefore a
      caller-side obligation on `now`, not a parameter: pass a UTC instant, never a local
      `DateTime.now()`. Same correction applies to 6.7
- [x] 3.6 Test (port): `mutationPublishesItsFacts`, `cascadeMutationPublishesAllFactsInOneBatch`,
      `rejectedMutationPublishesNothing`, `sequentialMutationsPublishInOrder`
- [x] 3.7 Test: `categories(of:)` ordering including the dropped-orphan case
- [x] 3.8 Test: partial plan-resolution failure still commits the successful occurrences and reports
      the failures afterwards
- [x] 3.9 Mutation-test the pipeline order: publish before committing state, then notify before
      publishing. Each must kill a test. Restore from a file copy, never `git checkout`.
      Both mutations caught: publish-before-commit killed `stateIsCommittedBeforeTheBatchIsPublished`
      at `app/test/ledger/ledger_test.dart:132`, notify-before-publish killed
      `publishHappensBeforeListenersAreNotified` at `:121`

## 4. Store contract and processor

- [x] 4.1 Add the `LedgerStore` abstract contract: `load` / `start` / `enqueue` / `flushNow` /
      `setErrorHandler`, plus `SaveBannerState`
- [x] 4.2 Add `InMemoryLedgerStore` as the test double.
      EDIT 11 Aug: lives at `app/test/support/in_memory_ledger_store.dart`, not under `lib/`. It is
      a fake and nothing in `lib/` referenced it, so shipping it in the app bundle bought nothing.
      A boot-time non-Drift store, if group 6 wants one, is a different class
- [x] 4.3 Add `PersistenceProcessor`: subscribe synchronously before any await, then `await
      store.start()`, forwarding every batch to `enqueue` as-is — no filtering, no coalescing
      (coalescing belongs to the store's debounce window)
- [x] 4.4 Add `flush()` as a pure passthrough to `store.flushNow()`
- [x] 4.5 Test (port): `committedFactsReachTheStore`, `laterUpsertWinsWhenBatchesArriveInOrder`,
      `ledgerMutationPersistsThroughTheBus`, `flushCompletesWithoutLosingPriorFacts`.
      EDIT 11 Aug: `ledgerMutationPersistsThroughTheBus` now drives a real `Ledger` rather than
      publishing on the bus by hand, so the hub-to-store path is covered end to end. Added
      `rejectedLedgerMutationReachesNothing` alongside it, since a throwing mutator must reach
      neither the bus nor the store
- [x] 4.6 Test: `processorSubscribesBeforeStoreStartCompletes` — a batch published immediately after
      `start()` returns is neither lost nor reordered
- [x] 4.7 Test `PersistenceProcessor.dispose()`: a batch published after dispose does not reach the
      store, and a second dispose is harmless.
      EDIT 11 Aug: `disposeStopsForwardingToTheStore` was proven against a broken `dispose` with the
      `cancel()` removed, and failed. `disposeIsIdempotent` survives that break by design, since it
      pins only that a second call completes

## 5. AnalysisCache

- [x] 5.1 Add `AnalysisCache` with `items`, `revision`, `itemsRevision`, private `lastComputed`.
      Initial values `[]`, `0`, `0`, `-1` — the `revision`/`lastComputed` gap is deliberate and makes
      the first refresh compute
- [x] 5.2 Add `start(bus)`: one subscription, `revision + 1` per delivered batch (batch count, not
      change count), idempotent on a second call; add `dispose()` cancelling it
- [x] 5.3 Add `refresh(state)` with the generation guard: return when `lastComputed == revision`,
      else capture `target`, assign `lastComputed = target` **synchronously before** the compute,
      discard the result if `target != lastComputed` on completion, bump `itemsRevision` only on an
      accepted result. Fire-and-forget; callers never await
- [x] 5.4 Add an injected `ComputeRunner` so tests force either path; native uses `Isolate.run`
      (the send-copy is the snapshot), web computes synchronously
- [x] 5.5 Document on the class that all members are event-loop-confined and the isolate never sees
      `this`.
      EDIT 11 Aug: dropped on review as noise. The isolate boundary is documented where it is
      actually enforced, on `isolateComputeRunner`
- [x] 5.6 Test (port): `busEventBumpsRevision`, `startIsIdempotent`
- [x] 5.7 Test (new): `refreshComputesOnFirstCallWithoutBusEvent`, `refreshIsNoOpWhenRevisionUnchanged`,
      `refreshRecomputesAfterBusEvent`
- [x] 5.8 Test (new): `staleComputeResultIsDiscarded` and `itemsRevisionBumpsOnlyOnAcceptedResult` —
      start refresh A, bump revision, start refresh B, complete A after B claimed; A's result is
      discarded and `items` holds B's
- [x] 5.9 Test (new): `syncFallbackComputesInline` for the web path
- [x] 5.10 Mutation-test the guard: claim `lastComputed` *after* the compute instead of before. If no
      test dies, the interleaving is untested.
      EDIT 11 Aug: two tests died, `staleComputeResultIsDiscarded` and
      `itemsRevisionBumpsOnlyOnAcceptedResult`. Deferring the claim into the `then` callback defeats
      the guard for every out-of-order completion, not only same-generation reentrancy: each callback
      writes `lastComputed = target` and then tests `target != lastComputed`, which can never hold,
      so a callback can never reject its own result

## 6. Boot, lifecycle, banners

- [x] 6.0 Not a blocker. Resolved 11 Aug: `LedgerChange` replay defers to `add-drift-store`.
      Nothing replays a change log until a store reads one off disk, so building it here would be
      designed against a hypothetical. 6.2's `load` is unaffected — it calls `store.load()`, which
      returns a `LedgerState` under the existing contract, and the in-memory double already
      satisfies that at `app/test/support/in_memory_ledger_store.dart:30`. The double keeps its own
      `_apply`; that is a fake rebuilding fake state, not duplication of a real implementation.
      Carried to Phase 4: replay bypasses every mutator guard, so the Drift store's `load` needs a
      release-path validation and a user-visible error, never a silent skip or a debug-only
      `assert`. `assertInvariants` is deliberately snapshot-only for this caller
      (`packages/domain/lib/src/ledger_state_invariants.dart:4`) but every current call site wraps
      it in `assert`, so it validates nothing in release
- [x] 6.0a Add the seed surface to the `LedgerStore` contract. `app/lib/persistence/ledger_store.dart:12`
      has `load` / `start` / `enqueue` / `flushNow` / `setErrorHandler` and no seed member, but boot
      step 3 calls `seedIfFirstLaunch(changes)`. The `hasSeeded` flag lives in store-meta, which is
      Phase 4 storage, so Phase 3 owns the contract and the in-memory double's implementation only.
      Blocks 6.2 and 6.5.
      `seedIfFirstLaunch` at `app/lib/persistence/ledger_store.dart:16`, the double's implementation
      at `app/test/support/in_memory_ledger_store.dart:41`. Gating on emptiness instead of the flag
      was proven to fail `anEmptiedLedgerIsNotReseeded`
- [x] 6.1 Add the `AppPhase` machine: sealed `Loading` / `Ready(ledger, persistence)` /
      `Failed(error)`. No partial-ready state.
      EDIT 12 Aug: `Failed` carries an optional `StackTrace` alongside the error
      (`app/lib/boot/app_phase.dart:20`), which the spec does not mention. Kept because a boot
      failure with no trace is hard to diagnose
- [x] 6.2 Implement the boot sequence in exactly this order: create store → `setErrorHandler` →
      `seedIfFirstLaunch` → `load` → create bus → create processor and `start()` → create `Ledger` →
      wire `onPlanError` → phase `ready`. Any throw lands in `failed`.
      `load` needs no replay here: boot takes whatever `LedgerStore.load()` returns and hands it to
      the `Ledger`. The double returns its held state, empty unless a test supplies one. Rebuilding
      state from a change log is Phase 4's job, per 6.0.
      Landed at `app/lib/boot/app_boot.dart:34`. `Ledger`'s constructor defaults to building its own
      bus, so step 7 passes the step-5 instance explicitly at `:48`; dropping that argument was
      proven to fail three tests, the mutations reaching a bus nobody subscribed to. `AppBoot` takes
      `createStore` and `seedChanges` as injected callbacks, since Phase 3 has no real store and 6.4
      owns the seed builder. A throwing `seedChanges()` lands in `failed` rather than crashing boot
- [x] 6.3 Add retry from `failed`: back to `loading`, re-run the whole sequence.
      `retry()` at `app/lib/boot/app_boot.dart:72` delegates to `start()`, which opens with
      `_teardown()` at `:45` so it covers a retry over a live runtime as well as an overlapping
      second `start()`. Teardown flushes before disposing, since the spec never says a retry may
      discard pending writes
- [ ] 6.3a `_teardown` at `app/lib/boot/app_boot.dart:90` disposes the processor and the ledger but
      never the `EventBus` created at `:54`, so each retry leaks an unclosed `StreamController`.
      Bounded, not urgent: `PersistenceProcessor.dispose()` cancels the subscription first, so a
      stale ledger publishes into a bus nobody is listening to rather than into a live pipeline.
      `Ledger` holds the bus at `ledger.dart:20` and has no `dispose` override, so decide whether
      `Ledger.dispose()` should close the bus it was handed or `AppBoot` should hold its own
      reference and close it. A test that retries twice and asserts the first bus is closed is what
      would have caught this
- [x] 6.4 Add the seed builder: build the sample dataset through the real mutation API into a throwaway
      state, then serialize as upsert changes. Assert/throw in debug — never swallow a rejected row.
      Serialization reads the FINAL state, it does not collect the mutator returns: every money
      source, category, entry and plan as an upsert, ordered moneySources, categories, entries,
      plans. No `seedChanges` exists in the domain, so this needs writing. Swift splits it across
      `Ledger+Sample.swift` (builds) and `LedgerState+SeedChanges.swift` (serializes).
      EDIT 12 Aug: at `app/lib/boot/seed_data.dart`, `seedChanges` at :8 and `_serialize` at :27.
      The first cut of the loudness tests could not fail: both forced a collision on the first
      `addAccount`, so a builder that swallowed entry rejections still passed all 13. Now
      parameterized over mint index with `_CollidingIds`, one case per row type, and
      `theCollidingIdFactoryReachesEachRowTypeInTurn` at `app/test/boot/seed_data_test.dart:263`
      guards the indices so a reordered seed breaks the guard rather than skipping rows silently.
      The seed emits 19 `UpsertEntry` rows, not the 15 §6.2 names — the 4 opening balances are
      entries too, since `setOpeningBalance` builds one at `ledger_state_entries.dart:38`.
      Three §6.2 gaps settled 12 Aug, all leaving the landed code unchanged. The row count is a
      counting convention and the dataset is dummy data, so it need not track Swift exactly.
      `includeInAnalysis` keeps the domain defaults, `true` on entries and categories, `false` on
      the opening balances the domain writes itself. Seed ids stay random uuids per build, which is
      what real data looks like; `newID` is injectable at `app/lib/boot/seed_data.dart:8` for any
      test that needs fixed ones
- [x] 6.4a The seed dates need a `month(offset, day: d)` helper that clamps the day into the shifted
      month. `_addMonths` at `packages/domain/lib/src/plan_scheduling.dart:39` already clamps
      correctly but is private and only reachable through `RecurrenceFrequency.stepFrom`, which
      steps from an anchor and cannot set a day-of-month. A naive `DateTime.utc(y, m + offset, d)`
      overflows into the next month. This is the deviation `ledger_runtime.md` §6.2 flags: Swift
      searched forward and could leave the target month, so seed dates may differ from V1 late in
      the month.
      EDIT 12 Aug: landed in the domain as `monthWithDayUtc` at
      `packages/domain/lib/src/calendar_day.dart:6`, beside the `startOfDayUtc` rule it depends on.
      It shifts the month before applying the day, so the source day of month never decides which
      month comes back. Not merged with `_addMonths`, which preserves the anchor's time-of-day and
      non-UTC-ness for the local scheduling path; only the `_clampDay` arithmetic is duplicated, and
      unifying it is a separate task rather than a change smuggled through here.
      The clamp is unobservable through the seed: probing every day the dataset uses (1, 3, 5, 8,
      12, 18, 20, 25) against every month, no seed date differs between naive and clamped. The
      biting test therefore lives in the domain, `calendar_day_test.dart:16`, where
      `monthWithDayUtc(Mar 31, -1, day: 31)` gives Feb 28 against the naive Mar 3
- [x] 6.5 Implement `seedIfFirstLaunch` gated on the persisted `hasSeeded` flag, NOT on emptiness. Set
      the flag first, then enqueue, then `flushNow` before `load`.
      Landed with 6.0a rather than on its own, since the contract member and its only Phase 3
      implementation are the same edit. Gate at `app/test/support/in_memory_ledger_store.dart:42`,
      write order at `:46`, and boot calls it at `app/lib/boot/app_boot.dart:40` ahead of `load` at
      `:42`. Covered by four tests in `app/test/boot/seed_gating_test.dart`
- [x] 6.6 Add `AppLifecycleListener`: resume → `resolvePlans`, inactive/pause/hide → `persistence.flush()`.
      Both guarded on `ready`. Also resolve once explicitly on entering `ready` — the platform fires no
      initial resume (flagged deviation, `design.md`).
      EDIT 12 Aug: `AppBoot` mixes in `WidgetsBindingObserver` and implements
      `didChangeAppLifecycleState` at `app/lib/boot/app_boot.dart:75` rather than owning an
      `AppLifecycleListener`. A shape deviation from `ledger_runtime.md` §5.5, taken because the
      callback set is equivalent and tests drive it directly with no widget tree. 7.1 registers it
      with one `addObserver`/`removeObserver` pair. `detached` does nothing: the engine is already
      tearing down and a flush cannot be relied on to finish. The spec does not cover `detached`
- [x] 6.7 Pass a UTC `now` to every `resolvePlans` call — boot, resume, and post-plan-creation. There
      is no calendar parameter to pass; see the note on 3.5.
      EDIT 12 Aug: injected `DateTime Function()? now` on the constructor, defaulting to
      `DateTime.now().toUtc()` at `app/lib/boot/app_boot.dart:30`. Deliberately not normalized with
      `startOfDayUtc`: resolution reads an instant, and moving it to UTC midnight would drag the
      cursor back up to 24 hours and under-resolve occurrences due later the same day. Swift called
      `resolvePlans()` bare, taking a device-local `now` and `Calendar.current`, so this is the
      sanctioned PORT FIX rather than a translation. `theDefaultClockIsUtc` asserts `isUtc`, so it
      holds in any timezone and still fails if the `.toUtc()` is dropped
- [ ] 6.8 Add banner state: displayed message is plan-error before save-state. Save messages track the
      store's `SaveBannerState`. Displayed message is `planError ?? saveStateMessage`. The strings are
      `clear` no banner, `retrying` "Couldn't save changes, retrying", `failedWillRetry` "Couldn't save
      changes, will retry shortly". A store reports `clear` only after a non-clear state, so an opening
      `clear` is not a dismissal and must not clear a plan-error already showing
- [ ] 6.9 Add the plan-error banner: message counts **distinct plan ids**, not failures; auto-dismiss
      after 4 s; a re-fire cancels the pending timer and arms a fresh window, and the cancelled timer
      must not clear the newer message
- [ ] 6.10 Test: boot order against a fake store — `setErrorHandler` before `seedIfFirstLaunch` before
      `load`; seed once, delete everything, reboot, confirm no re-seed
- [ ] 6.11 Test: banner distinct-plan-count phrasing, the 4 s dismissal, and the re-fire cancellation

## 7. Riverpod wiring and close-out

- [ ] 7.1 Add providers for phase, ledger, persistence, analysis cache and banner state. `AnalysisCache.start`
      must join the bus at provider initialization, before the first mutate is possible
- [ ] 7.2 Add the first controller tests over the providers
- [ ] 7.3 Run `cd packages/domain && dart analyze && dart test` and `cd app && flutter analyze && flutter test`.
      Analyzer at zero issues, not just zero errors
- [ ] 7.4 Confirm no `double` money reached `app/lib/`
- [ ] 7.5 Confirm the coverage map below is complete

## 8. Coverage map — `EventDrivenTests.swift`

16 Swift tests, all new; `app/test/` is currently empty.

| Swift test | Ported by |
|---|---|
| subscriberReceivesPublishedBatch | 2.4 |
| batchArrivesAtomicallyNotFlattened | 2.4 |
| ordersBatchesInPublishOrder | 2.4 |
| everySubscriberSeesEveryBatch | 2.4 |
| emptyBatchIsNotDelivered | 2.4 |
| bufferingIsLosslessBeforeConsumptionStarts | 2.5 (adapted — see task) |
| mutationPublishesItsFacts | 3.6 |
| cascadeMutationPublishesAllFactsInOneBatch | 3.6 |
| rejectedMutationPublishesNothing | 3.6 |
| sequentialMutationsPublishInOrder | 3.6 |
| committedFactsReachTheStore | 4.5 |
| laterUpsertWinsWhenBatchesArriveInOrder | 4.5 |
| ledgerMutationPersistsThroughTheBus | 4.5 |
| flushCompletesWithoutLosingPriorFacts | 4.5 |
| busEventBumpsRevision | 5.6 |
| startIsIdempotent | 5.6 |

### Dart-only additions

| Test | Task | Why |
|---|---|---|
| refresh guard suite (5 tests) | 5.7, 5.8, 5.9 | Swift never unit-tested `refresh`; the single-threaded runtime makes the interleavings deterministic and therefore testable |
| processorSubscribesBeforeStoreStartCompletes | 4.6 | Dart's subscribe-then-await sequencing has no Swift equivalent |
| reentrantMutateFromSubscriberThrows | 2.6 | Hazard created by synchronous delivery |
| Boot-order integration test | 6.10 | Wiring order is what makes the no-buffering difference harmless |
| Banner tests | 6.11 | Swift covered these only by inspection |
