Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app test suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ledger_runtime.md`, which is more detailed than the
specs in this change. Boot order is its §5.2 and must not be reordered.

Depends on `add-domain-accounting` — `AnalysisCache` computes `Accounting.analysisItems`.

## 1. Dependencies and scaffold

- [ ] 1.1 Add `flutter_riverpod` to `app/pubspec.yaml`; confirm `packages/domain/pubspec.yaml` still
      has no `flutter:` key
- [ ] 1.2 Create `app/lib/ledger/`, `app/lib/persistence/`, `app/lib/boot/`
- [ ] 1.3 Confirm `analysis_options.yaml` is strict-mode and `flutter analyze` is at zero issues

## 2. EventBus

- [ ] 2.1 Add `EventBus` over `StreamController<List<LedgerChange>>.broadcast(sync: true)`, with
      `publish(changes)` and `subscribe()`
- [ ] 2.2 Suppress empty batches in `publish` before touching the controller
- [ ] 2.3 Wrap the published list unmodifiable in debug so a subscriber cannot mutate a live batch
- [ ] 2.4 Test (port): `subscriberReceivesPublishedBatch`, `batchArrivesAtomicallyNotFlattened`,
      `ordersBatchesInPublishOrder`, `everySubscriberSeesEveryBatch`, `emptyBatchIsNotDelivered`
- [ ] 2.5 Test (adapted): `bufferingIsLosslessBeforeConsumptionStarts` — Swift pinned
      buffer-before-consume; Dart pins "listen before publish loses nothing". Record the semantic
      shift in the test's comment
- [ ] 2.6 Test: `reentrantMutateFromSubscriberThrows`, or document that construction makes it
      impossible

## 3. Ledger hub

- [ ] 3.1 Add `Ledger` owning a `LedgerState` and holding the bus; expose state read-only
- [ ] 3.2 Add the private `mutate` pipeline in exact order: domain mutator → debug invariant sweep →
      `bus.publish` → notify listeners. A throw from the mutator must skip all three later steps
- [ ] 3.3 Add the full mutation surface, one method per domain mutator, throwing where the domain
      throws. Do NOT add `restoreEntry`, `purgeEntry`, `restorePlan` or `purgePlan` — they do not
      exist in the domain
- [ ] 3.4 Add `categories(of: kind)`: active-and-matching only, roots by name each followed by its
      own children by name, orphaned children dropped. Ordinal `compareTo`, never locale collation
- [ ] 3.5 Add `resolvePlans(now, calendar)` and the settable `onPlanError` callback; failures are
      reported only after the successful changes commit and publish
- [ ] 3.6 Test (port): `mutationPublishesItsFacts`, `cascadeMutationPublishesAllFactsInOneBatch`,
      `rejectedMutationPublishesNothing`, `sequentialMutationsPublishInOrder`
- [ ] 3.7 Test: `categories(of:)` ordering including the dropped-orphan case
- [ ] 3.8 Test: partial plan-resolution failure still commits the successful occurrences and reports
      the failures afterwards
- [ ] 3.9 Mutation-test the pipeline order: publish before committing state, then notify before
      publishing. Each must kill a test. Restore from a file copy, never `git checkout`

## 4. Store contract and processor

- [ ] 4.1 Add the `LedgerStore` abstract contract: `load` / `start` / `enqueue` / `flushNow` /
      `setErrorHandler`, plus `SaveBannerState`
- [ ] 4.2 Add `InMemoryLedgerStore` as the test double
- [ ] 4.3 Add `PersistenceProcessor`: subscribe synchronously before any await, then `await
      store.start()`, forwarding every batch to `enqueue` as-is — no filtering, no coalescing
      (coalescing belongs to the store's debounce window)
- [ ] 4.4 Add `flush()` as a pure passthrough to `store.flushNow()`
- [ ] 4.5 Test (port): `committedFactsReachTheStore`, `laterUpsertWinsWhenBatchesArriveInOrder`,
      `ledgerMutationPersistsThroughTheBus`, `flushCompletesWithoutLosingPriorFacts`
- [ ] 4.6 Test: `processorSubscribesBeforeStoreStartCompletes` — a batch published immediately after
      `start()` returns is neither lost nor reordered

## 5. AnalysisCache

- [ ] 5.1 Add `AnalysisCache` with `items`, `revision`, `itemsRevision`, private `lastComputed`.
      Initial values `[]`, `0`, `0`, `-1` — the `revision`/`lastComputed` gap is deliberate and makes
      the first refresh compute
- [ ] 5.2 Add `start(bus)`: one subscription, `revision + 1` per delivered batch (batch count, not
      change count), idempotent on a second call; add `dispose()` cancelling it
- [ ] 5.3 Add `refresh(state)` with the generation guard: return when `lastComputed == revision`,
      else capture `target`, assign `lastComputed = target` **synchronously before** the compute,
      discard the result if `target != lastComputed` on completion, bump `itemsRevision` only on an
      accepted result. Fire-and-forget; callers never await
- [ ] 5.4 Add an injected `ComputeRunner` so tests force either path; native uses `Isolate.run`
      (the send-copy is the snapshot), web computes synchronously
- [ ] 5.5 Document on the class that all members are event-loop-confined and the isolate never sees
      `this`
- [ ] 5.6 Test (port): `busEventBumpsRevision`, `startIsIdempotent`
- [ ] 5.7 Test (new): `refreshComputesOnFirstCallWithoutBusEvent`, `refreshIsNoOpWhenRevisionUnchanged`,
      `refreshRecomputesAfterBusEvent`
- [ ] 5.8 Test (new): `staleComputeResultIsDiscarded` and `itemsRevisionBumpsOnlyOnAcceptedResult` —
      start refresh A, bump revision, start refresh B, complete A after B claimed; A's result is
      discarded and `items` holds B's
- [ ] 5.9 Test (new): `syncFallbackComputesInline` for the web path
- [ ] 5.10 Mutation-test the guard: claim `lastComputed` *after* the compute instead of before. If no
      test dies, the interleaving is untested

## 6. Boot, lifecycle, banners

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
- [ ] 6.7 Pass the fixed UTC calendar to every `resolvePlans` call — boot, resume, and post-plan-creation
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
