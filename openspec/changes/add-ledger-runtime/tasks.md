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

- [ ] 6.0 BLOCKER for 6.2. The domain has no replay for `LedgerChange` — Swift has
      `LedgerState+Replay.swift`, Dart has nothing, confirmed by search across
      `packages/domain/lib/` (three comments mention the concept, no implementation). The test
      double hand-rolls one at `app/lib/persistence/in_memory_ledger_store.dart:83` and says so in
      its own comment. Task 6.2's `load` and Phase 4's Drift store both need a real one. Settle
      where it lives before starting 6.2: domain-side replay is the Swift shape and gives the
      invariant sweep something to validate, but it may belong to `add-drift-store` instead. A
      replay bypasses every mutator guard, so whichever side owns it needs its own validation pass
      and a user-visible error, never a silent skip
- [ ] 6.1 Add the `AppPhase` machine: sealed `Loading` / `Ready(ledger, persistence)` /
      `Failed(error)`. No partial-ready state
- [ ] 6.2 Implement the boot sequence in exactly this order: create store → `setErrorHandler` →
      `seedIfFirstLaunch` → `load` → create bus → create processor and `start()` → create `Ledger` →
      wire `onPlanError` → phase `ready`. Any throw lands in `failed`
- [ ] 6.3 Add retry from `failed`: back to `loading`, re-run the whole sequence
- [ ] 6.4 Add the seed builder: build the sample dataset through the real mutation API into a throwaway
      state, then serialize as upsert changes. Assert/throw in debug — never swallow a rejected row
- [ ] 6.5 Implement `seedIfFirstLaunch` gated on the persisted `hasSeeded` flag, NOT on emptiness. Set
      the flag first, then enqueue, then `flushNow` before `load`
- [ ] 6.6 Add `AppLifecycleListener`: resume → `resolvePlans`, inactive/pause/hide → `persistence.flush()`.
      Both guarded on `ready`. Also resolve once explicitly on entering `ready` — the platform fires no
      initial resume (flagged deviation, `design.md`)
- [ ] 6.7 Pass a UTC `now` to every `resolvePlans` call — boot, resume, and post-plan-creation. There
      is no calendar parameter to pass; see the note on 3.5
- [ ] 6.8 Add banner state: displayed message is plan-error before save-state. Save messages track the
      store's `SaveBannerState`
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
