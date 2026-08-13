Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
both suites green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/persistence.md`, which is more detailed than the
specs in this change.

Depends on `add-ledger-runtime` — this implements the `LedgerStore` contract that change defines.

Use fake time (`package:clock` / `fake_async` or injected delays) for debounce and backoff tests, so
the suite never actually sleeps.

## 1. Replay in the domain

- [x] 1.1 Add `LedgerState.replaying(changes)` and `apply(changes)` in `packages/domain/`: a plain
      switch writing directly into the three maps plus plans. Upserts store by id, deletions remove
      EDIT: `apply` is an extension in the part file, `replaying` on the class, because Dart forbids
      named constructors in extensions
- [x] 1.2 No validation, no cascade, no invariant sweep — replay reconstructs already-validated data.
      Record the pocket-unlink consequence in a comment: the parent upsert rides the same stream
- [x] 1.3 Export from the barrel; extend `test/barrel_exports_test.dart`
      EDIT: no export line needed, `domain.dart:19` already exports `ledger_state.dart`
- [x] 1.4 Test: `replayInitRebuildsEquivalentState` — account, category and entry replay equal to a
      hand-built state
- [x] 1.5 Test: serialize a mutated state to upserts, replay, compare — round trip is identity
- [x] 1.6 Test: replaying a pocket deletion with no parent upsert leaves the parent's links untouched
      (pins the deliberate non-cascade)
      EDIT: written as a contrasting pair at `ledger_state_replay_test.dart:38` and `:50`, both
      building the parent link through `addAccount`/`addPocket`. The unlink lives in
      `_detachAndTombstonePocket`, reached through `purgePocket`, so the mutator half is
      `deletePocket` then `purgePocket`
- [x] 1.7 Confirm `dart analyze` and `dart test` are green; `packages/domain/pubspec.yaml` still has
      no `flutter:` key
- [x] 1.8 Rewire `app/test/support/in_memory_ledger_store.dart:99` `_apply` to call the domain's
      `apply`, and drop its now-false doc comment. Two copies of the switch will otherwise drift and
      the fake stops proving anything about the real store
      EDIT: `_drain` at :74 now mutates `_state` in place, since `apply` writes to the state's own
      maps, so `_state` became `final`. No test relied on the drain returning a fresh instance.
      Only two tests guard the delegation, both in `persistence_processor_test.dart`, so the fake's
      applied state has no direct test of its own
- [ ] 1.9 Test: give the fake's applied state a direct test. The delegation to the domain's `apply`
      is currently guarded only as a side effect of the persistence processor suite

## 2. Dependencies and schema

- [x] 2.1 Add `drift`, `sqlite3_flutter_libs`, `path_provider`; add `drift_dev` and `build_runner` as
      dev dependencies
- [x] 2.2 Define tables `accounts`, `sub_pockets`, `categories`, `entries`, `plans`, `store_meta`,
      mirroring the SwiftData rows one-for-one
- [x] 2.3 Flatten the entry template into `template_*` columns on the plan row
- [x] 2.4 Give every row `version_data BLOB` and `lifecycle INT`; store money as TEXT, never a float
      column
      EDIT: carried by a `SyncedRow` mixin. `store_meta` deliberately stays out, being device-local
- [x] 2.5 Reserve `entries.note TEXT` and the system-entry marker column now — unwritten by this
      change, but free today and a migration later
      EDIT: marker is `system_kind INTEGER` (0 opening, 1 adjustment, null user entry). The frozen
      Swift `SDEntry` has neither column, so both are port-only reservations rather than parity and
      they sit outside the domain `Entry` mapping. Group 3 must not round-trip them
- [x] 2.6 Generate the Drift code; confirm `flutter analyze` is at zero issues
      EDIT: `store_meta`'s single-row check is a table-level `customConstraints`, since the natural
      `integer().check(id.equals(0))` self-references the getter and trips `recursive_getters`
- [x] 2.7 Test (new): `schema_test.dart` reads the real DDL through `PRAGMA table_info` — money TEXT,
      version and lifecycle on the five synced tables, reserved columns nullable, flat template,
      `store_meta` rejecting a second row

## 3. Mappers

- [x] 3.1 Add row → domain and domain → row mappers for all five row types
      EDIT: drift's generated row classes collide with the domain names, so the generated file is
      imported as `rows`
- [x] 3.2 Unknown enum codes fall back to their documented defaults (account type other, category kind
      expense, lifecycle active, frequency monthly)
- [x] 3.3 A version vector that fails to decode raises — NOT an empty vector. An empty vector erases the
      row's causal history and becomes data loss once sync exists (`design.md`)
- [x] 3.4 Normalize ids to lowercase on the way in, per the project-wide id rule
- [x] 3.5 Test (port): `accountRoundTrips`, `pocketRoundTrips`, `categoryRoundTrips`, `entryRoundTrips`,
      `transferEntryRoundTrips`, `planRoundTrips`, `transferPlanRoundTrips`, `lifecycleRoundTrips`
- [x] 3.6 Test (new): Decimal-string precision round trip including negative and large values
      EDIT: `Decimal` normalizes `-15.50` to `-15.5`, so trailing zeros do not survive as text
- [x] 3.7 Test (new): epoch-ms date round trip across a DST boundary instant
      EDIT: round trips could not guard this at all. `Entry` and `RecurringPlan` re-normalize dates
      in their constructors, so swapping `startOfDayUtc` for `.toUtc()` passed every round trip on a
      UTC+08 machine. The read is now a public seam, `dayFromMillis` at `mappers.dart:51`, tested
      directly
- [x] 3.8 Test (new): lowercase-uuid normalization, and the out-of-range enum fallbacks
      EDIT: uppercasing sub-pocket ids on read is unobservable, not untested, since `Account`
      lowercases them in its constructor. The write side carries the assertion instead
- [x] 3.9 Test (new): `categoryParentIDImmutableOnUpsert` — an upsert with a changed parent does not
      move the stored parent id
      EDIT: the upsert path is `categoryUpsertRow`, not `categoryToRow`, which writes the incoming
      parent. Group 5 must call the former
- [x] 3.10 Ruled: `planToRow` keeps lifecycle as a parameter, where Swift pins the plan row to active
      in both init and update and so cannot tombstone a plan. Task 7.1 requires a delete to tombstone
      rather than issue a SQL `DELETE`, which Swift's shape makes unimplementable. Default is active,
      so Swift's behaviour is the default. Sanctioned deviation, user ruling

## 4. VersionVector

- [x] 4.1 Add `VersionVector` with `counters`, `bump(device)`, `dominates(other)`, `isConcurrent(other)`.
      Do NOT add merge — it belongs to the future sync engine
      EDIT: immutable and value-equal, so `bump` returns a new vector where Swift's was `mutating`
- [x] 4.2 Add the codec: encode as a UTF-8 JSON object of lowercase uuid → count, empty vector as `{}`.
      Decode both the normalized object form and Swift's flat alternating-array form
      EDIT: Swift's real wire form is a third shape neither this task nor the Swift read predicted.
      `JSONEncoder` degrades a `[UUID: UInt64]` dictionary to a flat array and encodes the struct,
      so stored data is `{"counters":[...]}` with uppercase uuids. Found by compiling and running
      the Swift struct. All three shapes decode, lowercasing on every path
- [x] 4.3 Add device identity in `store_meta`: a uuid v4 created once on first access, persisted, cached
      in memory thereafter
      EDIT: cached in an `Expando` keyed on the database, on the `Future` so concurrent first calls
      share one insert
- [x] 4.4 Test (port): `bumpIncrementsPerDevice`, `dominatesWhenEveryComponentIsGreaterOrEqual`,
      `concurrentWhenNeitherDominates`, `causalChainIsNotConcurrent`
- [x] 4.5 Test (new): the codec tolerance matrix, including a corrupt blob raising rather than emptying
      EDIT: an empty blob decodes to the empty vector rather than raising. Every unwritten row starts
      empty, so zero bytes mean no history yet and are not the corrupt case
- [x] 4.6 Test (new): `deviceIDStableAcrossStoreInstances` — reopening the same database keeps the id and
      continues the same counter

## 5. Write pipeline

- [x] 5.1 Add `DriftLedgerStore` implementing `LedgerStore`. Constants: 250 ms debounce, 2 retries,
      200 ms backoff
      EDIT: timers are injected through an `armTimer` seam. `FakeAsync` intercepts every timer and
      deadlocks on real drift I/O, so tests fire timers by hand. The suite never sleeps
- [x] 5.2 `enqueue` appends synchronously to an unbounded FIFO queue; the drain loop started by `start()`
      concatenates into `pending` in arrival order
- [x] 5.3 Each newly buffered batch cancels the armed debounce timer and starts a fresh 250 ms one
- [x] 5.4 Coalesce at save time: keep the last change per target id, preserving survivor order, across
      everything pending. Upserts and deletions share one keyspace
      EDIT: a survivor sits at the index of its last occurrence, not its first, so a1 a2 a3 a1
      applies as a2 a3 a1
- [x] 5.5 Save inside one transaction: record the raw pre-coalesce `taken` count, apply the coalesced
      list, bump each touched row's vector exactly once, commit. On success remove only the first
      `taken` elements — anything buffered during the save stays
- [x] 5.6 On failure roll back fully, report `retrying`, back off 200 ms, retry up to twice
- [x] 5.7 After the final failure report `failedWillRetry` AND schedule a timed re-flush. Never drop the
      pending batch (`design.md` — Swift waited passively for the next mutation)
- [x] 5.8 Serialize saves behind a single in-flight future; a requested save awaits the running one
- [x] 5.9 Report `clear` only after a non-clear state has been reported
      EDIT: a transition, not a latch. Reporting `clear` returns the store to the clear state, so a
      second healthy save stays silent
- [x] 5.10 Add the apply rules: upsert inserts when absent then updates; `deleteMoneySource` tries
      accounts then pockets; a delete for an absent id is a silent no-op
- [x] 5.11 Mutation-test the coalescing keyspace: give deletions their own keyspace and confirm
      `upsertThenDeleteInOneWindowAppliesOnlyDelete` dies. Restore from a file copy, never `git checkout`
      EDIT: a second mutation reversing survivor order survived the whole suite. The order test
      asserted final map contents, which are order-independent, so ordering had no guard at all.
      `drift_ledger_store_test.dart:235` now reads rowids back from SQLite and the mutation dies
- [ ] 5.12 Decide whether `debugPendingLength` and `debugSaveCycle()` stay public once groups 6 and 7
      land. They exist so tests can assert pending bookkeeping and race two saves directly

## 6. flushNow barrier

- [x] 6.1 Call `start()` defensively; it must be idempotent
- [x] 6.2 Push a barrier through the same ingest queue the batches ride and await it, so that on
      resumption every earlier batch is provably in `pending`
      EDIT: removing the barrier leaves the whole suite green and no test can distinguish it.
      `enqueue` drains synchronously here, so batches are already in `pending` by the time the flush
      awaits, where Swift's drain was an async stream that genuinely needed the barrier. Kept as
      defensive structure, since it holds the guarantee if the drain ever becomes async
- [x] 6.3 Cancel the armed debounce timer, then await any in-flight save
- [x] 6.4 Loop save cycles while `pending` is non-empty — this loop is the fix for Swift's single
      trailing flush, which could early-return with work still buffered
      EDIT: the first two versions of the loop test passed against a single trailing save. One extra
      batch never needs a second cycle, because it lands in pending before the flush awaits. The
      test now chains two batches through `onTransactionBegin` so each arrives mid-transaction of a
      different save, and fires no clock afterwards so no debounce can carry them
- [x] 6.5 Terminate the loop on a cycle that ends in `failedWillRetry`, so a flush cannot spin against a
      broken disk; the timed retry owns recovery
      EDIT: `_lastCycleGaveUp` resets at cycle start, not only on failure, or one earlier failure
      would disable the loop for every later flush
- [x] 6.6 Return without touching the database or reporting state when the store is already idle

## 7. Load, tombstones, seeding

- [x] 7.1 A delete change sets `lifecycle = tombstoned` and bumps the vector — never SQL `DELETE`
      EDIT: landed with group 5. `_tombstone` at `drift_ledger_store.dart:369`, delete cases at
      `:332-340`
- [x] 7.2 `load()` fetches rows where lifecycle is not tombstoned, maps to domain, builds upserts in the
      order accounts, pockets, categories, entries, plans, then returns `LedgerState.replaying(changes)`
      EDIT: `load()` at `:133` over `_loadChanges()` at `:84`. A `debugLoadChanges()` seam at `:81`
      exposes the ordered list, because asserting on `LedgerState` maps is order-independent and so
      cannot pin the ordering at all
- [x] 7.3 Storage errors during load propagate, so boot can show its retry screen
      EDIT: true for storage errors, NOT for a corrupt version vector. The row mappers never read
      `version_data` and `_loadChanges` never calls `versionFromRow`, so a corrupt vector loads
      silently and throws only on the next write to that row. `persistence.md:426-428` says it must
      surface as a load error. Deviation pinned by a test, unresolved — see 7.7
- [x] 7.4 Implement `seedIfFirstLaunch` against the persisted flag, per the `app-boot` contract
      EDIT: `:140`. The flag rides the save transaction rather than one of its own, per
      `persistence.md:454-462`, which the task line omitted. `_seedFlagPending` at `:75` is written
      inside `_runCycle`'s transaction at `:238` and cleared only after commit at `:253`. `:223` had
      to stop returning early on empty pending, or a zero-change seed would never write the flag
- [x] 7.5 Test (port): `loadReturnsWhatWasEnqueued`, `deleteChangeRemovesFromLoadedState`
- [x] 7.6 Test (new): `seedRunsOnceAndIsGatedByFlagNotEmptiness` — seed, wipe every row by raw SQL, boot
      again, confirm nothing is re-seeded
      EDIT: both high-risk tests were proved to bite by mutating the source. Swapping the accounts
      and pockets builders fails the ordering test at index 0; replacing the flag check with an
      emptiness check re-seeds the wiped database and fails the gating test
- [x] 7.7 Decide whether a corrupt version vector must fail `load()`. Ruled: it must not, and the
      spec claim is removed. Decoding every vector on every boot polices a field nothing reads until
      sync exists, and the retry screen cannot repair a corrupt blob, so the loud version gives an
      unfixable loop rather than a working app. Damage now surfaces on the write path. User ruling
- [ ] 7.9 DEFERRED past MVP, user ruling. `_runCycle` at `drift_ledger_store.dart:239` catches
      `on Object`, so an error that fails identically on every attempt retries twice, reports
      `failedWillRetry`, then retries on a timer forever behind a banner promising a recovery that
      cannot come, and the edit is never saved. Fixing it needs a terminal state on `SaveBannerState`
      at `ledger_store.dart:5`, whose three cases all imply recovery, plus a permanent-error class in
      the cycle and a test that corrupts a blob by raw SQL to trigger one.
      Deferred because the only permanent error reachable today is a corrupt version vector, which
      needs a bug in our own encode path to occur at all: SQLite's journal rules out torn writes,
      bit rot lands in a page rather than one blob, and the file is sandboxed. Redundancy was
      considered and rejected for the same reason, since a second copy of a blob our own code
      encoded wrong is wrong identically.
      Revisit when the save banner gets a UI, or the first time any other permanent error appears
      here. The `on Object` catch is the real gap and it is not vector-specific
- [x] 7.8 Closed, not a defect. `deviceID` resolves its `Future` once into an `Expando`, so a rolled
      back insert does not produce a second id: the same claimed id is returned and written by
      whichever attempt commits, and a discarded id was never written to any vector because the
      bumps rode the same rolled back transaction. What remains is that the cache can report an id
      whose meta row is not yet committed, so a write to `store_meta` must upsert rather than update.
      `_writeSeedFlag` at `:263` already does. The other two callers use the id only as a map key

## 8. Store suite against real SQLite

- [x] 8.1 Test (port): `enqueuedChangesPersistAcrossLoad`, `deleteTombstonesRowButHidesItFromLoad`,
      `coalescedUpsertsWriteLatestValue`, `planPersistsAndTombstonesAcrossLoad`,
      `rapidConflictingUpsertsPersistTheLastOne`, `flushNowPersistsAnEnqueueMadeMomentsBefore`,
      `debouncedFlushPersistsWithoutAnExplicitFlush`
      EDIT: four written at `drift_ledger_store_test.dart:791`, `:803`, `:828`, `:838`. The other
      three already existed from the groups that built the behaviour, one under a prose name:
      `rapidConflictingUpsertsPersistTheLastOne` is `rapid conflicting upserts store the last one`
      at `:182`, already looping to 50. Kept distinct from group 7's load tests, which assert replay
      correctness where these assert persistence across a load and the raw tombstone shape
- [x] 8.2 Test (new): `flushNowCoversBatchBufferedDuringInFlightSave` — pins the loop fix
- [x] 8.3 Test (new): `failedWillRetryEventuallyPersistsWhenStoreRecovers` — pins the timed retry, ending
      in a reported `clear`
- [x] 8.4 Test (new): `saveFailureRollsBackThenRetrySucceeds` — the rollback leaves no partial rows
      EDIT: `:279`, renamed from `a failed save rolls back leaving nothing partial` and extended.
      The old one enqueued a single row, so "no partial rows" and "no rows" were the same
      assertion and a save that never ran passed it. Now two tables, both empty after the failure
      and both filled after the retry
- [x] 8.5 Test (new): `clearReportedOnlyAfterNonClearState` — a happy path reports nothing at all
- [x] 8.6 Test (new): `upsertThenDeleteInOneWindowAppliesOnlyDelete`
- [x] 8.7 Each of 8.2–8.5 must fail against the Swift semantics. Verify that before moving on — a test
      that passes either way is not pinning the fix
      EDIT: all four mutations killed their test. Loop to `if` left a batch buffered; dropping
      `_armTimedRetry` armed no timer; moving the applies outside the transaction left the account
      behind without the entry; dropping the clear guard reported `[clear, clear]`. The tombstone
      counter-sum assertion was checked the same way, writing the vector unbumped, and it bites

## 9. Web target and close-out

- [x] 9.1 Wire the sqlite3 wasm path: `sqlite3.wasm` and `drift_worker.js` served from `web/`, opened
      with fallback handling
      EDIT: `openLedgerConnection` at `database_connection.dart:14` over a conditional import, with
      `database_connection_native.dart` and `database_connection_web.dart` behind it. A runtime
      `kIsWeb` branch cannot work here, unlike `analysis_cache.dart:27`, because `drift/native.dart`
      pulls `dart:io` and `dart:ffi` and so fails the web compile however it is guarded.
      `sqlite3.wasm` is the `sqlite3-3.5.1` release asset, not the devtools build inside the drift
      package, which embeds a different C library version
- [x] 9.2 Confirm `flutter build web` compiles the store
      EDIT: a plain build proves nothing yet. `main.dart` is still the stub and nothing imports the
      opener, so the first build never compiled it. Confirmed with a temporary entrypoint that
      imports it: 101.9s against 19.7s, web storage symbols present in the bundle and
      `NativeDatabase` absent
- [x] 9.3 Run `cd packages/domain && dart analyze && dart test` and `cd app && flutter analyze &&
      flutter test`. Analyzer at zero issues, not just zero errors
- [x] 9.4 Confirm no `double` money reached `app/lib/` or `packages/domain/lib/`
      EDIT: two hits, neither money. `accounting.dart:190` `fraction` takes two `Decimal` and returns
      a presentation ratio, matching Swift and adding a non-finite guard Swift lacks;
      `date_range.dart:4` is the words "double-count" in a comment
- [x] 9.5 Confirm the coverage map below is complete
      EDIT: all 22 Swift scenarios and every Dart-only addition map to a real test. Six looked
      missing to a verbatim name search and were false alarms, ported under the plain-language
      naming rule
Two findings from this group are UI and platform work, so they were filed where they will be done
rather than left open here: `storageIsDurable` has no consumer, now `add-app-shell-and-boot` 6.4;
the web opener has no test, now `add-release-targets` 5.4.

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
