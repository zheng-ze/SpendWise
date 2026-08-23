# Module Spec: Domain Models + LedgerState

**Module:** `domain` core. See `docs/ARCHITECTURE.md` for how this module fits the rest of the app.
**Source of truth:** this doc is the current behavior spec for the Dart implementation, covering
every model in `packages/domain/lib/` except `RecurringPlan`, `RecurrenceFrequency`, and
`OccurrenceID`, which belong to the plans module (`plans_and_accounting.md`).

This doc is a behavior spec: a Dart implementation written and tested against it must be
behavior-identical to what is described here, including §7's account-tombstone orphan fix.

## 0. Dart representation conventions

| Swift | Dart |
|---|---|
| `UUID` | `String`, lowercase normalized uuid form. Normalize to lowercase at every construction boundary |
| `Decimal` | `Decimal` from the `decimal` package. `double` never touches money |
| `Date` | `DateTime` (UTC discipline per master doc hazard 3; this module only stores dates, it does no date math) |
| enum with payload (`MoneySource`, `LedgerChange`, `LedgerError`) | sealed class hierarchy |
| plain `Int`-raw enum (`LifecycleState`, `AccountType`, `CategoryKind`, `Entry.Kind`) | plain Dart enum with an explicit `code` int field pinned to the Swift raw value. Never persist `enum.index` |
| `Set<UUID>` | `Set<String>` |
| `[UUID: X]` | `Map<String, X>` |
| struct value semantics | immutable-by-discipline classes (final fields where the Swift field is `let`, e.g. every `id` and `TransactionCategory.parentID`). `==`/`hashCode` value-based (`equatable` or hand-written) because the change-emission tests compare whole objects |
| `throws LedgerError` | `throw` a `LedgerError` (sealed class implementing `Exception`); tests match on the exact variant and payload |

`LedgerState` itself is a mutable class mutated in place, owned exclusively by `Ledger` (master doc §3). Mutators return `List<LedgerChange>`.

Type names stay identical to Swift: `LedgerState`, `LedgerChange`, `LedgerError`, `Entry`, `MoneySource`, `Account`, `SubPocket`, `TransactionCategory`, `LifecycleState`, `AccountType`, `CategoryKind`.

---

## 1. Types

### 1.1 LifecycleState

Enum, 4 states with pinned codes:

| State | Code | Meaning |
|---|---|---|
| `active` | 0 | Normal, visible, referenceable |
| `archived` | 1 | In the recycle bin. Restorable. Still name-resolvable |
| `referenceOnly` | 2 | Purged from the bin but kept because entries still reference it. Not restorable, not selectable, name still resolves |
| `tombstoned` | 3 | Gone. A tombstoned row is removed from the state tables in the same step, so this value never appears on a stored holder/category. It exists as a code for the persistence layer |

Derived getters: `isActive` (`== active`), `isVisibleReference` (`!= tombstoned`).

Entries only ever use `active` (delete is a hard delete). Holders and categories use `active / archived / referenceOnly`; `tombstoned` is a transition, not a resting state.

### 1.2 Entry

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `String` | new uuid | final |
| `date` | `DateTime` | now | |
| `amount` | `Decimal` | required | Signed. Income/opening inflow positive, expense negative. Stored transfers always positive (§3, normalization) |
| `name` | `String` | required | |
| `categoryID` | `String?` | `null` | Only on income/expense entries, never transfers (validator + invariant 6) |
| `sourceID` | `String` | required | A MoneySource id (account or pocket) |
| `destinationID` | `String?` | `null` | Non-null makes the entry a transfer |
| `includeInAnalysis` | `bool` | `true` | Opening-balance entries are created with `false` |
| `lifecycle` | `LifecycleState` | `active` | Always `active` in a stored state (invariant 9) |

Derived:

- `isTransfer` = `destinationID != null`.
- `kind` (`EntryKind` enum: `income | expense | transfer`): transfer if `isTransfer`, else `expense` when `amount < 0`, else `income` (zero is income by this formula, but zero amounts never pass validation).
- `expectedCategoryKind` (`CategoryKind?`): `income → CategoryKind.income`, `expense → CategoryKind.expense`, `transfer → null`.

Entry mixes in `HolderReferencing` (§1.8).

### 1.3 Account

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `String` | new uuid | final |
| `name` | `String` | required | |
| `type` | `AccountType` | required | |
| `subPocketIDs` | `Set<String>` | empty | Parent-to-child links. Owned by `addPocket` / holder tombstoning only, never by the edit surface (§3 `updateAccount`) |
| `incomingTransfersAsExpenses` | `bool` | `false` | Per-holder treat-as-expense flag, consumed by the accounting module |
| `includeInNetWorth` | `bool` | `true` | |
| `statementDay` | `int?` | `null` | Day of month the card statement cuts, valid range 1–28. Meaningful only when `type == card`, forced to `null` otherwise by `updateAccount` |
| `lifecycle` | `LifecycleState` | `active` | |

`AccountType` enum, pinned codes 0–7 in this order: `cash, checking, savings, card, prepaid, investment, insurance, other`.

Helpers: `addSubPocket(id)` inserts into `subPocketIDs`, `removeSubPocket(id)` removes.

### 1.4 SubPocket

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `String` | new uuid | final. Shares one id space with accounts (both live in `moneySources`) |
| `name` | `String` | required | |
| `incomingTransfersAsExpenses` | `bool` | `false` | |
| `lifecycle` | `LifecycleState` | `active` | |

Pockets have no type, no opening balance of their own, no `includeInNetWorth` (they roll into the parent), no statement day. A pocket knows nothing about its parent; the link lives only in the parent's `subPocketIDs`.

No opening-balance *field* — like accounts. `setOpeningBalance` (§3.2) accepts **any** holder including pockets; the sample seed and the balance-edit flow depend on it.

### 1.5 MoneySource

Sealed class, exactly two variants: `account(Account)` and `pocket(SubPocket)`. This is the value type stored in `LedgerState.moneySources`, giving accounts and pockets one table and one id space.

Uniform getters delegating to the wrapped value: `id`, `name`, `incomingTransfersAsExpenses`, `lifecycle`.
Downcast helpers: `asAccount` (`Account?`), `asPocket` (`SubPocket?`).
Needed internally: `settingLifecycle(LifecycleState)` returning a copy of the same variant with the lifecycle replaced.

### 1.6 TransactionCategory

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `String` | required | final |
| `name` | `String` | required | |
| `kind` | `CategoryKind` | required | `income` (0) or `expense` (1), pinned codes |
| `colorHex` | `String` | required | e.g. `"#FF8800"`. Stored verbatim (deliberate: color survives icon-set changes) |
| `includeInAnalysis` | `bool` | required | Consumed by the analysis module (parent-gate semantics live there, not here) |
| `parentID` | `String?` | required | final. One level of nesting only, enforced by validator + invariant 5 |
| `symbol` | `String` | required | SF Symbol name in the Swift data. The Flutter UI maps it via the symbol-to-IconData table (master doc hazard 4). The domain treats it as an opaque string |
| `lifecycle` | `LifecycleState` | `active` | |

### 1.7 LedgerChange

Sealed class, 9 cases. Payload upserts carry the **stored** (post-validation, post-normalization) object; deletes carry the id.

| Case | Payload |
|---|---|
| `upsertAccount` | `Account` |
| `upsertPocket` | `SubPocket` |
| `upsertCategory` | `TransactionCategory` |
| `upsertEntry` | `Entry` |
| `upsertPlan` | `RecurringPlan` (type from the plans module) |
| `deleteMoneySource` | `String` id (accounts and pockets share this case) |
| `deleteCategory` | `String` id |
| `deleteEntry` | `String` id |
| `deletePlan` | `String` id |

`targetID` getter: the payload's id in every case. The persistence layer coalesces by `targetID`, so it must be total.

Convenience factory: `LedgerChange.upsertSource(MoneySource)` dispatching to `upsertAccount`/`upsertPocket` (Swift's overloaded `upsert(_:)`).

Equality is by case and payload value (tests compare change lists directly).

### 1.8 HolderReferencing

Interface/mixin over `sourceID: String` and `destinationID: String?` (implemented by `Entry` here and `EntryTemplate` in the plans module), providing:

- `holderIDs`: `Set<String>` of `sourceID` plus `destinationID` when present.
- `references(String id)`: `sourceID == id || destinationID == id`.
- `touches(Set<String> ids)`: `holderIDs` intersects `ids`.

### 1.9 LedgerError

Sealed class, 12 cases. Cases with a payload carry the offending id.

| Case | Payload | Thrown when |
|---|---|---|
| `idCollision` | id | add* called with an id already present in the target table (for holders: anywhere in `moneySources`, account or pocket) |
| `unknownAccount` | id | account-specific lookup misses or resolves to a pocket (`updateAccount`, `addPocket`'s parent) |
| `unknownHolder` | id | generic holder lookup misses (`updatePocket` on a non-pocket, entry source/destination, opening balance target, plan template holders) |
| `unknownCategory` | id | category lookup misses (entry's category, category's parent, plan template category, `updateCategory` target) |
| `unknownEntry` | id | `updateEntry` on a missing id |
| `unknownPlan` | id | `updatePlan` on a missing id |
| `zeroAmount` | – | entry amount is exactly zero |
| `categoryTooDeep` | – | category's parent itself has a parent |
| `categoryKindMismatch` | – | three distinct situations: transfer carrying a category, income/expense entry whose category kind disagrees with the entry sign, child category whose kind disagrees with its parent |
| `inactiveReference` | id | a **newly introduced** reference targets a non-active holder/category (§3.3) |
| `exhaustedPlan` | id | plan add/update where `endDate != null && lastResolvedDate >= endDate` |

---

## 2. LedgerState container and queries

```dart
class LedgerState {
  Map<String, MoneySource> moneySources;
  Map<String, Entry> entries;
  Map<String, TransactionCategory> categories;
  Map<String, RecurringPlan> plans;
}
```

Constructor defaults all four maps to empty. Non-active rows stay in the maps so referencing entries still resolve names; queries carve out what a surface shows.

Read-only queries (part of this module, from `LedgerState+Queries.swift`):

| Query | Behavior |
|---|---|
| `activeSources` | `Set<String>` of holder ids with `lifecycle == active` |
| `activeCategories` | same for categories |
| `binnedSources` | holder ids with `lifecycle == archived` (the recycle bin) |
| `binnedCategories` | same for categories |
| `activeAccounts` | `List<Account>`, active only, sorted by `name` ascending |
| `activePockets(Account account)` | the account's `subPocketIDs` resolved to pockets, active only, sorted by `name` ascending |
| `sourceName(String? id)` | `null` if id is null or missing. Account: its name. Pocket: `"<parentName>/<pocketName>"` when an owning account exists, else the bare pocket name |
| `entriesReferencing(String holderID)` | count of entries where `references(holderID)` (source or destination). The reference-count primitive for purge/tombstone decisions (amended by §7) |
| `entryCount(Set<String> ids)` | count of entries touching any id in the set (bin UI messaging) |
| `entryCountReferencing(String categoryID)` | count of entries with that `categoryID` |

---

## 3. Mutators

Contract for every mutator: **validate, then mutate, then return the full `List<LedgerChange>` describing what changed, in order.** On a thrown error the state is untouched (validation is complete before the first write). Delete/restore/purge mutators do not throw: a missing id or wrong-lifecycle target is a no-op returning `[]`. Change payloads are always the stored values (after any normalization or field forcing), so a subscriber can mirror state from changes alone.

Ordering note: where Swift iterated a `Set` or `Dictionary` (pockets of an account, plans scan, dereference sweep), the relative order **within** that group is unspecified; the ordering guarantees below are between groups. Dart's insertion-ordered maps may strengthen this deterministically; tests must not demand more than the spec.

### 3.1 Accounts and pockets

**`addAccount(Account account)`**

- Throws `idCollision(account.id)` if `moneySources` already contains the id (account **or** pocket).
- Stores the account with `subPocketIDs` forced to **empty** — links are owned by `addPocket`, a caller-supplied set is discarded.
- Returns `[upsertAccount(stored)]`.

**`updateAccount(Account account)`**

- Throws `unknownAccount(account.id)` if the id is missing or resolves to a pocket.
- Stores the passed account with two fields overridden:
  - `subPocketIDs` := the **existing** account's set. The edit surface can never rewrite pocket links (not even with bogus ids).
  - `statementDay` := passed value if `type == card`, else forced `null`.
- Everything else (name, type, flags, lifecycle) is taken from the argument as-is.
- Returns `[upsertAccount(stored)]`.

**`addPocket(SubPocket pocket, String accountID)`**

- Throws `unknownAccount(accountID)` if the parent is missing or not an account (checked **first**).
- Throws `idCollision(pocket.id)` if the pocket id exists anywhere in `moneySources` (**second**).
- Throws `inactiveReference(accountID)` if the parent's lifecycle is not `active` (**third**). **PORT FIX.** Swift checks only the two above, so a pocket could be added under an archived or `referenceOnly` account, leaving an active pocket owned by an unselectable parent. This is the same orphan family §3.7's `restorePocket` fix and §7 address from their own sides; `addPocket` is the fourth and last public route into it. Note this is the reverse of the category rule in §3.4, where a non-active parent is explicitly permitted — see the note there for why the two differ.
- Inserts the pocket, then adds its id to the parent's `subPocketIDs`.
- Returns `[upsertPocket(pocket), upsertAccount(parent)]` — pocket first, updated parent second.

**`updatePocket(SubPocket pocket)`**

- Throws `unknownHolder(pocket.id)` if the id is missing or resolves to an account.
- Replaces the stored pocket wholesale (name, flag, lifecycle all from the argument). The parent link is untouched — it lives on the parent.
- Returns `[upsertPocket(pocket)]`.

### 3.2 Entries

**`addEntry(Entry entry)`**

- Throws `idCollision(entry.id)` if the id exists in `entries`.
- Runs `validated(entry)` (§3.3); stores and returns `[upsertEntry(stored)]` where `stored` is the validated (possibly transfer-normalized) entry.

**`updateEntry(Entry entry)`**

- Throws `unknownEntry(entry.id)` if missing.
- Runs `validated(entry, previous: old)` (§3.3), replaces the stored entry.
- Retargeting can drop the last reference to a `referenceOnly` holder or category, so afterwards it runs the dereference sweep (§3.8) over:
  - dropped holders = `old.holderIDs - stored.holderIDs`,
  - dropped category = `old.categoryID` if it differs from `stored.categoryID`, else none.
- Returns `[upsertEntry(stored)] + <sweep changes>`. When nothing was dropped the list is exactly `[upsertEntry(stored)]`.

**`setOpeningBalance(Decimal amount, String holderID, {DateTime? date})`** (date defaults to now)

- Throws `unknownHolder(holderID)` if the holder is missing.
- If `amount == 0`: no-op, returns `[]` (checked **after** the holder check, so an unknown holder with amount 0 still throws).
- Otherwise delegates to `addEntry` with a synthetic entry: fresh id, given date, given amount (sign preserved — a negative opening balance is a valid expense-shaped entry), `name: "Opening balance"`, no category, no destination, `includeInAnalysis: false`.
- Returns that `addEntry`'s changes: `[upsertEntry(opening)]`.

**`deleteEntry(String id)`** — hard delete, never archived.

- Missing id: `[]`.
- Removes the entry, then runs the dereference sweep (§3.8) over the deleted entry's `holderIDs` and its `categoryID`.
- Returns `[deleteEntry(id)] + <sweep changes>`.

### 3.3 Entry validation: `validated(Entry entry, {Entry? previous})`

`previous` is the entry being replaced (null on add). Checks run in this order; the first failure throws:

1. `amount == 0` → `zeroAmount`.
2. `sourceID` not in `moneySources` → `unknownHolder(sourceID)`.
3. **Prior-reference exemption:** let `priorRefs = previous?.holderIDs ?? {}`. If `sourceID` is NOT in `priorRefs` and the source's lifecycle is not `active` → `inactiveReference(sourceID)`. A holder the entry already referenced stays usable even once archived or referenceOnly — editing an old entry must never be blocked by later lifecycle changes.
4. If `categoryID` is non-null:
   - category not in `categories` → `unknownCategory(categoryID)`.
   - `entry.expectedCategoryKind == null` (i.e. the entry is a transfer) → `categoryKindMismatch`. Transfers are category-less.
   - `category.kind != expectedCategoryKind` → `categoryKindMismatch`.
   - If `previous?.categoryID != categoryID` (a **newly introduced** category reference, including on add) and `category.lifecycle != active` → `inactiveReference(categoryID)`. Keeping the same category on edit is exempt, mirroring rule 3.
5. If `destinationID` is null: done, entry stored as-is.
6. `destinationID` not in `moneySources` → `unknownHolder(destinationID)`.
7. **Self-transfers are accepted.** `destinationID == sourceID` is a legal entry and is stored like any other transfer. A PayNow to your own account debits and credits the same holder, so it appears on the bank statement and must be recordable. It contributes zero to `balance` (both legs cancel) and analysis emits both legs symmetrically (`plans_and_accounting.md` §5.3), so it nets to zero there too. **PORT FIX** — the Swift rejects this with `selfTransfer`; that error case is deleted from `LedgerError` rather than kept unthrown.
8. If `destinationID` not in `priorRefs` and the destination's lifecycle is not `active` → `inactiveReference(destinationID)`.
9. **Transfer normalization:** if `amount < 0`, the stored entry is rebuilt with `amount` negated (now positive) and `sourceID`/`destinationID` **swapped** (same id, date, name, categoryID, includeInAnalysis). A stored transfer therefore always has a positive amount; "transfer of -100 from A to B" and "transfer of 100 from B to A" are the same fact stored one way. A positive transfer is stored unchanged.

Note the check order is observable: a transfer with a category throws `categoryKindMismatch` even when the destination is also invalid (category checks precede destination checks), and a zero-amount entry throws `zeroAmount` before any holder lookup.

### 3.4 Categories

**`addCategory(TransactionCategory category)`** / **`updateCategory(TransactionCategory category)`**

- Add throws `idCollision(id)` on an existing id; update throws `unknownCategory(id)` on a missing one.
- Shared validation, in order (skipped entirely when `parentID` is null):
  1. parent not in `categories` → `unknownCategory(parentID)`.
  2. parent itself has a `parentID` → `categoryTooDeep` (max two levels).
  3. `parent.kind != category.kind` → `categoryKindMismatch`.
  - Parent **lifecycle** is not checked. (Adding an active child under an archived parent is allowed; see §5 purge note.) This is deliberately the reverse of `addPocket` (§3.1), which rejects a non-active parent. A pocket is a holder reached through the account that owns it, so an active pocket under a non-active account is unreachable and may be hanging from a row already on its way out. A category's parent is only a naming ancestor — it holds no balance and owns nothing — and the purge cascade (§3.8) sweeps children regardless of their lifecycle, so an active child can never outlive the parent row. The state pockets must prevent is one categories cannot reach.
- Stores the category verbatim, returns `[upsertCategory(category)]`.

### 3.5 Plans (types owned by the plans module; the mutators live on LedgerState)

**`addPlan(RecurringPlan plan)`** / **`updatePlan(RecurringPlan plan)`**

- Add throws `idCollision(id)`; update throws `unknownPlan(id)`.
- Shared validation, in order:
  1. `template.sourceID` not in `moneySources` → `unknownHolder`; not active → `inactiveReference`. **No prior-reference exemption for plans** — plan templates always require active holders, on update too.
  2. Same pair for `template.destinationID` when non-null.
  3. `template.categoryID` when non-null: missing → `unknownCategory`; lifecycle not active → `inactiveReference`. (Template category kind is NOT validated here; a mismatch surfaces later as a per-occurrence `PlanFailure` from `resolvePlans`.)
  4. `endDate != null && lastResolvedDate >= endDate` → `exhaustedPlan(id)`.
- Returns `[upsertPlan(plan)]`.

**`deletePlan(String id)`** — hard delete (plans are regenerable config, not history). Missing id: `[]`. Returns `[deletePlan(id)]`.

**`resolvePlans(DateTime now, <calendar context>)`** returns `(List<LedgerChange> changes, List<PlanFailure> failures)`.

For each stored plan (order across plans unspecified):

1. Compute `due = plan.occurrences(after: lastResolvedDate, upTo: now)` (plans-module logic).
2. For each due date in ascending order: build the occurrence entry via `template.makeEntry(planID, date)` (deterministic id from the plans module). If that id already exists in `entries`, **skip silently** (already materialized, e.g. seeded or future sync). Otherwise run `validated(entry)`: on success store it and append `upsertEntry(stored)`; on error append `PlanFailure(planID, occurrence, error)` to `failures` and continue. Failures never abort the sweep.
3. Advance a copy of the plan with `lastResolvedDate = now`, then:
   - if the advanced plan `isExhausted(asOf: now)` → remove it from `plans`, append `deletePlan(planID)`.
   - else if `due` was non-empty → store the advanced plan, append `upsertPlan(advanced)`.
   - else (nothing due, not exhausted) → **no state change and no change emitted.** A stale cursor only gates occurrences already in the past, so not re-persisting is safe and avoids write churn.

Within one plan the change order is: entry upserts (date ascending), then the plan's own upsert or delete.

**Cascade helper `removePlansReferencing(Set<String> ids)`** (private, used by `deleteAccount`): hard-removes every plan whose template `touches(ids)`, returns the removed plan ids.

### 3.6 Archive (delete = archive, never cascade to entries)

**`deleteAccount(String id)`**

- No-op `[]` unless the id resolves to an **account** with lifecycle `active` (a pocket id, or an already archived account, is ignored).
- Effects and change order:
  1. Account lifecycle → `archived`; append `upsertAccount`.
  2. Every pocket in `subPocketIDs` whose lifecycle is `active` → `archived`; append `upsertPocket` each (non-active pockets untouched). Links in `subPocketIDs` are kept for restore.
  3. Every plan touching `{accountID} ∪ subPocketIDs` is hard-removed; append `deletePlan` each. Plans are config, not history — they do not archive.
- Entries are never touched (all retained, still pointing at the archived holders).

**`deletePocket(String id)`**

- No-op unless an active pocket. Lifecycle → `archived`. Parent's `subPocketIDs` keeps the link. Returns `[upsertPocket(archived)]` only — the parent is not re-emitted.

**`deleteCategory(String id)`**

- No-op unless an active category.
- Category → `archived` (append `upsertCategory`), then every **active** child (`parentID == id`) → `archived` (append `upsertCategory` each).
- Entries keep their `categoryID` — never rehomed to null.

### 3.7 Restore

**`restoreAccount(String id)`**

- No-op unless an **archived** account.
- Account → `active` (append `upsertAccount`), then every **archived** pocket in `subPocketIDs` → `active` (append `upsertPocket` each). `referenceOnly` pockets stay as they are (they left the bin permanently).

**`restorePocket(String id)`**

- No-op unless an archived pocket.
- **Blocked** (no-op `[]`) unless the owning account is `active` — restore the account first. A pocket with **no** owning account is blocked too, since no account is not an active account. That shape already violates invariant 3, so restoring it would only entrench the violation.

  **PORT FIX.** Swift blocked only on an `archived` parent (`parent.lifecycle != .archived`), so an archived pocket could be restored under a `referenceOnly` parent, leaving an active pocket owned by a purged, unselectable account. Any non-active parent now blocks the restore. This is the same orphan family §7 addresses from the purge side, where a `referenceOnly` parent tombstones once its last pocket goes, and it matches `restoreAccount`, which restores archived pockets but leaves `referenceOnly` ones. A `referenceOnly` pocket is unrestorable regardless, per the terminal-but-one rule in §4.
- Otherwise pocket → `active`, returns `[upsertPocket]`.

**`restoreCategory(String id)`**

- No-op unless an archived category.
- **Blocked** (no-op) when `parentID` is non-null and the parent's lifecycle is `archived`.
- Otherwise category → `active` (append `upsertCategory`), then every **archived** child → `active` (append `upsertCategory` each).

### 3.8 Purge (permanent delete from the bin) and the dereference sweep

Purge never touches entries. Outcome per row: **referenced → `referenceOnly` (kept, name resolves), unreferenced → tombstoned (row removed).**

> §7 amends the account/pocket reference rule and the purge order. The paragraphs below give the corrected behavior directly; the Swift original differed only in the defect described there.

**`purgeAccount(String id)`**

- No-op unless an **archived** account.
- Purge each pocket in `subPocketIDs` (that resolves to a pocket) first, then the account itself, both via the holder-purge rule below. Change order: all pocket-purge changes, then the account's.
- Account referencedness uses the §7 rule: direct entry references, or any surviving pocket.

**`purgePocket(String id)`** — no-op unless an archived pocket, then the holder-purge rule.

**Holder-purge rule** (per holder):

- If the holder is referenced (`entriesReferencing(id) > 0`, plus for accounts the §7 pocket rule): lifecycle → `referenceOnly`, append `upsertAccount`/`upsertPocket`.
- Else **tombstone**: remove the row from `moneySources` and append `deleteMoneySource(id)`. A pocket additionally leaves its parent's `subPocketIDs` **in the same step** (append `upsertAccount(parent)` **before** the `deleteMoneySource`), so no dangling link ever exists between changes.

**`purgeCategory(String id)`**

- No-op unless an **archived** category.
- Purge the category row, then every child row with `parentID == id` — children are swept **regardless of their lifecycle** (an active child of an archived parent, possible per §3.4, gets purged too).
- Category-row rule: if the row is **referenced** → lifecycle `referenceOnly`, append `upsertCategory`; else remove the row and append `deleteCategory(id)`.
- **Category referencedness is recursive**, not a single-row check: a category counts as referenced when any entry carries its `categoryID`, **or** when any of its descendant categories is itself referenced. The walk is depth-guarded by a visited set, so a malformed cycle terminates instead of recursing forever. **PORT FIX.** Swift tests direct entry references only, which would delete a parent row while a still-referenced child survives pointing at it — an unknown parent, tripping invariant clause 5. Because children sweep first and the parent is judged after, a child kept alive as `referenceOnly` is visible when its parent is weighed, and the parent is kept for it.

**Dereference sweep `tombstoneDereferenced(Set<String> holders, String? category)`** (private; called by `deleteEntry` and `updateEntry`) — the **only** referenceOnly → tombstoned path:

- For each holder id in the set whose stored lifecycle is `referenceOnly` and whose reference count has hit zero (§7 rule for accounts): tombstone it via the holder tombstone above (pocket detaches from parent, and per §7 the parent is then re-checked).
- Then, if `category` is non-null, stored, `referenceOnly`, and unreferenced under the recursive rule above (no entry carries it and no descendant of it is referenced): remove the row, append `deleteCategory`.
- That removal cascades **upward**: a category's parent may have been held up solely by the child just removed, so once the child's row is gone the parent is re-judged under the same rule and removed too if it now qualifies, and so on up the chain. This mirrors the pocket-to-parent re-check on the holder side.
- Holders sweep first, category last.

---

## 4. The lifecycle machine

```
                    delete*                    purge* (referenced)
        active ───────────────► archived ───────────────► referenceOnly
          ▲                        │                            │
          └──────── restore* ──────┘                            │ last referencing
                                                                │ entry deleted or
                    purge* (unreferenced)                       │ retargeted
        archived ──────────────────────────► tombstoned ◄───────┘
                                          (row removed)
```

| Rule | Statement |
|---|---|
| Delete is archive | `deleteAccount/Pocket/Category` set `archived`. Nothing is removed, entries always retained. Only entries and plans hard-delete |
| Archive cascade | Account archives its active pockets. Category archives its active children. Account archival also hard-deletes plans touching the account or its pockets |
| Restore cascade | Account restore reactivates its archived pockets. Category restore reactivates archived children |
| Restore blocking | Pocket restore is a no-op while its parent account is archived. Child-category restore is a no-op while its parent is archived |
| Purge fork | Referenced → `referenceOnly`. Unreferenced → tombstoned (removed). §7 defines "referenced" for accounts |
| Atomic pocket detach | A tombstoned pocket leaves `moneySources` and its parent's `subPocketIDs` in one mutation |
| referenceOnly is terminal-but-one | No restore from `referenceOnly`. The only exit is tombstoning via the dereference sweep when the last referencing entry is deleted or retargeted away |
| Entries are binary | `active` or gone. `deleteEntry` removes the row and may cascade tombstones via the sweep |

---

## 5. Behavioral notes worth pinning (subtle rules, all test-backed)

1. **Transfer normalization** (§3.3.9): negative transfer flips sign and swaps endpoints; emitted and stored entry are the normalized one.
2. **`subPocketIDs` ownership**: `addAccount` empties it, `updateAccount` restores the existing set — a caller can never create or rewrite links through the account edit surface. Only `addPocket` adds a link and only holder tombstoning removes one.
3. **`statementDay` forcing**: `updateAccount` nulls it for any non-card type, keeps it for cards. (`addAccount` stores what it is given — the UI form owns the initial constraint.)
4. **Prior-reference exemption** applies per-reference: editing an entry whose source is now archived is fine, but retargeting that entry's **destination** to an archived holder throws. Same-category on edit is exempt, switching to an inactive category throws.
5. **Plans have no exemption** — every plan add/update needs fully active holders and category.
6. **Purge of category children ignores lifecycle** (`purgeCategory` sweeps all children), while archive/restore cascades filter by lifecycle (`active`→archive, `archived`→restore).
7. **Wrong-flavor ids are no-ops**: `deleteAccount(pocketID)` and `deletePocket(accountID)` do nothing (typed guards), whereas `update*` on the wrong flavor throws (`unknownAccount`/`unknownHolder`).
8. **Emission completeness**: every state delta appears in the returned changes with stored values — `deleteAccount` emits the archived account, archived pockets, and plan deletes, but no `deleteMoneySource` and no entry changes.

---

## 6. Invariants (`assertInvariants`), debug-only, run after every mutation

Port as a method on `LedgerState`, executed inside `assert(...)` so release builds skip it. Each clause is a testable property of any reachable state:

1. **Keys match ids.** For all four maps, every key equals the stored value's `id`.
2. **Pocket links resolve and are exclusive.** Every id in any account's `subPocketIDs` resolves to a pocket in `moneySources` (archived/referenceOnly pockets stay linked; only tombstoned ones leave), and no pocket id appears in two accounts' sets.
3. **No orphan pocket.** Every pocket in `moneySources` appears in exactly one account's `subPocketIDs`.
4. **No dangling entry reference.** Every entry's `sourceID`, and `destinationID` when present, resolves in `moneySources` (any lifecycle — tombstoned rows only leave once unreferenced).
5. **Category nesting.** A category with a stored parent: the parent has no parent (depth ≤ 2), child kind equals parent kind, and the parent is not `referenceOnly` or `tombstoned`. An **archived** parent is legal, matching the write path (`_validateParent` permits it deliberately); a parent already on its way out is not, because the dereference sweep deletes a `referenceOnly` category as soon as its last entry goes and does **not** look for children, so the child would be left naming a row that no longer exists.
6. **Entry-category coherence.** For every entry whose `categoryID` resolves: the entry is not a transfer, and the category's kind equals the entry's `expectedCategoryKind`. (Archived/referenceOnly categories are fine.)
7. **No dangling plan reference.** Every plan's template source, destination (when present), and category (when present) resolve in their tables.
8. **No exhausted plan stored.** Every stored plan with an `endDate` has `lastResolvedDate < endDate` (stated against the cursor, not a clock — the domain has none).
9. **Entries are active.** Every stored entry's lifecycle is `active`.
10. **No stored tombstone.** No holder or category in the tables has lifecycle `tombstoned`.
11. **referenceOnly implies referenced.** Every `referenceOnly` category is referenced under the recursive rule of §3.8 — it has at least one entry carrying its `categoryID`, **or** at least one descendant category that is itself referenced. The clause is stated against that rule rather than against direct entries alone, and is checked by calling the same helper the purge and sweep paths use, so the three can never drift: a parent kept alive solely by a child's entry satisfies the clause exactly because it is what keeps clause 5 (no category with an unknown parent) true. Every `referenceOnly` **pocket** has at least one referencing entry. Every `referenceOnly` **account** has at least one referencing entry **or at least one pocket still present in its `subPocketIDs`** (the account-side amendment required by the §7 fix — without it the fixed purge would trip the original clause).
12. **Lifecycle monotonicity.** No row's lifecycle moves to a more-alive state, except `archived` → `active`. This is the only **transition** clause: it is illegal relative to the *previous* state and cannot be decided from the resulting one, since an active row holding entries is a perfectly legal snapshot. It is therefore checked by comparing consecutive settled states rather than by a pass over the tables. `restoreAccount`/`restorePocket`/`restoreCategory` are the only sanctioned back-edge and can produce only that one transition, each gating on `== archived` before writing. This is what makes `referenceOnly` genuinely terminal.
13. **Statement day range.** Every card account's `statementDay` is null or within 1–28; every non-card account's is null. The mutators clamp on the write path, so this catches a row that arrived through the seeding constructor or a future import.
14. **Plans reference no leaving row.** No stored plan references a `referenceOnly` or `tombstoned` row. An **archived** row is legal: archiving *freezes* a plan rather than dropping it, so a later restore returns a holder that still has its plans, and the plan's occurrences fail validation meanwhile. Clause 7 covers existence; this clause covers lifecycle only.
15. **A pocket may not outlive its account.** No pocket is more alive than the account holding it. The write path enforces this by judging the **child** (`updatePocket`), so every path that moves the **parent** instead escapes it — clause 2 checks that links resolve and clause 3 that no pocket is orphaned, and neither compares the two lifecycles.

The Dart test suite should expose a way to run the sweep on demand (mirroring `ledger.assertInvariants()` calls inside tests) in addition to the after-every-mutation hook in `Ledger.mutate`.

---

## 7. KNOWN DEFECT — fix during the port, do not copy

**Swift bug (code critique v2, Con 1):** `entriesReferencing(holder:)` counts only direct source/destination references, so a pocket's references never count toward its parent account. Two broken paths:

- **Purge path.** Account A funded only through its pockets (A itself never an entry endpoint). Archive A, purge A: the Swift code purges the **account first** and sees zero references → tombstones and removes A, then makes each referenced pocket `referenceOnly`. Result: referenceOnly pockets owned by nobody. Invariant 3 crashes on the spot in debug; in release it is silent inconsistency persisted to disk.
- **Deferred path.** A and its pocket P both `referenceOnly`. Deleting the last entry that references **A directly** tombstones A via the sweep while P still has referencing entries. Same orphan.

**Corrected behavior (normative for the Dart port):**

1. **Reference rule.** An account counts as referenced while it has direct entry references **or** any pocket id in its `subPocketIDs` still present in `moneySources` (i.e. the pocket is alive in any lifecycle). Pockets keep the direct-count rule.

   **PORT FIX (Dart).** The port strengthens this: a pocket keeps its parent referenced only when the pocket is **itself referenced**, evaluated by the same rule, not merely because its row is present. Pocket ids no longer in `moneySources` are skipped, so a stale link cannot revive a parent. Rationale: presence trusts `subPocketIDs` to be accurate, and a pocket row that ever failed to clear would pin its parent at `referenceOnly` permanently, with nothing to re-examine the link. Deriving referencedness from entries makes that failure mode a redundant re-check rather than a leak. The two rules differ only for a surviving pocket carrying zero entries, which the atomic detach-and-remove (`_detachAndTombstonePocket`) makes unreachable, so all three regression tests below hold identically under either. Implemented as `_isReferenced` in `ledger_state_queries.dart`.
2. **Purge order.** `purgeAccount` purges the pockets **first**, the account **last**, so each pocket's survival (referenceOnly vs tombstoned) is settled before the account's referencedness is evaluated. Change list: pocket changes, then account change.
3. **Deferred cascade.** When a pocket tombstones (from the dereference sweep or a purge), re-check its former parent: if the parent is `referenceOnly`, has zero direct references, and now has no pockets left in `subPocketIDs`, tombstone the parent in the same mutation (parent's `upsertAccount` detach change, then `deleteMoneySource(pocket)`, then `deleteMoneySource(parent)`).
4. **Sweep rule.** The dereference sweep never tombstones a `referenceOnly` account that still has surviving pockets, even at zero direct references — it stays `referenceOnly`.
5. **Invariant amendment.** Clause 11 as stated in §6 (account satisfies it via surviving pockets).

**Regression tests (required, this shape exactly):**

- `purgeAccountWhoseEntriesOnlyReferenceItsPocketsKeepsItReferenceOnly` — account A, pocket P under A, one entry with P as an endpoint and A on neither end (e.g. income of 100 into P). Delete A (archives A and P), purge A. Expect: A `referenceOnly`, P `referenceOnly`, invariants pass. (Under the Swift bug: A removed, P orphaned, invariant 3 fires.)
- `deletingLastDirectEntryKeepsAccountWhilePocketStillReferenced` — A and P `referenceOnly`, one entry referencing A directly and one referencing P. Delete the A-referencing entry. Expect: A **stays** `referenceOnly` (pocket alive), P untouched, invariants pass.
- `lastPocketTombstoneCascadesToDereferencedParent` — A and P `referenceOnly`, the only remaining entry references P. Delete it. Expect: P tombstoned and detached, then A tombstoned in the same mutation (zero direct refs, no pockets left). Change list contains `upsertAccount(A-detached)`, `deleteMoneySource(P)`, `deleteMoneySource(A)` in that order. Invariants pass, `moneySources` empty.

---

## 8. Test inventory — LedgerStateTests parity

Source suite: `LedgerStateTests.swift`, 68 tests, plus `TestSupport.swift` (a one-line `applyIgnoringChanges` helper that runs a mutation and discards its changes; port as an equally trivial helper). The Dart suite must cover every scenario below, names mapped 1:1 where sensible, plus the three §7 regression tests. Fixture helpers used throughout: a default savings `account(id)`, a default expense `category(id, kind:, parent:)`, a monthly `plan(id, source:)`.

**A. Pocket attachment and id space (3)**
- `addPocketAttachesToParentAndTable` — pocket stored, parent's `subPocketIDs` contains it.
- `addPocketToMissingAccountThrows` — `unknownAccount`.
- `addAccountRejectsIdCollisionWithPocket` — one id space: an account with a pocket's id throws `idCollision`.

**B. Entry validation (6)**
- `zeroAmountEntryThrows`.
- `entryWithUnknownSourceThrows` — `unknownHolder`.
- `selfTransferIsAcceptedAndStored` — and `selfTransferContributesZeroToBalance`.
- `entryWithUnknownCategoryThrows` — `unknownCategory`.
- `negativeTransferNormalizesToPositiveWithSwappedEndpoints` — stored amount 100, endpoints swapped.

**C. Opening balance (3)**
- `openingBalanceIsExcludedFromAnalysis` — amount stored, `includeInAnalysis == false`, no category.
- `openingBalanceOfZeroRecordsNothing` — no entry created.
- `setOpeningBalanceOnUnknownHolderThrows` — `unknownHolder`.

**D. Category structure (2)**
- `categoryNestedTwoLevelsThrows` — third level throws `categoryTooDeep`.
- `addCategoryWithUnknownParentThrows` — `unknownCategory(parent)`.

**E. Category kind rules (5)**
- `expenseEntryWithIncomeCategoryThrows` / `incomeEntryWithExpenseCategoryThrows` — `categoryKindMismatch`.
- `matchingKindEntryIsAccepted` — both signs with matching kinds stored.
- `transferWithCategoryThrows` — `categoryKindMismatch`.
- `childCategoryKindMustMatchParent` — `categoryKindMismatch`.

**F. Archive / restore / purge lifecycle (14)**
- `deleteAccountArchivesItWithPocketsAndRetainsEntries` — account + pocket archived, unrelated account active, all 3 entries retained.
- `deletePocketArchivesItKeepingParentLinkAndEntries`.
- `deleteCategoryArchivesItAndChildrenKeepingEntryCategoryID`.
- `restoreAccountReactivatesItAndPockets`.
- `restorePocketBlockedWhileParentArchived` — stays archived.
- `purgeWithReferencingEntriesGoesReferenceOnly`.
- `purgeWithoutReferencingEntriesTombstones` — row removed.
- `deleteLastReferencingEntryTombstonesReferenceOnlyHolder` — deferred tombstone via entry delete.
- `newEntryCannotReferenceArchivedHolder` — `inactiveReference`.
- `newEntryCannotReferenceArchivedCategory` — `inactiveReference`.
- `editingEntryOnAlreadyArchivedCategoryStaysAllowed` — prior-reference exemption (category kept, other fields edited).
- `updateEntryOffReferenceOnlyHolderTombstonesIt` — retarget away tombstones the old holder, invariants pass.
- `tombstonedPocketDetachesFromParentKeepingInvariants` — purge of unreferenced archived pocket removes row and parent link atomically.
- `archivedPocketStaysLinkedForRestore` — archive then restore pocket round-trip, link intact.

**G. Account create/edit surface (7)**
- `addAccountRejectsDuplicateId`.
- `updateAccountEditsAttributesInPlace` — name/type/flags all replaced, still one row.
- `updateAccountPreservesPocketLinks`.
- `updateAccountIgnoresPassedSubPocketIDs` — bogus passed set discarded, real link kept.
- `updateAccountClearsStatementDayForNonCard`.
- `updateAccountKeepsStatementDayForCard`.
- `updateUnknownAccountThrows`.

**H. Entry create/edit surface (6)**
- `updateEntryOverwritesSameId` — still one entry, new amount.
- `addEntryRejectsDuplicateId`.
- `updateUnknownEntryThrows`.
- `editingEntrySourceMovesTheMoney` — balances derived, expense moves wholly to the new source. (Swift asserts via the accounting module's `balance`; the Dart Phase 1 version may assert on the stored entry's `sourceID` if `Accounting` is not yet ported, then upgrade in Phase 2.)
- `editingEntryRevalidatesNewHolders` — retarget to ghost throws `unknownHolder`, original untouched (validate-before-mutate).
- `editingEntryCanChangeCategory`.

**I. Pocket/category edit surface (3)**
- `updatePocketChangesFieldsNotParentLink`.
- `updatePocketOnUnknownIdThrows` — `unknownHolder`.
- `addCategoryUpdatesInPlace` — updateCategory replaces fields, count stays 1.

**J. Transfer storage (1)**
- `positiveTransferStoredUnchanged`.

**K. Delete guards (3)**
- `deleteEntryRemovesOnlyThatEntry`.
- `deleteAccountIgnoresAPocketId` — no-op on wrong flavor.
- `deletePocketIgnoresAnAccountId` — no-op on wrong flavor.

**L. Invariants (1)**
- `invariantsHoldAfterArchiveWithRetainedEntries` — active entry referencing archived holders is a legal state.

**M. Change emission (15)** — each asserts the exact returned list (order included):
- `addAccountEmitsUpsert` — `[upsertAccount]`.
- `updateAccountEmitsUpsertOfStoredAccount` — payload is the stored (post-override) account.
- `addPocketEmitsPocketAndParentUpsert` — `[upsertPocket, upsertAccount]` in that order.
- `updatePocketEmitsUpsert`.
- `addEntryEmitsUpsertOfStoredEntry`.
- `addEntryEmitsNormalizedTransfer` — payload is the normalized entry.
- `updateEntryEmitsUpsert` — exactly one change when no reference was dropped.
- `setOpeningBalanceEmitsEntryUpsert` / `setOpeningBalanceOfZeroEmitsNothing`.
- `addCategoryEmitsUpsert` / `updateCategoryEmitsUpsert`.
- `deleteEntryEmitsDelete`.
- `deleteAccountEmitsArchiveUpsertsAndPlanDeletes` — contains archived account, archived pocket, `deletePlan`; contains **no** `deleteMoneySource`.
- `deletePocketEmitsPocketUpsertOnly` — exactly `[upsertPocket(archived)]` even with entries present.
- `deleteCategoryEmitsArchiveUpserts` — archived category emitted, entry keeps its `categoryID`.

**N. Port-only additions**
- The three §7 regression tests.
- A pinned-code test for each int-coded enum (`LifecycleState`, `AccountType`, `CategoryKind`) asserting the exact code table in §1, so persistence codes cannot drift from Swift data.
