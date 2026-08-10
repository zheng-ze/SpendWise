Task groups map to the commit sequence. Each group must leave `dart analyze` at zero issues and the
domain test suite green before the next begins. The user commits; do not run `git commit`.

## 1. Change and error types

- [x] 1.1 Add `lib/src/ledger_error.dart`: sealed `LedgerError implements Exception`, 10 cases
      (`idCollision`, `unknownAccount`, `unknownHolder`, `unknownCategory`, `unknownEntry`,
      `zeroAmount`, `selfTransfer`, `categoryTooDeep`, `categoryKindMismatch`, `inactiveReference`),
      id payloads where the spec assigns one, hand-written value `==`/`hashCode`
- [x] 1.2 Add `lib/src/ledger_change.dart`: sealed `LedgerChange`, 7 cases (`upsertAccount`,
      `upsertPocket`, `upsertCategory`, `upsertEntry`, `deleteMoneySource`, `deleteCategory`,
      `deleteEntry`), value equality, `targetID` declared abstract on the base so a new case cannot
      compile without it
- [x] 1.3 Add the `LedgerChange.upsertSource(MoneySource)` factory dispatching account versus pocket
- [x] 1.4 Test: equality by case and payload for both hierarchies, including cross-case inequality
- [x] 1.5 Test: `targetID` returns the right id for all 7 cases

## 2. Container and queries

- [x] 2.1 Add `lib/src/ledger_state.dart` with the three id-keyed maps defaulting to empty
- [x] 2.2 Add `ledger_state_queries.dart` as a `part of`: `activeSources`, `activeCategories`,
      `binnedSources`, `binnedCategories`
- [x] 2.3 Add `activeAccounts` and `activePockets(account)`, both name-sorted ascending, active only
- [x] 2.4 Add `sourceName(id)`: account name, `"Parent/Child"` for an owned pocket, bare name when
      unowned, null for a null or missing id
- [x] 2.5 Add `entriesReferencing(holderID)`, `entryCount(ids)`, `entryCountReferencing(categoryID)`
- [x] 2.6 Test: pin every query, including the `"Parent/Child"` form and the set-count union

## 3. Account and pocket mutators

- [x] 3.1 Implement `addAccount`: id collision across the whole money-source table, pocket links forced
      empty, returns one upsert
- [x] 3.2 Implement `updateAccount`: `unknownAccount` when missing or a pocket, pocket links restored
      from the stored account, `statementDay` kept only for cards
- [x] 3.3 Implement `addPocket`: parent check first, then collision, then `inactiveReference` on a
      non-active parent, insert plus parent link, returns `[upsertPocket, upsertAccount]` in that order
- [x] 3.4 Implement `updatePocket`: `unknownHolder` when missing or an account, wholesale replace,
      parent link untouched
- [x] 3.5 Add `test/support/builders.dart` (savings `account()` named "acc", expense `category()` with
      `"#888888"` / `"tag"` / analysis included). No `apply.dart`: Swift's `applyIgnoringChanges` only
      silenced a missing `@discardableResult`, and Dart does not warn on an ignored return value
- [x] 3.6 Port test group A (3): pocket attachment, unknown parent, id collision across the shared space
- [x] 3.7 Port test group G (7): the account create and edit surface
- [x] 3.8 Port the pocket half of test group I (2): field replacement, unknown id throws

## 4. Entry validation and entry mutators

- [x] 4.1 Implement `_validated(entry, {previous})` as a literal top-to-bottom sequence of the 9 checks;
      do not factor it into composed validators
- [x] 4.2 Implement `addEntry` and `updateEntry`, the latter running the dereference sweep over dropped
      holders and a changed category, returning `[upsertEntry] + sweepChanges`. `_tombstoneDereferenced`
      is a stub returning `[]` until 7.6
- [x] 4.3 Implement `setOpeningBalance`: holder check first, zero is a no-op after it, synthetic entry
      named "Opening balance", no category, excluded from analysis
- [x] 4.4 Implement `deleteEntry` as a hard delete followed by the sweep
- [x] 4.5 Port test group B (5) and group J (1), including negative-transfer normalization and positive
      transfer stored unchanged
- [x] 4.6 Port test group C (3): opening balance
- [x] 4.7 Port the non-lifecycle half of test group H (5); assert on stored entry fields where the Swift
      test asserted through `balance`
- [x] 4.8 Test the observable check order explicitly: zero amount beats an unknown source, and a
      categorised transfer with a bad destination yields `categoryKindMismatch`

## 5. Category mutators

- [x] 5.1 Implement `addCategory` and `updateCategory` with the shared parent validation in order:
      unknown parent, parent depth, kind mismatch. Parent lifecycle is unchecked because
      `SpendWise_Code_Critique_v2.md` item 3 resolved the orphaned-child problem with the lifecycle
      cascades (archive cascade, restore blocking, explicit purge) rather than an add-path guard
- [x] 5.2 Port test group D (2): nesting depth and unknown parent
- [x] 5.3 Port test group E (5): the kind rules, including transfer-with-category
- [x] 5.4 Port the category half of test group I (1): update replaces fields in place

## 6. Archive and restore

- [x] 6.1 Implement `deleteAccount`: active-account guard, archive plus active-pocket cascade, links
      kept, entries untouched, no plan cascade (out of MVP scope)
- [x] 6.2 Implement `deletePocket` and `deleteCategory`, the latter cascading to active children only
- [x] 6.3 Implement `restoreAccount`, `restorePocket` and `restoreCategory` (blocked while an archived
      parent exists). PORT FIX on `restorePocket`: Swift blocked only on an `archived` parent, which let
      a pocket be restored under a `referenceOnly` one. A pocket may never outlive its parent, so any
      non-active parent blocks it. Recorded in §3.7 of `docs/modules/domain_models.md`
- [x] 6.4 Port the archive and restore subset of test group F, plus group K (3) wrong-flavor no-ops

## 7. Purge, the dereference sweep, and the §7 fix

Indivisible: the corrected rules interlock across four call sites, so a partial landing is red.

Tests in this group assert that no public API *produces* an illegal state. They never seed one by
hand and assert how a mutator responds: an orphan pocket cannot arise through the API, so its
behavior is undefined and pinning it would freeze an accident into the suite.

Group 7 keeps `Account.subPocketIDs` as the link direction. Inverting it onto `SubPocket.parentID`
was weighed and rejected: the guards do not go away (`_willOutliveParentCategory` is the same guard
on the `parentID` side), accounts and pockets share one id space so a `String parentID` would admit
pocket-parented-to-pocket, self-parenting and cycles, and `netWorth` would turn O(accounts) into
O(accounts x sources). The one real cost of the current direction is `sourceName` paying an
O(accounts) scan per rendered row; revisit only with measurements from the real UI.

- [x] 7.0 Close the mutable-map hole first, since it is what actually admits the illegal states.
      Back `moneySources`, `entries` and `categories` with private fields and expose
      `UnmodifiableMapView` getters, so every write goes through a mutator. Move the test fixtures
      that poke the maps directly onto the `LedgerState(moneySources: {...})` constructor. Without
      this, one direct write reproduces a pocket with two parents, an order-dependent
      `_owningAccount`, and an orphan active pocket that no guard can catch
- [x] 7.1 Write the three regression tests first and confirm each fails against unfixed behavior:
      `purgeAccountWhoseEntriesOnlyReferenceItsPocketsKeepsItReferenceOnly`,
      `deletingLastDirectEntryKeepsAccountWhilePocketStillReferenced`,
      `lastPocketTombstoneCascadesToDereferencedParent`
- [x] 7.2 Implement the corrected reference rule: an account is referenced by direct entries or by any
      surviving pocket in its links; pockets keep the direct-count rule. Landed as `_isReferenced` in
      `ledger_state_queries.dart`. PORT FIX on §7 clause 1, recorded there: a pocket counts only when
      it is *itself* referenced by the same rule, rather than merely having a row in `moneySources`.
      Presence trusts `subPocketIDs`, so a pocket row that failed to clear would pin its parent at
      `referenceOnly` with nothing left to re-examine the link. The rules diverge only for a surviving
      pocket with zero entries, which 7.3's atomic detach makes unreachable. Carries an
      `unused_element` warning until 7.4 and 7.6 call it
- [x] 7.3 Implement `_detachAndTombstonePocket` as the *only* path that removes a pocket row: detach
      from the parent and delete the row in one mutation, emitting the parent upsert before the
      pocket deletion. Sole-remover is the point, since it makes a dangling link and a surviving
      detached row unreachable by construction rather than by convention. Uses the already-written
      and currently unused `Account.removeSubPocket`
- [x] 7.4 Implement `purgeAccount` with pockets purged first and the account last, and `purgePocket`,
      both routing every pocket-row removal through 7.3. Share the holder rule as `_purgeHolder`, and
      snapshot `subPocketIDs` before the loop since detaching mutates the set being iterated
- [x] 7.4a Test the detach and the row removal as one step, since a half-applied pair is exactly the
      orphan this group exists to prevent: after removing a pocket the parent's links no longer
      contain it *and* its row is gone, neither one without the other. Assert on the emitted change
      list too, since a caller replaying `UpsertAccount` without the following `DeleteMoneySource`
      would rebuild the orphan downstream. Drive it through `purgePocket`, not the private
      `_detachAndTombstonePocket`: widening that method's visibility to reach it from a test would
      defeat the sole-remover property 7.3 exists to establish
- [x] 7.5 Implement `purgeCategory`, sweeping children regardless of lifecycle
- [x] 7.6 Implement `tombstoneDereferenced`: holders first then category, never tombstoning an account
      with surviving pockets, cascading to a dereferenced parent when its last pocket tombstones.
      Routes pocket removal through 7.3. The cascade recurses through `_sweepHolder` on the former
      parent, which terminates because a pocket cannot own pockets
- [x] 7.6a Test that tombstoning an account takes its pockets with it: no pocket row outlives the
      account row that held it, through every route that removes an account. This replaces the
      orphan-restore test deleted in 7.0, which seeded an orphan by hand and asserted how
      `restorePocket` treated it. Orphan *behavior* is undefined and must not be pinned; that no
      public API *produces* one is the property worth testing, and the cascade is where it can break
- [x] 7.7 Port the purge subset of test group F and the lifecycle half of group H. An audit against
      the inventory found 11 of the 12 items already covered by the tests written across 7.1 to 7.6a,
      so porting them again would have produced near-duplicates. The one real gap was the category
      branch of `_tombstoneDereferenced`, which no test reached: every `DeleteCategory` in the suite
      came from `purgeCategory`, never from the sweep. Closed by
      `test/ledger_state_category_sweep_test.dart`, which also pins the holders-before-category order
- [x] 7.8 Resolve the null-parent ambiguity in `_willOutliveParentAccount`. RESOLVED BY 7.3, not by
      splitting the boolean. The task assumed the null-parent case was reachable, which it no longer
      is: `addPocket` is the only path that inserts a pocket row and it writes the parent link in the
      same step, and `_detachAndTombstonePocket` is the only path that removes one and it detaches in
      the same step, so `_owningAccount` cannot return null for a stored pocket. The two callers were
      also not in conflict, since blocking a restore and clamping an update are both the conservative
      action for their own operation. Splitting the boolean would have added a parameter to
      distinguish a case that cannot arise, so the branch keeps its guard and gains a one-line comment
      naming both meanings. Clause 11 in group 8 is where an assert on this belongs
- [x] 7.9 Test that the illegal states are unreachable through the public API now that the maps are
      closed: a pocket cannot end up in two accounts' links, `_owningAccount` cannot depend on map
      insertion order, and no mutator sequence leaves a detached pocket row alive. Rewrite the
      `hasOrphanActivePocket` helper so it detects an orphan from the pocket row rather than from
      `subPocketIDs`, which currently defines half the case away. Replaced by
      `expectNoOrphanPocket` (unclaimed rows and dangling links, all lifecycles, matching the copy in
      `ledger_state_account_cascade_test.dart`) plus `expectNoPocketOutlivingItsParent`, which keeps
      the group's original lifecycle claim as its own check. The old helper searched `activeAccounts`
      for active pockets only, so a pocket under an archived account read as an orphan by
      construction. All six original tests still pass against the stricter pair, so nothing was being
      masked. `addAccount` never forwards `subPocketIDs` to the constructor and `updateAccount`
      restores them from the stored row, which is what makes double-linking unreachable

## 8. Recurring Plans

Pulled ahead of the invariants so clauses 7 and 8 are written once against real plan data instead of
being added now and amended later. `docs/modules/domain_models.md` §3.5 is the behavior spec.

- [x] 8.1 Add `recurrence_frequency.dart`: int-coded enum `weekly(0)`, `biweekly(1)`, `monthly(2)`,
      `quarterly(3)`, `yearly(4)`, with a `stepFrom(DateTime anchor, int k)` that adds the k-th stride.
      Weekly and biweekly add days; monthly, quarterly and yearly add months or years and **clamp** to
      the last valid day of the target month. Dart's `DateTime(y, m, d)` overflows a short month
      instead of clamping, so a Jan 31 monthly plan would land on Mar 3 without an explicit clamp.
      Every stride is measured from the anchor, so clamping never accumulates: Jan 31 monthly gives
      Feb 28 then Mar 31, not Mar 28. Covered by `test/recurrence_frequency_test.dart` (10 tests)
- [x] 8.2 Add `occurrence_id.dart`: deterministic UUIDv5 of `(planID, occurrence day)` so two devices
      resolving the same occurrence converge on one entry id. Fixed app-wide namespace
      `8b9e0c42-5f3a-4d71-9c2e-1a6b7f0d3e85`, name string `'<planID>|<secondsSince2001>'` where the
      day is the UTC start of day and the offset is measured from 2001-01-01 UTC, not the Unix epoch.
      The `uuid` package already exposes `v5`, so no new dependency is needed and the `crypto` note
      in the proposal does not apply. Emit the id lowercase so it satisfies the id rule.
      The plan id is normalized before hashing, so a caller passing an uppercase id cannot mint a
      second id for the same occurrence. Covered by `test/occurrence_id_test.dart` (7 tests)
- [x] 8.3 Add `entry_template.dart`: `EntryTemplate` with `amount`, `name`, `categoryID`, `sourceID`,
      `destinationID`, `includeInAnalysis`, implementing `HolderReferencing`, plus
      `makeEntry(planID, date)` building the occurrence entry with the id from 8.2. Covered by
      `test/entry_template_test.dart` (6 tests)
- [x] 8.4 Add `recurring_plan.dart`: `RecurringPlan` with `id`, `template`, `frequency`, `anchor`,
      `endDate`, `lastResolvedDate`, plus `nextOccurrence(onOrAfter)`, `isExhausted(asOf)` and
      `occurrences(after, upTo)`. `occurrences` is exclusive of `after` and inclusive of the ceiling
      (`min(endDate, upTo)`), matching the half-open convention used everywhere else. Also carries
      `resolvedAt(date)`, the cursor-only copy the resolve sweep advances through. Covered by
      `test/recurring_plan_test.dart` (16 tests)
- [x] 8.5 Add `PlanFailure` (`planID`, `occurrence`, `error`) — a per-occurrence validation failure,
      distinct from a plan reaching its end date, which is silent and expected. `error` is typed
      `LedgerError` rather than `Object`, since every failure path runs through entry validation
- [x] 8.6 Add the two `LedgerChange` cases `UpsertPlan` and `DeletePlan`, and the two `LedgerError`
      cases `UnknownPlan` and `ExhaustedPlan`, bringing `LedgerChange` to 9 cases and `LedgerError`
      to 12
- [x] 8.7 Add the `_plans` map to `LedgerState` behind an `UnmodifiableMapView`, matching the three
      existing tables
- [x] 8.8 Add `addPlan` / `updatePlan` with the §3.5 validation in order: source resolves and is
      active, destination the same when non-null, category resolves, matches the template's implied
      kind and is active when non-null, then `endDate != null && lastResolvedDate >= endDate` throws
      `ExhaustedPlan`. **No prior-reference exemption** — unlike `updateEntry`, a plan template always
      requires active holders, on update too. PORT FIX: the kind check is hoisted to write time rather
      than deferred to the sweep as the Swift does, since a template's kind is fixed by its own fields
      and a mismatch would otherwise fail every occurrence forever. `isTransfer` / `kind` /
      `expectedCategoryKind` moved onto `HolderReferencing` so `Entry` and `EntryTemplate` share one
      definition of the rule
- [x] 8.9 Add `deletePlan`: hard delete, since plans are regenerable config rather than history.
      Missing id returns `[]`
- [x] 8.10 Add `resolvePlans(DateTime now)` returning changes and failures. Per plan: occurrences
      ascending, skip an occurrence whose id is already in `entries` (already materialized), otherwise
      validate and either store it or record a `PlanFailure` and continue. Failures never abort the
      sweep. Then advance a copy to `lastResolvedDate = now` and either retire it when exhausted or
      re-store it when something was due. Nothing due and not exhausted emits nothing and writes
      nothing. Within one plan: entry upserts date-ascending, then the plan's own upsert or delete
- [x] 8.11 Add the `removePlansReferencing(Set<String>)` cascade helper and wire it into
      `deleteAccount` as step 3, hard-removing every plan whose template touches the account or any of
      its pockets and appending a `DeletePlan` each. Plans are config, so they do not archive
- [x] 8.12 Port test group `RecurringPlanTests`, plus the month-end clamp case from 8.1, the
      already-materialized skip and the failure-does-not-abort property from 8.10

## 9. Invariants

- [x] 9.1 Add `ledger_state_invariants.dart` as a `part of` with all 11 clauses, including the clause 11
      amendment that lets a surviving pocket satisfy a reference-only account, and clauses 7 and 8
      (dangling plan reference, exhausted plan stored) now that group 8 has landed. With 7.0 and 7.3
      landed these are a backstop against future mutators, not the primary defense: link exclusivity
      and the no-orphan clause should already hold by construction, so a clause that fires is a bug in
      a mutator rather than a state to repair
- [x] 9.2 Wire the check to run inside `assert(...)` after every mutation, and expose it for on-demand
      use from tests
- [x] 9.3 Port test group L (1) and add coverage for the orphan-pocket and account-via-pocket clauses

## 10. Adversarial review fixes

Findings from the review pass run after group 9. Ordered by severity; do these before the parity
work so group 11 ports against fixed behavior.

- [x] 10.1 Fix the `isExhausted` boundary, which disagrees with invariant clause 8. Clause 8 rejects
      a stored plan whose `lastResolvedDate` is not strictly before `endDate`, but `isExhausted`
      uses `end.isBefore(asOf)`, so a plan resolved exactly ON its end date is not considered
      exhausted and `resolvePlans` stores it instead of retiring it. That stored state then trips
      clause 8 from inside `resolvePlans` itself. Reproduce with a monthly plan whose `anchor` and
      `endDate` are both `2026-03-01`, then `resolvePlans(DateTime.utc(2026, 3, 1))`: the occurrence
      materializes, the cursor advances to `endDate`, and the sweep throws
      `Ledger invariant 8 violated: plan ... is stored exhausted`. Change the comparison to
      `!end.isAfter(asOf)` so a plan retires once its final occurrence is resolved, and add a test
      at the exact-boundary case. Note this only surfaces under assertions; `dart run` with
      assertions off silently stores the dead plan
- [x] 10.2 Fix the `updateCategory` kind swap. A category may be edited from `income` to `expense`
      (or back) after creation, leaving stored entries whose sign contradicts their category kind and
      children whose kind no longer matches their parent, since nothing propagates the new kind
      downward. `addEntry` and `_validatePlan` both enforce the kind rule at write time, so this is
      the one door left open. RESOLVED as an immutability rule rather than the reference guard
      originally proposed: guarding on references cannot close the hole, because a parent kind swap
      breaks clause 5 with an empty entry table. `updateCategory` now rejects any change to `kind`
      with `CategoryKindMismatch`. This deviates from Swift, which stores the category verbatim, so
      the PORT FIX is recorded in `specs/ledger-mutations/spec.md`
- [x] 10.3 STALE FINDING, no production change. The review claimed only `deleteEntry` calls
      `_tombstoneDereferenced`, but `updateEntry` has run the sweep against its prior holders and
      category since commit `ac508d6`, and the category branch was already covered by
      `ledger_state_category_sweep_test.dart` ("retargeting the last entry off it removes the
      category row"). The transfer source/destination swap in `_validated` is harmless here: the
      difference is taken against `_validated`'s return value and `holderIDs` is an unordered set, so
      a swap yields an empty difference. One real gap did sit behind the finding and is now closed:
      the HOLDER branch was never exercised through `updateEntry`, only through `deleteEntry`. Added
      `retargetingATransferOffItsDestinationRemovesTheDereferencedRow` to
      `ledger_state_reference_rule_test.dart`, asserting the dereferenced row is gone rather than
      only that `DeleteMoneySource` was emitted
- [x] 10.4 Audit the raw-constructor test setups. Several tests build `LedgerState` directly into
      states no mutator sequence can reach, so they assert against fiction. Rebuild each via real
      mutator calls, or delete the test if the state is genuinely unreachable. Two were already
      converted in group 9; the rest remain. CONSIDERED AND KEPT: `recurring_plan_test.dart` "is
      false while the end date is still ahead" carries `lastResolvedDate` past `endDate`, which
      clause 8 forbids, but it never constructs a `LedgerState` — `RecurringPlan` is a plain value
      object with no such invariant, so it is legitimate unit coverage of the `asOf` conjunct.
      DONE: 13 sites converted across `ledger_state_category_sweep_test.dart` (5),
      `ledger_state_reference_rule_test.dart` (3), `ledger_state_account_cascade_test.dart` (4) and
      `ledger_state_queries_test.dart` (the `stateWith` helper and all 10 of its callers, so the
      helper itself is gone). The recipe throughout: file the entry while the holder is still
      active, then `deleteX` and `purgeX` to drive the row to `referenceOnly`, since `_validated`
      rejects an inactive source at write time. Every converted test passed with its original
      expectations unchanged, including the two that assert exact emitted change lists.
      ONE TEST DELETED: `ledger_state_queries_test.dart` "an unowned pocket yields its bare name"
      seeded a pocket row no account claims. Group 7.3 made `_detachAndTombstonePocket` the sole
      pocket remover and it detaches in the same mutation, so that row is unreachable through the
      public API and 7.9 already pins its unreachability. Per group 7's rule that orphan behavior is
      undefined and must not be frozen into the suite, the test was removed rather than converted.
      KEPT RAW BY DESIGN: the 6 sites in `ledger_state_invariants_test.dart`. That file exists to
      prove `assertInvariants` catches illegal states, which are unreachable by construction — that
      is the point of the file, and its first test is named "the raw constructor stores what it is
      given without validating". Converting them would delete the coverage
- [x] 10.5 Close the `LedgerError` coverage gap: the error tests assert the throw but not that state
      is untouched afterwards, so a mutator that half-applied before throwing would still pass.
      DONE: added the untouched-state assertion to 6 tests in `ledger_state_entries_test.dart`
      (the 5 validation throws plus `updateEntry`'s unknown-id), 1 in
      `ledger_state_categories_test.dart` (unknown parent) and 2 in `ledger_state_lifecycle_test.dart`
      (a new entry naming an archived holder, and one naming an archived category). The task's cited
      line numbers were stale after group 10.1–10.3; the test names are authoritative. The sweep of
      the remaining `LedgerError` sites found `ledger_state_plans_test.dart` already asserting
      untouched state at all 13 of its throws, so no change was needed there.
      VERIFIED LOAD-BEARING: temporarily reordering `addEntry` to store before validating made
      exactly the 9 new assertions fail, and nothing else
- [x] 10.6 Point the tests at the barrel. Eight test files import `package:domain/src/...`
      directly, which is why the missing plan exports in 12.1 went unnoticed: the suite never
      exercises the public surface. DONE: all 8 switched to `package:domain/domain.dart`, and zero
      `package:domain/src/` imports remain under `test/`. 12.1 was pulled forward to unblock this,
      and the migration is what proves the barrel now covers the public surface: the suite would not
      compile otherwise
- [x] 10.7 Add idempotency and emission-order coverage for the mutators that lack it, rather than
      leaving both properties to the group 11 parity tests. DONE: added the group "repeating a
      lifecycle mutator changes nothing" to `ledger_state_lifecycle_test.dart` — 8 tests covering
      `deleteAccount`, `restoreAccount`, `purgeAccount`, `deletePocket`, `deleteCategory`,
      `restoreCategory`, `purgeCategory` and `deleteEntry`, each asserting the second call returns
      `[]` and leaves the table byte-identical to a snapshot. This pins the "delete, restore and
      purge SHALL NOT throw; a no-op returns an empty change list" clause in
      `specs/ledger-mutations/spec.md`. Emission ORDER is left where it already lives: the exact
      change-list assertions in the cascade and sweep tests, with anything further belonging to
      11.1's matchers

## 11. Change-emission parity

- [x] 11.1 Add `test/support/matchers.dart` with both matchers: exact ordered list, and containment plus
      relative position for groups derived from unordered iteration. RESOLVED WITHOUT THE FILE. Dart's
      built-ins already provide both shapes: `expect(changes, [...])` is the exact ordered list, and
      `containsAllInOrder` is containment plus relative position. A `matchers.dart` would have wrapped
      them with no added strength, so it was not written. The requirement's real intent — never pin the
      order of a group that comes from unordered iteration, per the ordering clause in
      `specs/ledger-mutations/spec.md` — is honored in the two places it actually bites, both added
      under 11.2: the `deleteAccount` cascade (holders archive from a set, so only
      "holder upserts precede the plan deletes" is pinned) and the `deleteCategory` cascade (children
      come from an unordered scan, so only "parent precedes children" is pinned). Do not re-add the
      file on a later audit
- [x] 11.2 Port test group M (15), choosing the matcher per assertion. AUDITED BEFORE PORTING, and 11 of
      the 15 were already covered by tests asserting the exact returned change list — porting all 15
      verbatim would have produced 11 near-duplicates, the same outcome 7.7 rejected. The suite is
      organized by behavior rather than by Swift group letter, so the 4 real gaps were closed in place
      instead of in a new file. Coverage map, by the Swift name in `docs/modules/domain_models.md`:
      1 `addAccountEmitsUpsert` — `ledger_state_holders_test.dart:133`;
      2 `updateAccountEmitsUpsertOfStoredAccount` — `:215` for the pocket-link restore, and the
      statementDay-forced-null clause was the gap: `:183` asserted it on state only, so it now also
      asserts the emitted payload for a card edited to a non-card type;
      3 `addPocketEmitsPocketAndParentUpsert` — `:24`, exact order;
      4 `updatePocketEmitsUpsert` — `:253`;
      5 `addEntryEmitsUpsertOfStoredEntry` — WAS THE GAP: every `UpsertEntry` list assertion came from
      the transfer-normalization or opening-balance path, and the `addEntry` group held only a
      duplicate-id test. Added "emits an upsert of the stored entry" to
      `ledger_state_entries_test.dart`;
      6 `addEntryEmitsNormalizedTransfer` — `ledger_state_entries_test.dart:112`;
      7 `updateEntryEmitsUpsert` — `:187`, one change when nothing was dropped;
      8 `setOpeningBalanceEmitsEntryUpsert` — `:142`;
      9 `setOpeningBalanceOfZeroEmitsNothing` — `:154`;
      10 `addCategoryEmitsUpsert` — `ledger_state_categories_test.dart:238`;
      11 `updateCategoryEmitsUpsert` — `:167`;
      12 `deleteEntryEmitsDelete` — `ledger_state_entries_test.dart:235`;
      13 `deleteAccountEmitsArchiveUpsertsAndPlanDeletes` — WAS THE GAP: its four clauses were split
      across three tests, and the one asserting the exact list had no plan in its fixture while the one
      asserting `DeletePlan` checked neither the archive upserts nor the absence of
      `DeleteMoneySource`. Added "archives the holders and drops the plan without deleting rows" to
      `ledger_state_plans_test.dart`, covering all four in one scenario. VERIFIED LOAD-BEARING:
      removing the `_removePlansReferencing` call from `deleteAccount` makes it fail;
      14 `deletePocketEmitsPocketUpsertOnly` — `ledger_state_lifecycle_test.dart:143`, with an entry
      referencing the pocket;
      15 `deleteCategoryEmitsArchiveUpserts` — WAS THE GAP: asserted `changes.first` plus a length, so
      the two child upserts were never identified. `ledger_state_lifecycle_test.dart:167` now pins all
      three payloads while keeping its entry-keeps-`categoryID` clause

## 12. Barrel and final gate

- [x] 12.1 Add `lib/domain.dart` exporting the public surface: models, enums, `LedgerState`,
      `LedgerChange`, `LedgerError`, id helpers, and the plan types from group 8. PULLED FORWARD
      into the group 10 pass, because the missing plan exports were the defect sitting behind 10.6
      rather than a loose end of the final gate. The barrel already carried 13 exports but none of
      the 6 plan files, so `resolvePlans` (returns `PlanResolution`) and `addPlan` (takes
      `RecurringPlan`) were public methods whose types no consumer could name. Added
      `entry_template`, `occurrence_id`, `plan_failure`, `plan_resolution`, `plan_scheduling`
      and `recurring_plan`. `plan_resolution` and `plan_failure` are part of the public RETURN
      surface, so both belong here, not only the types named in parameters
- [x] 12.2 Verify the full gate: `cd packages/domain && dart format . && dart analyze && dart test` at
      zero analyzer issues, then `cd app && flutter analyze`. GREEN: `dart format` reports 44 files, 0
      changed; `dart analyze` "No issues found!"; `dart test` 310 passing across 21 files;
      `flutter analyze` "No issues found!"
- [x] 12.3 Confirm the ported suite covers all 68 Swift scenarios plus the 3 regression tests, and
      report green to the user for committing. CONFIRMED against the Swift source rather than the
      inventory alone: `SpendWiseTests/LedgerStateTests.swift` holds exactly 68 `@Test func`, matching
      the per-group counts in `docs/modules/domain_models.md` (A3 B5 C3 D2 E5 F14 G7 H6 I3 J1 K3 L1
      M15 = 68). `RecurringPlanTests.swift` holds 20, covered by group 8.12. The 3 §7 regression tests
      are in `test/ledger_state_reference_rule_test.dart` under their Swift names
      (`purgeAccountWhoseEntriesOnlyReferenceItsPocketsKeepsItReferenceOnly` :12,
      `deletingLastDirectEntryKeepsAccountWhilePocketStillReferenced` :36,
      `lastPocketTombstoneCascadesToDereferencedParent` :100). Group N's pinned enum-code tests are in
      `test/enum_codes_test.dart`, one "codes are pinned" per int-coded enum plus a `fromCode`
      rejection each. The Dart suite runs 310 tests against the Swift 68 because a single Swift
      scenario often became several focused Dart tests, and because groups 7 to 10 added coverage with
      no Swift counterpart: the orphan-pocket and lifecycle invariants, the dereference sweep's holder
      and category branches, the plan resolve sweep, idempotency of every delete/restore/purge, and
      the untouched-state half of the error tests

## 13. Adversarial review remediation

Findings from the final adversarial review run before UI work. Four parallel audits (Swift-reference
parity, invariants and state machine, test-suite mutation testing, API and UI readiness) plus direct
verification. Every item below was reproduced empirically with a throwaway probe or a source mutation,
not inferred from reading. Probes were deleted and the tree verified clean at 310 passing after each.

Standing ruling from the user for this group: the Swift app is a behavioral REFERENCE, not a
conformance target. Where the Dart is better, the Dart wins and the spec text is what gets corrected.

### 13.A Invariant coverage

Settled: `assertInvariants` is a DEBUG-ONLY bug-catching tripwire. It stays inside `assert(...)`, it
does not roll back, and release builds strip it. That is the design, not a defect. What follows is
therefore about making the tripwire catch more, not about turning it into a guard.

One structural observation drives most of this group. Every existing clause is a SNAPSHOT predicate
over a single state. Some of the worst bugs found in review are TRANSITION violations, illegal only
relative to the previous state, and no snapshot predicate can see them. Clause 12 below is the first
of that kind and needs a before/after hook rather than a pass over the maps.

- [x] 13.1 Add clause 12, the lifecycle-monotonicity transition check, so 13.3 stops being silent.
      Lifecycle may only move toward less alive, with `restoreAccount`/`restoreCategory`
      (`ledger_state.dart:399`, `:437`) the sole sanctioned back-edge and only from `archived`. Since
      this cannot be expressed as a snapshot, add a debug-only before/after comparison: capture the
      lifecycle of every money source and category at mutator entry, compare after, and throw when a
      row moved to a more-alive state without going through a restore mutator. Keep it inside the same
      `assert(...)` discipline as `_checked` so release builds pay nothing. `LifecycleState`
      (`lifecycle_state.dart:27`) already exposes `isAtLeastAsAliveAs`, which is the comparison to use
- [x] 13.2 Correct the earlier clause-2 note. Clause 2 DOES have throw sites,
      `ledger_state_invariants.dart:41` and `:49`. The review flagged a possible numbering gap and that
      flag was wrong; no numbering gap exists. This item is bookkeeping only, no code change.
      RESOLVED: confirmed both throw sites present, and the stale re-check instruction removed from
      13.13 so a later audit cannot revive the claim

### 13.B Reachable state corruption

Each reproduced by probe. In debug these now surface via the clauses added in 13.A and 13.C; in
release they still land silently, which is the accepted cost of a debug-only checker.

- [x] 13.3 `referenceOnly` to `active` resurrection, currently SILENT (no clause fires, because the
      resulting state is a perfectly legal snapshot: an active account holding entries).
      `addAccount(A); addEntry(E on A); deleteAccount(A); purgeAccount(A); updateAccount(Account(id: A))`
      returns A to `active`. `restoreAccount` (`ledger_state.dart:399`) and `restoreCategory` (`:437`)
      deliberately gate on `== archived` to forbid exactly this; the update mutators hand it back.
      `referenceOnly` is terminal except for tombstoning (comment at `:407`). Same via `updateCategory`
      (`:205-221`). Fix the update mutators to preserve a `referenceOnly` lifecycle. Clause 12 from
      13.1 is what makes this visible in debug rather than silent
- [x] 13.4 Mutators store an arbitrary caller-supplied lifecycle unchecked, including `tombstoned`,
      which is documented persistence-only. `addAccount:72-82`, `updateAccount:89-102`,
      `updatePocket:124-128`, `updateCategory:217-221`. Two guard gaps explain it:
      `_willOutliveParentAccount:132-137` compares with `isAtLeastAsAliveAs` and `active <= tombstoned`
      is true, so tombstoning a pocket under an active parent is not "outranking"; and
      `_willOutliveParentCategory:226-234` returns false early when `parentID == null`, so root
      categories have no lifecycle guard at all
- [x] 13.5 Plans are invisible to every reference and purge path, so clause 7 breaks three ways.
      `_isHolderReferenced` (`ledger_state_queries.dart:71-82`) and `_isCategoryReferenced`
      (`ledger_state.dart:622-631`) count entries only; `deleteAccount:351` compensates with
      `_removePlansReferencing` and nothing else does. Holes: `purgeCategory` (no plan cascade on
      either `deleteCategory` or `purgeCategory`), `deletePocket`/`purgePocket` (`:367-375`, `:546-553`,
      the same archival transition as `deleteAccount` with the cascade missing), and the dereference
      sweep (`:649-665`, `:667-687`, where deleting the last entry sweeps a row out from under a live
      plan). Note `deletePlan` NOT sweeping is correct and is not part of this: the bug is rows
      vanishing under a plan, not the reverse
- [x] 13.6 A live child is accepted under a `referenceOnly` parent and then orphaned.
      `_validateParent:467-475` checks existence, depth and kind but never the parent's lifecycle; the
      doc comment at `:464` sanctions ARCHIVED parents, and `referenceOnly` was not considered. Adding
      a child under a `referenceOnly` parent then deleting the parent's last entry makes
      `_sweepCategory` delete the parent, leaving a live category pointing at a dead id (clause 5).
      Asymmetry to mirror: `purgeCategory:601-607` sweeps children "regardless of lifecycle" so the
      row cannot be outlived; `_sweepCategory` does the same deletion with no child sweep
- [x] 13.7 `updateCategory` reparenting never re-judges the old parent (clause 11). When a child moves
      off a `referenceOnly` parent whose only claim to referencedness was that child link, nothing
      calls `_sweepCategory(oldParent)`. `updateEntry:154-161` has exactly this sweep for dropped
      holders and category; `updateCategory:205-221` has no dropped-parent analogue
- [x] 13.8 An active account may hold a `referenceOnly` pocket and no clause forbids it. Clause 2
      checks link resolution and exclusivity, clause 3 checks orphanhood; neither compares parent and
      child lifecycle. The `isAtLeastAsAliveAs` rule is enforced on the write path only, so any path
      that changes the PARENT rather than the child escapes it. Add the invariant counterpart

### 13.C Coverage gaps proven by mutation testing

27 mutations run against the suite; 6 survived undetected. Each line below is a mutation that broke
NO test. I independently re-confirmed 13.9 and 13.11.

- [x] 13.9 "A transfer may not carry a category" is untested on all three of its implementations.
      Deleting the guard at `ledger_state.dart:494` (`_validated`), at `:279` (`_validatePlan`), or
      neutering clause 6 at `ledger_state_invariants.dart:106` each breaks zero tests. Reachable:
      `addEntry(amount: 50, categoryID: c, sourceID: a, destinationID: b)` throws
      `CategoryKindMismatch`. Add entry-path, plan-path and invariant tests.
      RESOLVED, with the original finding PARTLY CORRECTED. The two mutator guards are EQUIVALENT
      MUTANTS, not coverage gaps: with `expected == null`, the very next line `category.kind != expected`
      is always true and throws the identical `CategoryKindMismatch`, so deleting the guard changes
      nothing observable and no test can distinguish it. The behavior IS now tested on both paths; the
      line is merely redundant, and is kept as defensive documentation. Only the INVARIANT was a real
      gap: clause 6's two branches throw different messages, so its null branch is observable, and the
      new seeded test kills that mutation. The "breaks zero tests" signal was right; the inference
      "therefore untested" was wrong
- [x] 13.10 The `priorRefs` exemption is untested on the holder side. Deleting
      `!priorRefs.contains(entry.sourceID) &&` at `:485` or the `destinationID` twin at `:507` breaks
      zero tests. The CATEGORY twin at `:496` IS tested, so this is an oversight rather than a design
      choice. Assert that editing an entry whose holder is archived stays allowed and emits
      `UpsertEntry`, while adding a NEW entry on that holder still throws
- [x] 13.11 `resolvePlans` idempotency is untested and the test that names it is vacuous. Deleting
      `if (_entries.containsKey(entry.id)) continue;` at `:302` breaks zero tests.
      `test/resolve_plans_smoke_test.dart:47` "is idempotent, so a second sweep materializes nothing"
      passes for an unrelated reason: the first sweep advanced `lastResolvedDate`, so `occurrences()`
      returns empty and the guard is never reached. Rewind the cursor with
      `updatePlan(plan.resolvedAt(older))`, re-resolve, and assert no `UpsertEntry` is emitted.
      Mutant emits 2 duplicate upserts
- [x] 13.12 `_isHolderReferenced` recursion can be weakened to the exact form its own doc comment
      rejects. `ledger_state_queries.dart:79-81` `.any(_isHolderReferenced)` to `.isNotEmpty` breaks
      zero tests, though `:66-70` documents why row-existence is wrong ("would pin a parent at
      referenceOnly forever"). `purgeAccount` masks it since pockets sweep first; the `_sweepHolder`
      path does not.
      RESOLVED, with a correction: the SWEEP path cannot discriminate the mutation either, because
      `_detachAndTombstonePocket` removes the pocket from both the table and `subPocketIDs` BEFORE the
      parent is re-judged, so `.isNotEmpty` is false either way. Four sweep-based scenarios were probed
      and none discriminated. The working discriminator is the THIRD call site, clause 11 in the
      invariant checker, which judges a seeded state with no sweep in the way
- [x] 13.13 Invariant clauses 1, 4 and 6 are dead code: neutering each individually breaks zero tests
      (clause 5 breaks 21, clauses 3/7/8 one each). These are precisely the replay safety net for the
      seeding constructor, which validates nothing. Seed via
      `LedgerState(moneySources: {'wrong-key': AccountSource(acc)})`, an entry naming an absent holder,
      and a transfer carrying a category, asserting each trips `assertInvariants`

### 13.D Correctness defects found by direct reading

- [x] 13.14 `_addMonths` negative-month arithmetic is wrong. `recurrence_frequency.dart:41-43` mixes
      `~/` (truncates toward zero) with `%` (returns non-negative), so the year never decrements.
      Verified from anchor 2026-03-15: `monthly.stepFrom(a, -3)` gives 2026-12-15 instead of
      2025-12-15; `yearly.stepFrom(a, -1)` returns the anchor UNCHANGED. Unreachable internally (both
      callers iterate `k = 0; k++`) but `stepFrom` is exported, so a UI computing a previous occurrence
      gets a silently wrong date. Fix with Euclidean division:
      `final year = anchor.year + (rawMonth >= 0 ? rawMonth ~/ 12 : (rawMonth - 11) ~/ 12);`
      Secondary: a non-advancing `stepFrom` would hang the unbounded `for (var k = 0; ; k++)` loops at
      `recurring_plan.dart:35` and `:62`
- [x] 13.15 `statementDay` is never validated or clamped, though the tech doc mandates it.
      `Flutter_Port_Tech_Doc.md:41-43`: "only the FORM enforces the range; the domain passes it
      through, so the Dart domain must validate/clamp it itself, since drift rows and the future
      Realbyte import bypass the picker". Verified: 999 and -5 both store unmodified. `Tech_Doc:263`
      has the Accounts screen shipping "with the statement-day clamp fix", and card payable math builds
      a cut date from 999. This is a sanctioned PORT FIX that was not applied
- [x] 13.16 Entry dates are local-time and occurrence ids are timezone-sensitive.
      `recurrence_frequency.dart:61` preserves the anchor's zone, so a local-midnight anchor yields
      local-midnight entry dates, while `occurrence_id.dart:11-17` calls `.toUtc()` first, so
      `DateTime(2026,3,15)` at UTC+8 hashes as 2026-03-14. This is hazard 3 at `Tech_Doc:277-279`, "a
      timezone move cannot change generated ids": a device changing timezone regenerates already
      materialized occurrences under new ids, which the `containsKey` guard cannot catch. Also lands
      entries in the wrong month against the half-open UTC `[start, end)` windows (`project.md:53`).
      Distinct from 13.14 despite sharing a file
- [x] 13.17 `addAccount` does not clear `statementDay` for a non-card type though `updateAccount:96-98`
      does. Verified: a cash account keeps `statementDay: 15` on add, then silently drops it on the
      first edit. Make the two consistent

### 13.E Public surface, before UI

- [x] 13.18 Export `Decimal` from the barrel: `export 'package:decimal/decimal.dart' show Decimal;`.
      Every money value in the public API is a `Decimal` (`Entry.amount`, `EntryTemplate.amount`,
      `setOpeningBalance`), so a consumer importing only `package:domain/domain.dart` cannot name the
      type it must handle. Same class as the plan-exports defect fixed in 12.1. Without it every UI
      file needs a second import and `app/pubspec.yaml` needs a direct `decimal` dependency pinned
      compatibly with the domain's `^3.2.6`, where a skew becomes a type-identity error
- [x] 13.19 Give `PlanResolution` value `==`/`hashCode` (`plan_resolution.dart:5-11`), using
      `ListEquality` for its list fields. It is the only exported model without them, so a Riverpod
      provider returning it never compares equal to its predecessor and every `resolvePlans` rebuild
      re-fires listeners and re-shows the plan-error banner (`Tech_Doc:267`)
- [x] 13.20 Expose a public parent-lookup for a pocket. `_owningAccount`
      (`ledger_state_queries.dart:94`) is private and `SubPocket` deliberately knows nothing about its
      parent (`domain_models.md:93`), so a UI rendering pocket sub-rows or a move-pocket form re-scans
      all money sources, duplicating one line the domain already has

### 13.F New invariant clauses

Clauses to ADD, each one a state the review proved reachable that `assertInvariants` currently accepts.
Clause 12 is defined in 13.1; these continue the numbering. Every one is snapshot-expressible, so each
is a plain pass over the maps in the existing style. Add a test per clause seeding the illegal state
through the `LedgerState` constructor, which validates nothing and is the intended way to exercise the
checker (see 13.13).

- [x] 13.21 Clause 13, parent and child lifecycle coherence. A parent must be at least as alive as its
      children, for both accounts to pockets and categories to child categories. Reachable today:
      `addAccount(A); addPocket(P, A); addEntry(E on P); deleteAccount(A); purgeAccount(A);
      updateAccount(...)` leaves an active account holding a `referenceOnly` pocket and
      `assertInvariants` passes. Clause 2 checks link resolution and exclusivity, clause 3 checks
      orphanhood, and neither compares lifecycles. The `isAtLeastAsAliveAs` rule
      (`lifecycle_state.dart:27`) is enforced only on the write path in `updatePocket`/`updateCategory`,
      so every path that changes the PARENT escapes it. This is the invariant counterpart to 13.8
- [x] 13.22 Clause 14, no plan may reference a non-active row. Clause 7 checks only that a plan's
      holders and category EXIST, so a plan naming an archived or `referenceOnly` holder passes.
      `_validatePlan` (`ledger_state.dart:263`) requires an active source at write time, so any stored
      plan pointing at a non-active row got there through a cascade gap. This clause is what turns the
      three 13.5 holes into loud failures instead of silent drift
- [x] 13.23 Extend clause 5 to reject a live child under a non-active parent. The write path
      (`_validateParent:467-475`) deliberately permits an ARCHIVED parent
      (`ledger-mutations/spec.md:214-215`), so the clause must forbid only the `referenceOnly` and
      `tombstoned` cases to stay consistent with 13.6. Without it, the orphaning sequence in 13.6 is
      caught only after the parent is deleted, by which point the child's `parentID` already dangles
- [x] 13.24 Consider a clause asserting `statementDay` is null for non-card accounts and within 1 to 28
      for cards, once 13.15 lands. It pairs with the clamp: the mutator enforces the range on the write
      path, the clause catches a row that arrived through the seeding constructor or a future import.
      Sequence this AFTER 13.15 so the clause and the clamp agree on the boundary

### 13.G Spec text corrections, no code change

The code is right in each of these; the prose describes something else.

- [x] 13.25 `addPocket`'s lifecycle guard (`ledger_state.dart:110`) is real and load-bearing. Removing
      it fails exactly 2 tests, both named for the behavior. But three normative sources describe only
      two guards: `specs/ledger-mutations/spec.md:71-74`, `docs/modules/domain_models.md:222-227`, and
      `tasks.md:33`. Amend all three. Then reconcile the deliberate opposite rule for categories at
      `ledger-mutations/spec.md:214-215` ("The parent's lifecycle SHALL NOT be checked, so an active
      child may be added under an archived parent") with an explicit sentence on why pockets differ,
      or the asymmetry reads as an accident
- [x] 13.26 Record that category purge and sweep recurse into children. `_isCategoryReferenced`
      (`:622-631`) and `_sweepCategory` (`:649-665`) walk the child tree; the flat rule would delete a
      parent row while a child survives pointing at it, tripping clause 5, so the recursion is correct.
      But `domain_models.md:453` states clause 11 flatly as "Every referenceOnly category has at least
      one entry with its categoryID", which a parent kept alive solely by a child's entry does not
      literally satisfy. Also `domain_models.md:391-393` describes the sweep's category branch as a
      single-row check, and `ledger-lifecycle/spec.md:161-164` writes the re-check cascade for holders
      only. Update all three to state the recursive rule
- [x] 13.27 Record that occurrence ids intentionally do not reproduce the Swift app's. Swift builds the
      UUIDv5 name from `planID.uuidString`, which is UPPERCASE; `occurrence_id.dart:16` uses
      `normalizedID`, which is lowercase. Verified to yield different uuids for the same plan and day
      (`ad07cedc-...` versus `b75d3ff8-...`). Harmless under the reference-not-conformance ruling since
      the Flutter app is the sole writer, but `project.md:78-80` specifies the namespace and the 2001
      seconds epoch without mentioning case, so a later audit will re-raise it

### 13.H Follow-ups raised while remediating

Found while doing the work above, not in the original review.

- [x] 13.28 Reconcile the invariant clause numbering with the task text. The clauses were implemented
      in dependency order rather than task order, so the numbers landed as: 12 lifecycle monotonicity
      (13.1), 13 statement day (13.24), 14 plans may not reference a leaving row (13.22), 15 a pocket
      may not outlive its account (13.21). Task 13.21 calls its clause "13" and 13.24 calls its clause
      "the statementDay clause"; the code is self-consistent and tested, so this is task-text drift, not
      a code defect. Correct the task text and `docs/modules/domain_models.md`'s clause list so the two
      agree, and note that 13.23 extended the EXISTING clause 5 rather than adding a new one
- [x] 13.29 Entry dates are still local-time even though occurrence ids are now timezone-stable.
      13.16 fixed `OccurrenceID.make` to read calendar components directly, so ids no longer move with
      the device timezone. But `recurrence_frequency.dart` `stepFrom` still preserves the anchor's zone,
      so a local-midnight anchor yields local-midnight entry `date` values, which can fall in the wrong
      month against the half-open UTC `[start, end)` window filters (`project.md:53`). The fix is to
      normalize anchors to UTC where plans are constructed or occurrences generated, which is outside
      the two files 13.16 was scoped to. `docs/modules/plans_and_accounting.md:353` already mandates
      `startOfDay` = `DateTime.utc(d.year, d.month, d.day)` for all plan date math.
      FIXED: `startOfDayUtc` now lives in `lib/src/plan_scheduling.dart` beside the rest of the
      plan date math, and the
      `RecurringPlan` constructor normalizes `anchor`, `endDate` and `lastResolvedDate` through it.
      Because every occurrence is `stepFrom(anchor, k)`, normalizing the anchor makes the whole series
      UTC without touching `stepFrom`. `OccurrenceID.make` calls the same helper. Covered by a
      `date normalization` group in `recurring_plan_test.dart`; the full suite passes under TZ=UTC,
      Asia/Singapore, Pacific/Kiritimati and Pacific/Midway
- [x] 13.30 Sync `openspec/project.md` with `openspec/config.yaml`. The month-end bullet in
      `project.md` lacks the "every stride is measured from the anchor so clamping never accumulates"
      detail that `config.yaml:49-51` carries. Pre-existing drift, outside 13.27's scope, but CLAUDE.md
      requires the pair be kept in sync
