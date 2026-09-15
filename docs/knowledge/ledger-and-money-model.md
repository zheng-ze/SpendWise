# Ledger & Money Model

Last reconciled: 2026-09-02

## Feature overview

The pure-Dart domain layer: the value models, the in-memory `LedgerState`, and the mutators that
change it. This is the single source of truth the app mutates and persists. It depends on nothing
but the `decimal` package; a `flutter` import in `packages/domain/` is rejected by `pubspec.yaml`,
which makes framework-free a compiler-enforced boundary, not a convention.

Key terms: a **money source** is either an **account** or a **pocket**; both share one id space
and one table (`moneySources`). An **entry** is one recorded transaction (income, expense, or
transfer). A **category** labels spending or income with one level of nesting. A **plan** is a
recurring entry template. Every row moves through a **lifecycle**: `active`, `archived` (recycle
bin), `referenceOnly` (referenced but purged), or `tombstoned` (removed). A mutation returns a
`List<LedgerChange>`; rejections throw a sealed `LedgerError`.

## Error and change vocabulary

`LedgerError` (`ledger_error.dart`) has **15** cases, not the spec's "ten". Identified cases carry
an id and equality is by case + id: `IdCollision`, `UnknownAccount`, `UnknownHolder`,
`UnknownCategory`, `UnknownEntry`, `UnknownPlan`, `ExhaustedPlan`, `UnknownBudget`,
`InactiveReference`, `StaleResolutionCursor`, `SystemEntryLocked`. Plain cases (no id): `ZeroAmount`,
`CategoryTooDeep`, `CategoryKindMismatch`, `CategoryAlreadyBudgeted`. Each carries a persisted
`_case` lowerCamelCase string; changing it breaks stored rows.

`LedgerChange` (`ledger_change.dart`) has **11** cases: `UpsertAccount`, `UpsertPocket`,
`UpsertCategory`, `UpsertEntry`, `UpsertPlan`, `UpsertBudget`, `DeleteMoneySource`,
`DeleteCategory`, `DeleteEntry`, `DeletePlan`, `DeleteBudget`. `targetID` is total across all;
`LedgerChange.upsertSource(MoneySource)` dispatches to `UpsertAccount` vs `UpsertPocket`.

## Key files

- `packages/domain/lib/src/ledger_state/ledger_state.dart` — the container: four id-keyed maps
  (`moneySources`, `entries`, `categories`, `plans`) and every mutator.
- `packages/domain/lib/src/ledger_state/ledger_state_invariants.dart` — the debug `assertInvariants`
  sweep run after every mutation.
- `packages/domain/lib/src/ledger_state/ledger_state_queries.dart` — read-only queries and the
  reference-counting helpers used by purge.
- `packages/domain/lib/src/ledger_state/ledger_state_replay.dart` — validation-free replay used by
  load, the in-memory double, and seeding.
- `packages/domain/lib/src/ledger_state/ledger_state_purge.dart` — the holder/category purge rule
  and the dereference sweep.
- `packages/domain/lib/src/ledger_state/ledger_state_entries.dart`, `ledger_state_holders.dart`,
  `ledger_state_categories.dart`, `ledger_state_plans.dart`, `ledger_state_budgets.dart` — the
  mutator groupings by row kind.
- `packages/domain/lib/src/entries/entry.dart`, `account.dart`, `sub_pocket.dart`,
  `money_source.dart`, `transaction_category.dart`, `holder_referencing.dart`,
  `category_resolution.dart` — the value models.
- `packages/domain/lib/src/ledger_change.dart`, `ledger_error.dart`, `lifecycle_state.dart`,
  `ids.dart` — the sealed change/error vocabularies and ID normalization.

## Module interactions

`Ledger` (app layer, `app/lib/ledger/ledger.dart`) is the only object allowed to touch
`LedgerState`; views and view models never hold a `LedgerState` reference. Every public
`Ledger` mutation runs the same pipeline: run the domain mutator, sweep invariants in debug,
publish the returned changes to the `EventBus`, then notify Riverpod listeners (`ledger_runtime.md`
§1.1). On a thrown `LedgerError` nothing happens — no change, no invariant sweep, no publish.

The persistence layer (`persistence.md`) coalesces changes by `LedgerChange.targetID` and rebuilds
state via `LedgerState.replaying(changes)`, which applies changes directly into the maps without
validation or cascade (`ledger_state_replay.dart`).

`LedgerState.adopt` (`ledger_state_adopt.dart`) is the sync apply boundary's counterpart: it
clears and refills all five live tables in place, keeping the same `LedgerState` object, without
validating. The caller (`Ledger.applySyncBatch`, see `ledger_runtime.md`) validates the candidate
structurally before adopting. The `_lifecycleAtLastCheck` baseline refreshes only inside the
existing debug-only assert closure, so release builds allocate no snapshot map and the next debug
local mutation judges clause 12 against the post-sync baseline.

`Accounting` reads `LedgerState` as pure functions — balances, net
worth, and analysis classification — and never mutates it.

## Lifecycle machine

The state machine, with the rule behind each edge (`ledger_state_purge.dart`,
`ledger_state_invariants.dart`):

- **Delete archives.** `deleteAccount` / `deletePocket` / `deleteCategory` set `archived`; nothing
  is removed and entries are always retained. Only entries and plans hard-delete.
- **Archive cascade.** Archiving an account also archives its active pockets and hard-deletes every
  plan touching the account or its pockets. Archiving a category archives its active children.
- **Restore reactivates.** `restoreAccount` / `restoreCategory` reactivate their archived children;
  `restorePocket` reacts only the pocket.
- **Restore blocks.** Restoring a pocket is a no-op unless its owning account is `active`; restoring
  a child category is a no-op unless its parent is `active`.
- **Purge forks.** An archived row referenced by entries becomes `referenceOnly` (kept, name still
  resolves); an unreferenced row is tombstoned (removed from the table).
- **referenceOnly is terminal-but-one.** No restore from `referenceOnly`; the only exit is
  tombstoning via the dereference sweep when the last referencing entry is deleted or retargeted.
- **Entries are binary.** `active` or gone; `deleteEntry` removes the row and may cascade
  tombstones through the sweep.

### The account-referencedness fix (Dart port)

An account counts as referenced while it has direct entry references **or** any pocket that is
itself referenced (not merely present). `purgeAccount` purges pockets first, then the account, so
each pocket's fate is settled before the account's referencedness is judged. A tombstoned pocket
detaches from its parent's `subPocketIDs` in the same step, and a parent left at zero references
with no surviving pockets is tombstoned too. See the regression tests in the purge and sweep code.

## Mutator contract

Every mutator validates, mutates, then returns the full `List<LedgerChange>` in order. Change
payloads are always the stored (post-normalization) values, so a subscriber can mirror state from
changes alone. Delete/restore/purge mutators do not throw: a missing id or wrong-lifecycle target
is a no-op returning `[]`.

- **Entry validation** runs `validated(entry)` in order: zero amount, source holder, prior-reference
  exemption, category kind/lifecycle, destination holder, self-transfer accepted, destination
  lifecycle, then transfer normalization (a negative transfer is stored positive with endpoints
  swapped). The check order is observable.
- **`updateEntry` locks system entries.** When the previous entry is a system kind, changing its
  `name`, `categoryID`, or `includeInAnalysis` throws `SystemEntryLocked(entry.id)`; amount, date,
  and holders stay editable (`setOpeningBalance` builds a `systemKind: openingBalance` entry with
  `includeInAnalysis: false`).
- **`addPocket`** rejects a non-active parent (`inactiveReference`); **`addCategory`** permits a
  non-active parent — a pocket is reached through its owning account, a category is only a naming
  ancestor.
- **Plans have no prior-reference exemption** — every plan add/update requires fully active holders
  and category.
- **`subPocketIDs` ownership**: `addAccount` empties the set, `updateAccount` restores the existing
  set, so a caller can never create or rewrite pocket links through the account edit surface. Both
  normalize `statementDay` via `withNormalizedStatementDay()` (clamp to 1–28, non-card → `null`).
- **`updateAccount` pocket-demotion cascade.** Moving an account to a less-alive lifecycle demotes
  any pocket that would otherwise outlive it (`_demotePocketsBelow`), appended after the account
  upsert, so a pocket is never more alive than its account.
- **`statementDay`** is forced to `null` for non-card types on `updateAccount`; `addAccount` stores
  what it is given (then clamped).

## Invariants

`assertInvariants` runs after every mutation in debug builds only (`ledger_state_invariants.dart`),
backstopping states that closed maps and dedicated removers are meant to make unreachable. The
clauses: keys match ids; pocket links resolve and are exclusive; no orphan pocket; no dangling
entry reference; category depth ≤ 2 with matching kinds and a non-ghost parent; entry-category
coherence; no dangling plan reference; no stored exhausted plan; entries are active; no stored
tombstone; `referenceOnly` implies referenced (recursively for categories); lifecycle monotonicity
(`archived → active` is the only back-edge); statement-day range; plans reference no leaving row;
a pocket may not outlive its account. The reference-count clause for accounts is checked by calling
the same helper the purge and sweep paths use, so the three can never drift.

## Gotchas and invariants

- **Transfer normalization**: a negative transfer is stored positive
  with source/destination swapped; "transfer of -100 A→B" and "transfer of 100 B→A" are one fact.
  Self-transfers (`destinationID == sourceID`) are legal and net to zero in balance and analysis.
- **Prior-reference exemption** applies per reference: editing an entry whose source is now archived
  is fine, but retargeting that entry's destination to an archived holder throws. Same-category on
  edit is exempt; switching to an inactive category throws.
- **Wrong-flavor ids**: `deleteAccount(pocketID)` is a no-op, but `updateAccount` on a pocket id
  throws `unknownAccount`; `updatePocket` on an account id throws `unknownHolder`.
- **`double` anywhere in `packages/domain/lib/` is a defect**; money is `Decimal`. IDs are lowercase
  uuid strings normalized at every construction boundary. Int-coded enums (`LifecycleState`,
  `AccountType`, `CategoryKind`) carry an explicit `code`; never persist `enum.index`.

## Requirements

- Money is `Decimal`, never `double`; IDs are normalized lowercase uuids; int-coded enums carry an
  explicit `code`. (CONTEXT.md domain rules)
- Every `LedgerState` mutation validates, mutates, and returns `List<LedgerChange>` in order.
  (`ledger_state.dart`)
- `assertInvariants` runs after every successful mutation in debug builds. (`ledger_state_invariants.dart`)
- Delete archives and retains entries; purge moves referenced rows to `referenceOnly` and
  unreferenced rows to tombstoned; only the dereference sweep moves a row to `tombstoned`.
  (`ledger_state_purge.dart`, `ledger_state_invariants.dart` clause 12)
- An account is referenced while it has direct entry references or any self-referenced pocket;
  `purgeAccount` purges pockets before the account. (`ledger_state_purge.dart`, `ledger_state_queries.dart`)
