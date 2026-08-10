# Persistence Module — Behavior Spec (Drift/SQLite)

**Scope:** `app/lib/persistence/` — `LedgerStore` contract, `InMemoryLedgerStore`, the Drift store,
schema, mapping, version vectors, seeding. Source of truth for every claim:
`../SpendWise-SwiftUI/SpendWise/Repository/Persistence/` (verified against code 2026-08-08).
Parent doc: `docs/Flutter_Port_Tech_Doc.md` (§4.3, §5 hazards 2/3/5/6/7, §1 defects 6–7 context).

This spec defines **expected behavior** of the Dart implementation. Two deviations from the Swift
original are deliberate and marked **PORT FIX** (§8): the `flushNow` early-return hole and the
dead-end `failedWillRetry` state. Everything else is behavior-for-behavior parity.

---

## 1. `LedgerStore` abstract contract

Swift source: `LedgerStore.swift` (protocol), consumed by `PersistenceProcessor` and app boot.

```dart
enum SaveBannerState { clear, retrying, failedWillRetry }

abstract class LedgerStore {
  Future<LedgerState> load();
  Future<void> start();
  void enqueue(List<LedgerChange> changes);      // fire-and-forget, non-async
  Future<void> flushNow();
  void setErrorHandler(void Function(SaveBannerState) handler);
}
```

| Member | Contract |
|---|---|
| `load()` | Reads all non-tombstoned rows, maps to domain, rebuilds a `LedgerState` by replaying upserts (§5). Throws on storage failure — boot shows the retry screen. Never called mid-session; it is a boot-time operation. |
| `start()` | Begins consuming the ingest queue. Idempotent — second call is a no-op. Must be safe to call from `flushNow()` (the Swift store calls `start()` defensively at the top of `flushNow`). |
| `enqueue(changes)` | Synchronous, non-blocking, callable from anywhere. Empty list is a no-op. Batches are ingested **in call order** (§4.1). Batch boundaries exist only on the ingest queue — `pending` is a flat ordered concatenation (§4.1) — and a batch carries no transactional meaning. |
| `flushNow()` | Barrier flush: *everything enqueued before the call is on disk when it returns* (§4.5). |
| `setErrorHandler(h)` | Registers the single banner callback. Handler must be invoked on the UI thread/zone (Swift hopped to `@MainActor`; in Dart, invoking from the event loop suffices — never from an isolate). Replacing the handler replaces it; there is no multicast. |

`SaveBannerState` semantics (names are the message, keep them):

| State | Meaning | When reported |
|---|---|---|
| `clear` | Last save succeeded, nothing outstanding | After a successful save. **PORT FIX:** report only when transitioning out of a non-clear state, not on every save (parent doc §4.3). Swift reported it on every success. |
| `retrying` | A save failed, an automatic retry is imminent | After each failed attempt while attempts remain (attempt < maxRetries). |
| `failedWillRetry` | All attempts in this flush cycle failed; data is still held in memory and will be retried | After the final failed attempt. **PORT FIX:** must actually schedule a retry (§8.2) — in Swift nothing was scheduled and the name lied unless another enqueue happened to arrive. |

### `PersistenceProcessor` (interface only — runtime module owns implementation)

The bridge from `EventBus` to the store. Contract, per `PersistenceProcessor.swift`:

- `start()`: subscribes to the bus, then (in order) awaits `store.start()`, then forwards every
  published `List<LedgerChange>` batch to `store.enqueue(batch)` as-is. No filtering, no batching
  of its own.
- `flush()`: delegates to `store.flushNow()`. Called by app lifecycle on `inactive`/`paused`.

### `InMemoryLedgerStore` (test double)

Swift source: `InMemoryLedgerStore.swift`. It deliberately mirrors the real store's ordered-ingest
shape so tests exercise the same arrival-order guarantee.

| Member | Behavior |
|---|---|
| Construction | Takes an optional initial `LedgerState` (defaults to empty). |
| `load()` | Returns the current in-memory state. Never throws. |
| `start()` | Begins draining the ingest queue into state via `LedgerState.apply` (§5). Idempotent. |
| `enqueue` | Queues the batch FIFO. Applied to state only by the drain loop (i.e., not before `start()`). |
| `flushNow()` | Calls `start()` defensively, then enqueues a barrier and awaits it — returns once every previously enqueued batch has been applied. No debounce, no persistence, no retry. |
| `setErrorHandler` | No-op. Never reports any banner state. |
| `applyForTesting(changes)` | Applies changes to state immediately, bypassing the queue (test setup helper). |
| `snapshot()` | Returns the current state (test assertion helper). |

In Dart the drain loop is a `StreamController`-fed async loop; the single-threaded event loop
already guarantees FIFO, but keep the queue + barrier structure so `flushNow` has identical
semantics to the real store and so the double stays honest.

---

## 2. Drift schema

The persistence model is **distinct from the domain model** — rows mirror `SDModels.swift` 1:1,
flattened exactly as SwiftData stored them. Never leak Drift row classes past the store.

Global column conventions (all decided here, recorded per parent doc §8):

| Concern | Decision |
|---|---|
| IDs | `TEXT` primary key, **lowercase** canonical uuid string (e.g. `"6f1a…-…"`). Normalize to lowercase at the store boundary — Swift's `UUID.uuidString` is uppercase; case mismatch is hazard §5.5. |
| Money (`Decimal`) | `TEXT`, canonical `Decimal.toString()` — sign, digits, `.` separator, no grouping, no currency. Never REAL. |
| Dates | `INTEGER`, **epoch milliseconds UTC** (`DateTime.toUtc().millisecondsSinceEpoch`). Recorded decision: Swift stored `Date` (an absolute instant); epoch millis preserves the instant exactly, sorts numerically, and avoids ISO8601 parse ambiguity. The parent doc's UTC-normalization rule (§5.3) applies to **occurrence identity in the domain** (date-only normalization before hashing), not to storage — the store persists the exact instant it is given. |
| Booleans | `INTEGER` 0/1 (Drift `boolean()`). |
| `version_data` | `BLOB`, UTF-8 JSON encoded version vector (§6). Every table except `store_meta` carries it. |
| `lifecycle` | `INTEGER`, `LifecycleState` raw value: `0 active, 1 archived, 2 referenceOnly, 3 tombstoned` (verified `LifecycleState.swift`). Every table except `store_meta` carries it. |
| ID lists | `TEXT`, JSON array of lowercase uuid strings. |

### `accounts` (mirrors `SDAccount`)

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | TEXT | no | PK, lowercase uuid |
| `name` | TEXT | no | |
| `type` | INTEGER | no | `AccountType` raw value: `0 cash, 1 checking, 2 savings, 3 card, 4 prepaid, 5 investment, 6 insurance, 7 other` |
| `sub_pocket_ids` | TEXT | no | JSON array of lowercase uuids; order not meaningful (domain holds a `Set`), treat as set on read |
| `incoming_transfers_as_expenses` | INTEGER | no | bool |
| `include_in_net_worth` | INTEGER | no | bool |
| `statement_day` | INTEGER | yes | 1–28, card accounts only; NULL otherwise |
| `version_data` | BLOB | no | §6 |
| `lifecycle` | INTEGER | no | |

### `sub_pockets` (mirrors `SDSubPocket`)

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | TEXT | no | PK, lowercase uuid — shares one id space with accounts (domain `MoneySource`), but a separate table, exactly as SwiftData did |
| `name` | TEXT | no | |
| `incoming_transfers_as_expenses` | INTEGER | no | bool |
| `version_data` | BLOB | no | |
| `lifecycle` | INTEGER | no | |

No parent pointer — parentage lives only in `accounts.sub_pocket_ids`, matching Swift.

### `categories` (mirrors `SDCategory`)

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | TEXT | no | PK, lowercase uuid |
| `name` | TEXT | no | |
| `kind` | INTEGER | no | `CategoryKind` raw value: `0 income, 1 expense` |
| `color_hex` | TEXT | no | e.g. `"#FF9500"` |
| `include_in_analysis` | INTEGER | no | bool |
| `parent_id` | TEXT | yes | lowercase uuid; NULL = top-level. Plain column, **no** FK constraint (SwiftData had none; referential integrity is the domain's job) |
| `symbol` | TEXT | no | SF Symbol name string — stored verbatim; remapping to Material icons is a UI concern (parent doc §5.4), the store never rewrites it |
| `version_data` | BLOB | no | |
| `lifecycle` | INTEGER | no | |

### `entries` (mirrors `SDEntry`)

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | TEXT | no | PK, lowercase uuid (deterministic v5 for plan-generated entries — generated upstream, opaque here) |
| `date` | INTEGER | no | epoch millis UTC |
| `amount` | TEXT | no | Decimal string; sign encodes income (+) vs expense (−) for non-transfers, transfers are positive |
| `name` | TEXT | no | |
| `category_id` | TEXT | yes | NULL for transfers and uncategorized |
| `source_id` | TEXT | no | |
| `destination_id` | TEXT | yes | non-NULL = transfer |
| `include_in_analysis` | INTEGER | no | bool |
| `note` | TEXT | yes | **Reserved, unused in V1** — always NULL until the V2 split wizard writes breakdowns here (locked prerequisite, parent doc §4.3 / gap-review B3). Distinct from `name`; nothing in the port reads or writes it |
| `system_kind` | INTEGER | yes | Synthetic-system-entry marker: `0 opening` ("Opening balance"), `1 adjustment` ("Balance adjustment"); NULL for user entries. The port still writes the English literals into `name` for parity — the marker travels alongside from day one so display-time naming/localization can later replace the persisted strings (parent doc §4.3 / §1 defect 9) |
| `version_data` | BLOB | no | |
| `lifecycle` | INTEGER | no | |

`note` and `system_kind` are **day-one schema reservations** with no `SDEntry` counterpart (parent
doc §4.3: free now, a migration later). They are not domain `Entry` fields and sit outside the §3
round-trip mapping.

### `plans` (mirrors `SDPlan` — `EntryTemplate` flattened into `template_*` columns)

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | TEXT | no | PK, lowercase uuid |
| `frequency` | INTEGER | no | `RecurrenceFrequency` raw value: `0 weekly, 1 biweekly, 2 monthly, 3 quarterly, 4 yearly` |
| `anchor` | INTEGER | no | epoch millis UTC |
| `end_date` | INTEGER | yes | epoch millis UTC |
| `last_resolved_date` | INTEGER | no | epoch millis UTC |
| `template_amount` | TEXT | no | Decimal string |
| `template_name` | TEXT | no | |
| `template_category_id` | TEXT | yes | |
| `template_source_id` | TEXT | no | |
| `template_destination_id` | TEXT | yes | |
| `template_include_in_analysis` | INTEGER | no | bool |
| `version_data` | BLOB | no | |
| `lifecycle` | INTEGER | no | Written as `active` (0) on every plan upsert — see §3 quirk |

There is no nested/JSON template object: five scalar `template_*` columns plus the bool, exactly as
`SDPlan` flattened it.

### `store_meta` (mirrors `SDStoreMeta`)

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | INTEGER | no | PK, fixed `0` with `CHECK (id = 0)` — enforces the single-row invariant Swift only had by convention (fetch-first) |
| `device_id` | TEXT | no | lowercase uuid v4, generated on first access, never changes |
| `has_seeded` | INTEGER | no | bool, default 0 |

No `version_data`, no `lifecycle` — meta is device-local and never syncs.

---

## 3. Domain ↔ row mapping

Swift source: `SDModels+Mapping.swift`. Three operations per table; keep all three distinct in the
Dart mapper (a Drift `Insertable` companion + a `toDomain()` on the row class):

| Operation | Swift | Contract |
|---|---|---|
| `init(from: domain)` | convenience init | Builds a **new** row from a domain value: copies every domain field, sets `version_data` to an **empty encoded vector** (the first `bump` happens in the write pipeline, §4.4 — a freshly inserted-and-saved row has exactly one counter at 1), sets `lifecycle` from the domain value's raw value. |
| `update(from: domain)` | `update(from:)` | Overwrites every domain-derived column on an **existing** row. Does **not** touch `id` and does **not** touch `version_data` (the pipeline bumps it separately). Lifecycle **is** overwritten from the domain value — an upsert of an archived account persists `lifecycle = 1`. |
| `toDomain()` | `toDomain()` | Rebuilds the domain value from columns. Total round-trip fidelity: `toDomain(rowFrom(x)) == x` for every domain field including lifecycle (pinned by mapping tests, §9). |

Field-level rules, verified against Swift:

- **Enum raw values** map by integer (§2 tables). Decoding an out-of-range raw value must not
  throw — fall back exactly as Swift did: `AccountType` → `other`, `CategoryKind` → `expense`,
  `RecurrenceFrequency` → `monthly`, `LifecycleState` → `active`. (Forward-compat: a future schema
  adding enum cases must not brick old readers.)
- **`sub_pocket_ids`**: domain `Set<String>` → JSON array (any order) on write; JSON array →
  `Set<String>` on read. Duplicates collapse silently.
- **Update column sets differ per table** — port them exactly:
  - `SDAccount.update` writes name, type, subPocketIDs, both bools, statementDay, lifecycle.
  - `SDSubPocket.update` writes name, incomingTransfersAsExpenses, lifecycle.
  - `SDCategory.update` writes name, kind, colorHex, includeInAnalysis, symbol, lifecycle —
    **not `parent_id`**. A category's parent is fixed at creation in Swift (`parentID` set only in
    `init(from:)`); the Dart mapper must preserve this: upserting an existing category never
    changes its stored `parent_id`.
  - `SDEntry.update` writes date, amount, name, categoryID, sourceID, destinationID,
    includeInAnalysis, lifecycle.
  - `SDPlan.update` writes frequency, anchor, endDate, lastResolvedDate, all six template columns,
    and **hard-codes `lifecycle = active`** (as does `SDPlan.init(from:)`). The domain
    `RecurringPlan` carries no lifecycle field; plan death is expressed only via `deletePlan` →
    tombstone. Keep this: every plan upsert writes lifecycle 0.
- **Version vector encoding/decoding** lives with the mapper (§6). Unlike the enum fallbacks above,
  vector decode failure **throws** — it surfaces as a load error, not an empty vector (§6, sanctioned
  deviation from Swift's decode-or-empty).

---

## 4. Write pipeline (Drift store)

Swift source: `SwiftDataLedgerStore.swift`. The Swift design used a nonisolated `AsyncStream`
ingest queue specifically to defeat actor reordering — yield is synchronous and ordered, so
**arrival order equals publish order**. Dart's single-threaded event loop gives that ordering for
free, but every observable behavior below is contract, not implementation detail.

Constants: `debounce = 250 ms`, `maxRetries = 2`, `retryBackoff = 200 ms`.

### 4.1 Ordered ingest

- `enqueue` appends the batch to an unbounded FIFO queue synchronously. Two `enqueue` calls made in
  sequence are buffered in that sequence, always. This is what makes last-write-wins coalescing
  correct (`rapidConflictingUpsertsPersistTheLastOne` test — 50 conflicting upserts, v50 lands).
- The drain loop (started by `start()`) moves batches from the queue into a `pending` buffer
  (`List<LedgerChange>`), concatenating batches in arrival order.

### 4.2 Debounce

- Each batch buffered into `pending` cancels the previous debounce timer and starts a fresh 250 ms
  one. When the timer fires uncancelled, it triggers a flush.
- A burst of edits therefore produces one save, ~250 ms after the last edit.

### 4.3 Coalescing

- At flush time, the pending snapshot is coalesced: **keep only the LAST change per `targetID`**,
  preserving the relative order of the survivors. (Swift: record last index per targetID, keep
  those indices, emit in original order.)
- Coalescing spans everything currently in `pending` (which may be several enqueue batches), not a
  single enqueue batch.
- Upserts and deletes coalesce in the same keyspace: upsert-then-delete of the same id within one
  window applies only the delete; delete-then-upsert applies only the upsert.
- Coalescing affects only what is **applied**; `pending` bookkeeping is by raw change count (§4.4).

### 4.4 Flush, retry, rollback

One flush cycle, restated runtime-neutrally from `performFlush`:

1. If `pending` is empty, return.
2. Record `taken = pending.length` (the raw, pre-coalesce count).
3. In **one SQLite transaction**: apply `coalesce(pending)` change-by-change (§4.6 apply rules,
   including a version bump per applied change), commit.
4. On success: remove the first `taken` elements from `pending` (anything buffered *during* the
   save stays for the next flush), report `clear` (subject to the transition-only rule, §1), done.
5. On failure: roll back the transaction (Drift transactions roll back automatically on throw —
   nothing partial may persist, matching `modelContext.rollback()`). If attempts remain
   (< maxRetries = 2 retries, so 3 attempts total): report `retrying`, wait 200 ms, go to 1
   (re-reading `pending`, which may have grown — the retry covers the grown buffer).
6. After the final failed attempt: report `failedWillRetry` and schedule the timed retry (§8.2).
   **The batch is never dropped** — `pending` still holds everything.

Flush execution is **serialized**: at most one flush cycle runs at a time. A flush requested while
one is in flight awaits the in-flight one (Swift kept a single `flushTask`; in Dart hold a single
`Future<void>?`). This matters even on a single-threaded runtime because the save and the backoff
sleep are awaits — a debounced flush and a `flushNow` can otherwise interleave and double-apply the
same `pending` prefix.

### 4.5 `flushNow` barrier contract

**Contract: everything enqueued before the call is on disk when it returns** (parent doc §5.7 —
mobile backgrounding is the moment that matters).

Sequence, restated from Swift and **PORT-FIXED** (§8.1):

1. Call `start()` defensively (idempotent).
2. Push a **barrier** through the same ingest queue the batches ride, and await it. When the
   barrier resumes, the drain loop is provably past every batch enqueued before the `flushNow`
   call — they are all in `pending`.
3. Cancel any armed debounce timer (the explicit flush supersedes it).
4. Await the in-flight flush, if any.
5. **Loop: while `pending` is not empty, run a flush cycle** (this loop is the fix — Swift ran a
   single trailing flush that could early-return, §8.1). A flush cycle that ends in
   `failedWillRetry` terminates the loop — `flushNow` does not spin forever against a broken disk;
   the timed retry (§8.2) owns recovery from there.

`flushNow` on an already-idle store (empty pending, no in-flight flush) returns without touching
the database and without reporting any banner state.

### 4.6 Apply rules (inside the save transaction)

Per coalesced change, in order:

| Change | Effect |
|---|---|
| `upsertAccount/Pocket/Category/Entry/Plan(v)` | Fetch row by id; if absent, insert `rowFrom(v)` (empty vector); then `update(from: v)` per §3; then bump the row's version vector (§6). Net: insert-then-save yields a vector with one counter at 1. |
| `deleteMoneySource(id)` | Try `accounts` first, then `sub_pockets` (one id space, two tables — account wins if somehow both exist). If found: tombstone (§5). If the id exists in neither table, the change is a silent no-op. |
| `deleteCategory(id)` / `deleteEntry(id)` / `deletePlan(id)` | Tombstone the row in the respective table if present; silent no-op if absent. |

Every applied change — upsert or tombstone — bumps the row's version vector exactly once.

---

## 5. Tombstones, `load()`, and replay

### Tombstone semantics

A delete change never issues SQL `DELETE`. It sets the row's `lifecycle = 3` (tombstoned) and bumps
the version vector. The row stays in SQLite forever (it is the sync engine's future deletion
record). Pinned by `deleteTombstonesRowButHidesItFromLoad`: after a delete, `load()` no longer
returns the entry, but a raw SQL fetch finds the row with `lifecycle = 3` and a vector whose
counters sum ≥ 1.

Note the two-layer meaning of lifecycle: the domain also uses `archived` (1) and `referenceOnly`
(2) as *live* states — rows in those states are stored and loaded normally. Only `tombstoned` (3)
is invisible to `load()`. The change stream only ever expresses tombstoning via `delete*` changes —
no domain path emits an upsert carrying `lifecycle = tombstoned` (purge flows emit
`deleteMoneySource`/`deleteCategory`, and domain invariant 10 guarantees no stored tombstoned value
ever rides an upsert payload). Because `update(from:)` writes the lifecycle column and `load()`
filters on it, the store would also handle such a hypothetical tombstoned upsert identically (row
persists, hidden from load) — acceptable defense in depth, not an expected flow.

### `load()`

1. Fetch all rows `WHERE lifecycle != 3` from `accounts`, `sub_pockets`, `categories`, `entries`,
   `plans`.
2. Map each to domain via `toDomain()`.
3. Build the upsert change list **in this order**: accounts, pockets, categories, entries, plans.
4. Return `LedgerState.replaying(changes)`.

Storage errors propagate (throw) — boot handles them with the retry screen.

### `LedgerState` replay (port of `LedgerState+Replay.swift`)

`LedgerState(replaying:)` = empty state + `apply(changes)`. `apply` is a plain switch that writes
**directly into the state's maps**:

| Change | Replay effect |
|---|---|
| `upsertAccount(a)` | `moneySources[a.id] = MoneySource.account(a)` |
| `upsertPocket(p)` | `moneySources[p.id] = MoneySource.pocket(p)` |
| `upsertCategory(c)` | `categories[c.id] = c` |
| `upsertEntry(e)` | `entries[e.id] = e` |
| `upsertPlan(pl)` | `plans[pl.id] = pl` |
| `deleteMoneySource(id)` | `moneySources.remove(id)` |
| `deleteCategory(id)` | `categories.remove(id)` |
| `deleteEntry(id)` | `entries.remove(id)` |
| `deletePlan(id)` | `plans.remove(id)` |

**Replay bypasses validation by design.** How: it never calls the `Ledger` mutators — no
`LedgerError` validation, no invariant sweep, no cascade logic runs. Specifically:

- `deleteMoneySource` on a pocket does **not** remove the id from the parent account's
  `subPocketIDs` — replay trusts that the original mutation emitted the parent-account upsert in
  the same change stream (the store persisted both, so load never sees the inconsistent half).
- Upserts overwrite unconditionally; no nesting/kind/reference checks.
- `assertInvariants()` is not run by replay itself. (Debug builds may sweep once after boot load;
  that is the runtime module's call, not the store's.)

Replay is shared by three consumers: `load()` rebuild, `InMemoryLedgerStore.apply`, and the seeding
path — implement it once on `LedgerState` in `domain`.

---

## 6. `VersionVector`

Swift source: `VersionVector.swift` + the codec in `SDModels+Mapping.swift`.

```dart
class VersionVector {
  Map<String, int> counters;            // deviceID (lowercase uuid) -> count
  void bump(String device);             // counters[device] = (counters[device] ?? 0) + 1
  bool dominates(VersionVector other);
  bool isConcurrent(VersionVector other);
}
```

| Operation | Contract |
|---|---|
| `bump(device)` | Increment that device's counter, creating it at 1 if absent. Counts are non-negative integers (Swift `UInt64`; Dart `int` is fine at personal scale, never negative). |
| `dominates(other)` | True iff for **every** device in `other.counters`, `this.counters[device] ?? 0 >= other's count`. Empty vector is dominated by everything; every vector dominates the empty vector; equal vectors dominate each other. |
| `isConcurrent(other)` | `!dominates(other) && !other.dominates(this)`. |
| Merge | **Deliberately absent.** Merge (per-device max + conflict surfacing via `isConcurrent`) is deferred to the future sync engine (parent doc §7.3). Do not add it during the port. |

### Bump policy (the store's side)

- **Every applied write bumps** the target row's vector exactly once — upserts **and** tombstones
  (a tombstone is a write the sync engine must be able to order).
- The bump uses this device's `device_id` from `store_meta` — created once (random uuid v4) on
  first access, persisted, cached in memory thereafter (§7).
- Bumps happen inside the save transaction; a rolled-back save leaves the stored vector untouched
  (the retry re-reads and re-bumps from the stored value).

### Encoding

Swift wire format (for the record, in case native data is ever migrated): `JSONEncoder` on a struct
whose only field is `counters: [UUID: UInt64]`. Because `UUID` is not a JSON-object key type in
Codable, Swift encodes the map as a **flat alternating array**:
`{"counters":["<UUID-UPPERCASE>",3,"<UUID2-UPPERCASE>",1]}`; empty vector = `{"counters":[]}`.
Encode failure produced empty `Data`; decode failure produced an empty vector.

Dart canonical format:

- **Encode:** UTF-8 JSON object mapping lowercase uuid → count: `{"6f1a…":3,"9c2e…":1}`. Empty
  vector encodes as `{}` (as bytes). Stored in `version_data BLOB`.
- **Decode:** recognizes exactly the two known wire formats: (a) the canonical object form; (b) the
  Swift alternating-array form above (uppercasing tolerated, keys lowercased on ingest). Anything
  else — empty blob, invalid UTF-8, invalid JSON, an unrecognized shape, a non-integer or negative
  count — is a **decode error, not an empty vector**. **PORT FIX** (sanctioned deviation, parent doc
  §4.3 / gap-review A13): Swift's `?? VersionVector()` fallback silently reset a row's causal
  history, which becomes data loss once the sync engine exists.
- **Failure surface:** a decode error is a **load error** — `load()` throws and boot shows the retry
  screen. Fail-the-load, not quarantine-the-row: chosen for now as the simplest and loudest option
  (a corrupt vector means the database is damaged; a quiet partial load would hide it).
- Round-trip test: encode → decode == identity for empty, single-device, and multi-device vectors.

---

## 7. Store meta and `seedIfFirstLaunch`

`store_meta` is a single row (fixed `id = 0`): `device_id` + `has_seeded`.

- **`device_id`**: read on first use; if the row does not exist, create it with a fresh random
  uuid v4 and `has_seeded = 0`, then cache the row in memory for the lifetime of the store. All
  version bumps use the cached value — no per-write meta query.
- **`has_seeded`** gates seeding **by flag, not by database emptiness**. A user who deletes all
  their data must not get re-seeded.

### `seedIfFirstLaunch(List<LedgerChange> changes)` contract

Restated from `SwiftDataLedgerStore.seedIfFirstLaunch`:

1. Read meta. If `has_seeded` is already true → return, doing nothing.
2. Set `has_seeded = true`.
3. `enqueue(changes)`.
4. `await flushNow()`.

In Swift, step 2 mutated the in-context meta row, so the flag and the seed rows committed
**atomically in the same `modelContext.save()`**. Drift must preserve that atomicity: the flag
update rides the same transaction as the first flush's save (implementation: mark the cached meta
dirty and write `store_meta` inside the §4.4 step-3 transaction). A crash before that save leaves
`has_seeded = 0` and no seed rows — next launch seeds again cleanly. Never write the flag in its
own earlier transaction (crash window would leave the flag set with no data).

### What the seed changes are (`LedgerState+SeedChanges.swift`)

The caller (boot, runtime module) builds a sample `LedgerState` and takes its `seedChanges`:

- `seedChanges` = upserts for the entire state, **in this order**: every `moneySources` value
  (accounts and pockets, via the `MoneySource`-dispatching upsert), then all `categories`, then all
  `entries`, then all `plans`. No deletes, ever. Iteration order within each map is unspecified —
  replay and the store are order-insensitive within a kind because ids never collide.
- `isEmpty` = all four maps empty (`moneySources`, `entries`, `categories`, `plans`). Kept as a
  domain helper; note it is **not** what gates seeding (the flag is).

Both are `LedgerState` members in `domain`, not store code.

---

## 8. Known defects — FIX in the port, do not copy

Parent doc §1 (critique v2, Cons 6 and 7). Both live in the Swift write pipeline; the port's
pipeline (§4) is specified with the fixes already applied. This section records what the Swift bug
was, what the fixed behavior is, and the test that pins each.

### 8.1 `flushNow` early-return hole (Con 6)

**Swift bug:** `flushNow` ran barrier → cancel debounce → await in-flight `flushTask` → one
trailing `flush()`. Two problems compound: (a) an in-flight `performFlush` captures
`taken = pending.count` *before* suspending on the save, so a batch buffered during that save is
not covered by it and stays in `pending`; (b) the trailing `flush()` begins with
`if let flushTask { await flushTask.value; return }` — if the debounce-initiated `flush()` wrapper
had not yet resumed to nil out `flushTask`, the trailing call awaited the already-finished task and
**returned without flushing the remainder**. Net effect: `flushNow` could return with covered
changes still in memory — a lie against the barrier contract, worst at the exact moment it matters
(app backgrounding).

**Fixed behavior (specced in §4.5):** after the barrier and after awaiting any in-flight flush,
`flushNow` **loops flush cycles until `pending` is empty** (or a cycle ends in `failedWillRetry`).
There is no code path where `flushNow` returns successfully with a non-empty `pending`.

**Pinning test** (`flushNowCoversBatchBufferedDuringInFlightSave`): start a flush whose save is
artificially slow (injectable executor/DB delay), `enqueue` a second batch while that save is
suspended, call `flushNow`, await it, then `load()` — the second batch's row must be present.
Under the Swift semantics this test loses the race; under the loop it cannot.

### 8.2 `failedWillRetry` schedules nothing (Con 7)

**Swift bug:** after `maxRetries` was exhausted, the store reported `failedWillRetry` and stopped.
Nothing was scheduled; the pending batch sat in memory until some future `enqueue` happened to arm
a new debounce. The banner text promised a retry that did not exist.

**Fixed behavior — timed retry, same backoff cadence:** when a flush cycle ends in
`failedWillRetry`, the store arms a retry timer at the existing `retryBackoff` cadence (200 ms).
When it fires, run a normal flush cycle (which itself carries 2 retries at 200 ms). Repeat until a
save succeeds. Rules:

- The retry timer is a singleton — a new `enqueue` (debounce) or `flushNow` while it is armed
  supersedes it (cancel it; the triggered flush covers the same `pending`).
- Banner stays `failedWillRetry` across failed timed cycles — do **not** flip back to `retrying`
  on timer-driven attempts; `retrying` is reserved for the intra-cycle attempts so the banner
  doesn't flicker. On eventual success report `clear` (transition rule, §1).
- `flushNow` does not await the timer: a cycle ending in `failedWillRetry` terminates the
  `flushNow` loop (§4.5); the timer owns recovery.

**Pinning test** (`failedWillRetryEventuallyPersistsWhenStoreRecovers`): inject a DB that fails the
first N saves then succeeds; enqueue, let the cycle exhaust to `failedWillRetry`, advance time, and
assert the data lands and the last reported state is `clear` — with **no** further `enqueue` calls.

---

## 9. Test inventory (parity with `PersistenceTests.swift`)

Swift ran the real store against an in-memory SwiftData container; Dart runs the Drift store
against **real in-memory SQLite** (`NativeDatabase.memory()`), per parent doc Phase 4. Same
scenarios, same names translated. Use fake time (`package:clock` / `fake_async` or injectable
delays) so debounce/backoff tests do not sleep; the Swift `eventually {…}` polling helper is only
needed where real async is exercised.

**VersionVector** (pure, in `test/` of the store package):

| Swift test | Asserts |
|---|---|
| `bumpIncrementsPerDevice` | Two bumps for A, one for B → counters {A:2, B:1} |
| `dominatesWhenEveryComponentIsGreaterOrEqual` | {A:3,B:2} dominates {A:3,B:1}; not vice versa |
| `concurrentWhenNeitherDominates` | {A:2,B:1} vs {A:1,B:2} concurrent both ways |
| `causalChainIsNotConcurrent` | bump-then-copy-then-bump: later dominates, not concurrent |

**InMemoryLedgerStore + replay:**

| Swift test | Asserts |
|---|---|
| `loadReturnsWhatWasEnqueued` | applyForTesting upserts → load returns them |
| `deleteChangeRemovesFromLoadedState` | apply delete after upsert → load lacks the source |
| `replayInitRebuildsEquivalentState` | `LedgerState.replaying([...])` equals hand-built state (account + category + entry) |

**Mapping round-trips** (row ↔ domain, no DB needed):

| Swift test | Shape exercised |
|---|---|
| `accountRoundTrips` | card account: subPocketIDs set, both bools non-default, statementDay 15 |
| `pocketRoundTrips` | incomingTransfersAsExpenses true |
| `categoryRoundTrips` | expense, non-nil parentID, includeInAnalysis false |
| `entryRoundTrips` | negative amount, categoryID set, includeInAnalysis false |
| `transferEntryRoundTrips` | destinationID set, nil category |
| `planRoundTrips` | monthly, endDate set, template flattening both ways |
| `transferPlanRoundTrips` | yearly, template destination set, nil endDate |
| `lifecycleRoundTrips` | referenceOnly account and archived category survive the round trip |

Dart additions here: Decimal-string precision round-trip (e.g. `-42.05`, large values), epoch-ms
date round-trip across a DST boundary instant, lowercase-uuid normalization, out-of-range enum
fallbacks (§3), version-vector codec tolerance matrix (§6).

**Drift store (real in-memory SQLite):**

| Swift test | Asserts |
|---|---|
| `enqueuedChangesPersistAcrossLoad` | enqueue account+entry, flushNow, load from same store → present |
| `deleteTombstonesRowButHidesItFromLoad` | delete entry → load lacks it, but raw SQL finds the row with lifecycle 3 and vector counter-sum ≥ 1 |
| `coalescedUpsertsWriteLatestValue` | two upserts of one category id in one batch → v2 persisted |
| `planPersistsAndTombstonesAcrossLoad` | plan upsert round-trips through load; deletePlan hides it |
| `rapidConflictingUpsertsPersistTheLastOne` | 50 sequential conflicting enqueues then flushNow → v50 wins (ordered-ingest guarantee) |
| `flushNowPersistsAnEnqueueMadeMomentsBefore` | fire-and-forget enqueue immediately followed by flushNow is on disk (barrier) |
| `debouncedFlushPersistsWithoutAnExplicitFlush` | start(), enqueue, no flushNow → persisted after debounce elapses |

Dart additions (new behavior + fixes):

| New test | Pins |
|---|---|
| `flushNowCoversBatchBufferedDuringInFlightSave` | §8.1 fix — the loop |
| `failedWillRetryEventuallyPersistsWhenStoreRecovers` | §8.2 fix — the timed retry, ends `clear` |
| `saveFailureRollsBackThenRetrySucceeds` | fail once → `retrying` reported, rollback leaves no partial rows, second attempt lands everything |
| `clearReportedOnlyAfterNonClearState` | happy-path saves report nothing; `clear` only after `retrying`/`failedWillRetry` |
| `upsertThenDeleteInOneWindowAppliesOnlyDelete` | coalescing across change kinds |
| `seedRunsOnceAndIsGatedByFlagNotEmptiness` | seed, wipe all rows (raw SQL), seed again → nothing; flag atomic with seed data |
| `deviceIDStableAcrossStoreInstances` | reopen same DB file/connection → same device_id, vector bumps continue the same counter |
| `categoryParentIDImmutableOnUpsert` | §3 quirk — upsert with changed parent does not move the stored parent_id |

**Web target note:** the Drift store must also run on web — sqlite3 wasm per the documented drift
recipe (`sqlite3.wasm` + `drift_worker.js` served from `web/`, `WasmDatabase.open` with fallback
handling). No pipeline behavior differs on web; CI should at minimum compile the store for web
(`flutter build web`) and ideally run the store suite once under `dart test -p chrome`. Parent doc
§5.6 also applies (no isolates on web — irrelevant to this module, which never uses them).
