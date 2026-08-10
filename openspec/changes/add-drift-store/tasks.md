Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
both suites green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/persistence.md`, which is more detailed than the
specs in this change.

Depends on `add-ledger-runtime` — this implements the `LedgerStore` contract that change defines.

Use fake time (`package:clock` / `fake_async` or injected delays) for debounce and backoff tests, so
the suite never actually sleeps.

## 1. Replay in the domain

- [ ] 1.1 Add `LedgerState.replaying(changes)` and `apply(changes)` in `packages/domain/`: a plain
      switch writing directly into the three maps plus plans. Upserts store by id, deletions remove
- [ ] 1.2 No validation, no cascade, no invariant sweep — replay reconstructs already-validated data.
      Record the pocket-unlink consequence in a comment: the parent upsert rides the same stream
- [ ] 1.3 Export from the barrel; extend `test/barrel_exports_test.dart`
- [ ] 1.4 Test: `replayInitRebuildsEquivalentState` — account, category and entry replay equal to a
      hand-built state
- [ ] 1.5 Test: serialize a mutated state to upserts, replay, compare — round trip is identity
- [ ] 1.6 Test: replaying a pocket deletion with no parent upsert leaves the parent's links untouched
      (pins the deliberate non-cascade)
- [ ] 1.7 Confirm `dart analyze` and `dart test` are green; `packages/domain/pubspec.yaml` still has
      no `flutter:` key

## 2. Dependencies and schema

- [ ] 2.1 Add `drift`, `sqlite3_flutter_libs`, `path_provider`; add `drift_dev` and `build_runner` as
      dev dependencies
- [ ] 2.2 Define tables `accounts`, `sub_pockets`, `categories`, `entries`, `plans`, `store_meta`,
      mirroring the SwiftData rows one-for-one
- [ ] 2.3 Flatten the entry template into `template_*` columns on the plan row
- [ ] 2.4 Give every row `version_data BLOB` and `lifecycle INT`; store money as TEXT, never a float
      column
- [ ] 2.5 Reserve `entries.note TEXT` and the system-entry marker column now — unwritten by this
      change, but free today and a migration later
- [ ] 2.6 Generate the Drift code; confirm `flutter analyze` is at zero issues

## 3. Mappers

- [ ] 3.1 Add row → domain and domain → row mappers for all five row types
- [ ] 3.2 Unknown enum codes fall back to their documented defaults (account type other, category kind
      expense, lifecycle active, frequency monthly)
- [ ] 3.3 A version vector that fails to decode raises — NOT an empty vector. An empty vector erases the
      row's causal history and becomes data loss once sync exists (`design.md`)
- [ ] 3.4 Normalize ids to lowercase on the way in, per the project-wide id rule
- [ ] 3.5 Test (port): `accountRoundTrips`, `pocketRoundTrips`, `categoryRoundTrips`, `entryRoundTrips`,
      `transferEntryRoundTrips`, `planRoundTrips`, `transferPlanRoundTrips`, `lifecycleRoundTrips`
- [ ] 3.6 Test (new): Decimal-string precision round trip including negative and large values
- [ ] 3.7 Test (new): epoch-ms date round trip across a DST boundary instant
- [ ] 3.8 Test (new): lowercase-uuid normalization, and the out-of-range enum fallbacks
- [ ] 3.9 Test (new): `categoryParentIDImmutableOnUpsert` — an upsert with a changed parent does not
      move the stored parent id

## 4. VersionVector

- [ ] 4.1 Add `VersionVector` with `counters`, `bump(device)`, `dominates(other)`, `isConcurrent(other)`.
      Do NOT add merge — it belongs to the future sync engine
- [ ] 4.2 Add the codec: encode as a UTF-8 JSON object of lowercase uuid → count, empty vector as `{}`.
      Decode both the normalized object form and Swift's flat alternating-array form
- [ ] 4.3 Add device identity in `store_meta`: a uuid v4 created once on first access, persisted, cached
      in memory thereafter
- [ ] 4.4 Test (port): `bumpIncrementsPerDevice`, `dominatesWhenEveryComponentIsGreaterOrEqual`,
      `concurrentWhenNeitherDominates`, `causalChainIsNotConcurrent`
- [ ] 4.5 Test (new): the codec tolerance matrix, including a corrupt blob raising rather than emptying
- [ ] 4.6 Test (new): `deviceIDStableAcrossStoreInstances` — reopening the same database keeps the id and
      continues the same counter

## 5. Write pipeline

- [ ] 5.1 Add `DriftLedgerStore` implementing `LedgerStore`. Constants: 250 ms debounce, 2 retries,
      200 ms backoff
- [ ] 5.2 `enqueue` appends synchronously to an unbounded FIFO queue; the drain loop started by `start()`
      concatenates into `pending` in arrival order
- [ ] 5.3 Each newly buffered batch cancels the armed debounce timer and starts a fresh 250 ms one
- [ ] 5.4 Coalesce at save time: keep the last change per target id, preserving survivor order, across
      everything pending. Upserts and deletions share one keyspace
- [ ] 5.5 Save inside one transaction: record the raw pre-coalesce `taken` count, apply the coalesced
      list, bump each touched row's vector exactly once, commit. On success remove only the first
      `taken` elements — anything buffered during the save stays
- [ ] 5.6 On failure roll back fully, report `retrying`, back off 200 ms, retry up to twice
- [ ] 5.7 After the final failure report `failedWillRetry` AND schedule a timed re-flush. Never drop the
      pending batch (`design.md` — Swift waited passively for the next mutation)
- [ ] 5.8 Serialize saves behind a single in-flight future; a requested save awaits the running one
- [ ] 5.9 Report `clear` only after a non-clear state has been reported
- [ ] 5.10 Add the apply rules: upsert inserts when absent then updates; `deleteMoneySource` tries
      accounts then pockets; a delete for an absent id is a silent no-op
- [ ] 5.11 Mutation-test the coalescing keyspace: give deletions their own keyspace and confirm
      `upsertThenDeleteInOneWindowAppliesOnlyDelete` dies. Restore from a file copy, never `git checkout`

## 6. flushNow barrier

- [ ] 6.1 Call `start()` defensively; it must be idempotent
- [ ] 6.2 Push a barrier through the same ingest queue the batches ride and await it, so that on
      resumption every earlier batch is provably in `pending`
- [ ] 6.3 Cancel the armed debounce timer, then await any in-flight save
- [ ] 6.4 Loop save cycles while `pending` is non-empty — this loop is the fix for Swift's single
      trailing flush, which could early-return with work still buffered
- [ ] 6.5 Terminate the loop on a cycle that ends in `failedWillRetry`, so a flush cannot spin against a
      broken disk; the timed retry owns recovery
- [ ] 6.6 Return without touching the database or reporting state when the store is already idle

## 7. Load, tombstones, seeding

- [ ] 7.1 A delete change sets `lifecycle = tombstoned` and bumps the vector — never SQL `DELETE`
- [ ] 7.2 `load()` fetches rows where lifecycle is not tombstoned, maps to domain, builds upserts in the
      order accounts, pockets, categories, entries, plans, then returns `LedgerState.replaying(changes)`
- [ ] 7.3 Storage errors during load propagate, so boot can show its retry screen
- [ ] 7.4 Implement `seedIfFirstLaunch` against the persisted flag, per the `app-boot` contract
- [ ] 7.5 Test (port): `loadReturnsWhatWasEnqueued`, `deleteChangeRemovesFromLoadedState`
- [ ] 7.6 Test (new): `seedRunsOnceAndIsGatedByFlagNotEmptiness` — seed, wipe every row by raw SQL, boot
      again, confirm nothing is re-seeded

## 8. Store suite against real SQLite

- [ ] 8.1 Test (port): `enqueuedChangesPersistAcrossLoad`, `deleteTombstonesRowButHidesItFromLoad`,
      `coalescedUpsertsWriteLatestValue`, `planPersistsAndTombstonesAcrossLoad`,
      `rapidConflictingUpsertsPersistTheLastOne`, `flushNowPersistsAnEnqueueMadeMomentsBefore`,
      `debouncedFlushPersistsWithoutAnExplicitFlush`
- [ ] 8.2 Test (new): `flushNowCoversBatchBufferedDuringInFlightSave` — pins the loop fix
- [ ] 8.3 Test (new): `failedWillRetryEventuallyPersistsWhenStoreRecovers` — pins the timed retry, ending
      in a reported `clear`
- [ ] 8.4 Test (new): `saveFailureRollsBackThenRetrySucceeds` — the rollback leaves no partial rows
- [ ] 8.5 Test (new): `clearReportedOnlyAfterNonClearState` — a happy path reports nothing at all
- [ ] 8.6 Test (new): `upsertThenDeleteInOneWindowAppliesOnlyDelete`
- [ ] 8.7 Each of 8.2–8.5 must fail against the Swift semantics. Verify that before moving on — a test
      that passes either way is not pinning the fix

## 9. Web target and close-out

- [ ] 9.1 Wire the sqlite3 wasm path: `sqlite3.wasm` and `drift_worker.js` served from `web/`, opened
      with fallback handling
- [ ] 9.2 Confirm `flutter build web` compiles the store
- [ ] 9.3 Run `cd packages/domain && dart analyze && dart test` and `cd app && flutter analyze &&
      flutter test`. Analyzer at zero issues, not just zero errors
- [ ] 9.4 Confirm no `double` money reached `app/lib/` or `packages/domain/lib/`
- [ ] 9.5 Confirm the coverage map below is complete

## 10. Coverage map — `PersistenceTests.swift`

22 Swift scenarios across four groups, all new.

| Swift test | Ported by |
|---|---|
| bumpIncrementsPerDevice | 4.4 |
| dominatesWhenEveryComponentIsGreaterOrEqual | 4.4 |
| concurrentWhenNeitherDominates | 4.4 |
| causalChainIsNotConcurrent | 4.4 |
| loadReturnsWhatWasEnqueued | 7.5 |
| deleteChangeRemovesFromLoadedState | 7.5 |
| replayInitRebuildsEquivalentState | 1.4 |
| accountRoundTrips | 3.5 |
| pocketRoundTrips | 3.5 |
| categoryRoundTrips | 3.5 |
| entryRoundTrips | 3.5 |
| transferEntryRoundTrips | 3.5 |
| planRoundTrips | 3.5 |
| transferPlanRoundTrips | 3.5 |
| lifecycleRoundTrips | 3.5 |
| enqueuedChangesPersistAcrossLoad | 8.1 |
| deleteTombstonesRowButHidesItFromLoad | 8.1 |
| coalescedUpsertsWriteLatestValue | 8.1 |
| planPersistsAndTombstonesAcrossLoad | 8.1 |
| rapidConflictingUpsertsPersistTheLastOne | 8.1 |
| flushNowPersistsAnEnqueueMadeMomentsBefore | 8.1 |
| debouncedFlushPersistsWithoutAnExplicitFlush | 8.1 |

### Dart-only additions

| Test | Task | Why |
|---|---|---|
| flushNowCoversBatchBufferedDuringInFlightSave | 8.2 | Fixes Swift's early-returning trailing flush |
| failedWillRetryEventuallyPersistsWhenStoreRecovers | 8.3 | Fixes Swift's passive wait after a reported failure |
| saveFailureRollsBackThenRetrySucceeds | 8.4 | Swift never pinned the rollback |
| clearReportedOnlyAfterNonClearState | 8.5 | Fixes a banner flash for a problem that never happened |
| upsertThenDeleteInOneWindowAppliesOnlyDelete | 8.6 | Coalescing across change kinds was untested |
| Corrupt vector raises | 4.5 | Swift's `?? VersionVector()` was silent data loss |
| seedRunsOnceAndIsGatedByFlagNotEmptiness | 7.6 | Pins flag-gating rather than emptiness-gating |
| deviceIDStableAcrossStoreInstances | 4.6 | Vector continuity depends on it |
| categoryParentIDImmutableOnUpsert | 3.9 | Documented mapping quirk |
| Decimal / DST / uuid / enum-fallback round trips | 3.6, 3.7, 3.8 | Dart-specific mapping hazards |
| Replay round trip and non-cascade | 1.5, 1.6 | Replay is new code in the domain |
