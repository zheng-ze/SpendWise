Task groups map to the commit sequence. Each group must leave `dart analyze` at zero issues and the
domain test suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/plans_and_accounting.md` §4 and §5, which are more
detailed than the specs in this change. Sections 1–3 of that file are the plans half and are done.

## 1. Balance primitives

- [x] 1.1 Add `lib/src/net_worth.dart`: `NetWorth` with `Decimal asset` and `Decimal liability`,
      hand-written value `==`/`hashCode` per the domain convention
- [x] 1.2 Add `lib/src/accounting.dart` with the `Accounting` namespace class and
      `applies(Entry, Set<String> sourceIDs)`: source must be in the set, a null destination passes on
      the source alone, a non-null destination must also be in the set
- [x] 1.3 Add `balance(of:entries:sourceIDs:)`: sum over applying entries — transfer contributes
      `+amount` to its destination and `-amount` to its source, non-transfer contributes its stored
      signed amount to its source. Starts at `Decimal.zero`
- [x] 1.4 Add `accountTotal(account, entries, sourceIDs, activePockets)`: own balance plus the balance
      of each sub-pocket in `activePockets`
- [x] 1.5 Test the gate and balances (see coverage map 6.1): `balanceNetsSignedTransactions`,
      `transactionOnlyAffectsItsOwnHolder`, `transferMovesBetweenHolders`,
      `deletedHolderUnappliesTransferToSurvivor`, `deletedSourceUnappliesTransferToSurvivor`
- [x] 1.6 Test account totals: `fundingPocketMovesOwnCashButNotAccountTotal`,
      `spendingFromPocketReducesPocketAndTotal`, `pocketToPocketAcrossAccountsMovesBothTotals`,
      `multiplePocketsSumIntoAccountTotal`, `archivedPocketDropsOutOfAccountTotal`
- [x] 1.7 Mutation-test the two `applies` guards: invert the source check, then the destination check.
      Each must kill at least one test. Restore from a file copy, never `git checkout`

## 2. Net worth

- [x] 2.1 Add `netWorth(ledger)`: existence set from `moneySources.keys`, active pockets from
      `ledger.activeSources`, iterate accounts only
- [x] 2.2 Gate each account on active lifecycle AND `includeInNetWorth`; split its total by sign,
      accumulating liability as a positive magnitude
- [x] 2.3 Test: `netWorthSplitsBySignNotType`, `netWorthExcludesFlaggedAccount`,
      `netWorthCountsPocketBalances`, `netWorthExcludesArchivedAccount`,
      `accountToAccountTransferIsZeroSumForNetWorth`, `emptyLedgerNetWorthIsZero`
- [x] 2.4 Test the archived-account nuance explicitly: an archived account is skipped as a *subject*
      but still counts as a transfer *endpoint*, so the counterparty's balance is unaffected by the
      archive. This is the failure mode the existence-set rule exists to prevent

## 3. Classification

- [x] 3.1 Add `lib/src/analysis_item.dart`: `AnalysisItem` with `String? bucketID`, `Decimal amount`,
      `DateTime date`, `CategoryKind kind`, value equality
- [x] 3.2 Add `lib/src/category_resolution.dart`: sealed `CategoryResolution` with `Excluded`,
      `Uncategorized`, `InCategory(String id)`
- [x] 3.3 Add `resolveCategory(entry, ledger)` in resolution order: null category → `Uncategorized`;
      id absent from `ledger.categories` → `Uncategorized`; `includeInAnalysis == false` → `Excluded`;
      parent present and excluded → `Excluded`; otherwise `InCategory`
- [x] 3.4 Add `classify(entry, sourceIDs, ledger)`: gate on `applies` and `entry.includeInAnalysis`,
      then switch on entry kind. Transfer → item only when the destination holder exists and has
      `incomingTransfersAsExpenses`, carrying the stored amount, null bucket, expense kind.
      Income/expense → resolve the category, then take `kind` from the signed amount BEFORE storing
      `abs(amount)`
- [x] 3.5 Add `analysisItems(ledger)`: one pass over `entries.values` with `sourceIDs` = all
      `moneySources` keys, dropping nulls. Output order unspecified — tests sort or use set semantics
- [x] 3.6 Test the gates: `normalExpenseProducesItemWithAbsoluteAmount`, `incomeProducesNoExpenseItem`,
      `plainTransferProducesNoExpenseItem`, `transferIntoTreatAsExpenseHolderProducesItem`,
      `excludedFromAnalysisEntryProducesNoItem`
- [x] 3.7 Test category resolution: `categoryExcludedFromAnalysisHidesItsExpenses`,
      `parentExcludedFromAnalysisHidesChildExpenses`, `uncategorizedExpenseIsIncluded`,
      `archivedCategoryStillBucketsUnderItsID`, `unresolvableCategoryRendersAsUncategorized`
- [x] 3.8 Test kind tagging: `analysisItemsTagExpenseAndIncomeSeparately`,
      `analysisItemsIncomeHonorsAnalysisExclusion`
- [x] 3.9 Mutation-test the ordering constraint in 3.4: take `abs` before deciding `kind`. If no test
      dies, the income/expense split is untested — add the test before proceeding

## 4. Filtering, totals, roll-up

- [x] 4.1 Add `filtered({kind, buckets, interval})` as an extension on `List<AnalysisItem>`, each null
      parameter meaning no constraint, `buckets` typed `Set<String?>` so null is selectable
- [x] 4.2 Interval filtering is half-open `[start, end)` — `start <= date < end`. This is a sanctioned
      deviation from Swift's closed `DateInterval.contains`; see `design.md`
- [x] 4.3 Add `total({kind, buckets, interval})` summing `filtered` from `Decimal.zero`
- [x] 4.4 Add `fraction(Decimal amount, Decimal over) -> double`: `over <= 0` returns `0.0`. The only
      sanctioned `double` in the domain — it is a presentation ratio, not money (`design.md`)
- [x] 4.5 Add `mainBucketID(String? leafID, LedgerState)`: null or absent leaf → null, else
      `parentID ?? leafID`
- [x] 4.6 Add `rollUp(items, state) -> Map<String?, Decimal>` grouping amounts by `mainBucketID`
- [x] 4.7 Test income totals: `incomeSumsPositiveNonTransferEntries`,
      `incomeIgnoresTransfersAndExcludedEntries`
- [x] 4.8 Test roll-up: `rollUpFoldsSubcategoriesIntoParent`, `rollUpBucketsTotalsPerChildAndDirect`,
      `rollUpUncategorizedFormsOwnBucket`
- [x] 4.9 Test the half-open boundary (Dart-only, required by 4.2): an item timestamped exactly on the
      instant shared by two adjacent month windows appears in the later window only

## 5. Barrel and close-out

- [x] 5.1 Export `accounting.dart`, `net_worth.dart`, `analysis_item.dart`, `category_resolution.dart`
      from `lib/domain.dart`; extend `test/barrel_exports_test.dart`
- [x] 5.2 Run `cd packages/domain && dart analyze && dart test` and `cd app && flutter analyze`.
      Analyzer at zero issues, not just zero errors
- [x] 5.3 Confirm no `double` reached `packages/domain/lib/` except `fraction`'s return:
      `grep -rn "double" packages/domain/lib/`
- [x] 5.4 Confirm the coverage map below is complete — every one of the 33 Swift scenarios maps to a
      Dart test that exists and passes

## 6. Coverage map — the 33 Swift scenarios

Audited before porting: no existing domain test covers any accounting behavior. The only prior hits
for these names are `includeInNetWorth` being stored in `ledger_state_holders_test.dart` and
`test/support/builders.dart`, neither of which exercises balance, net worth or analysis math. All 33
are therefore new, and none is redundant.

### 6.1 `AccountingTests.swift` — 16, all new

| Swift test | Ported by |
|---|---|
| balanceNetsSignedTransactions | 1.5 |
| transactionOnlyAffectsItsOwnHolder | 1.5 |
| transferMovesBetweenHolders | 1.5 |
| deletedHolderUnappliesTransferToSurvivor | 1.5 |
| deletedSourceUnappliesTransferToSurvivor | 1.5 |
| fundingPocketMovesOwnCashButNotAccountTotal | 1.6 |
| spendingFromPocketReducesPocketAndTotal | 1.6 |
| pocketToPocketAcrossAccountsMovesBothTotals | 1.6 |
| multiplePocketsSumIntoAccountTotal | 1.6 |
| archivedPocketDropsOutOfAccountTotal | 1.6 |
| netWorthSplitsBySignNotType | 2.3 |
| netWorthExcludesFlaggedAccount | 2.3 |
| netWorthCountsPocketBalances | 2.3 |
| netWorthExcludesArchivedAccount | 2.3 |
| accountToAccountTransferIsZeroSumForNetWorth | 2.3 |
| emptyLedgerNetWorthIsZero | 2.3 |

### 6.2 `AccountingAnalysisTests.swift` — 17, all new

| Swift test | Ported by |
|---|---|
| normalExpenseProducesItemWithAbsoluteAmount | 3.6 |
| incomeProducesNoExpenseItem | 3.6 |
| plainTransferProducesNoExpenseItem | 3.6 |
| transferIntoTreatAsExpenseHolderProducesItem | 3.6 |
| excludedFromAnalysisEntryProducesNoItem | 3.6 |
| categoryExcludedFromAnalysisHidesItsExpenses | 3.7 |
| parentExcludedFromAnalysisHidesChildExpenses | 3.7 |
| uncategorizedExpenseIsIncluded | 3.7 |
| archivedCategoryStillBucketsUnderItsID | 3.7 |
| unresolvableCategoryRendersAsUncategorized | 3.7 |
| incomeSumsPositiveNonTransferEntries | 4.7 |
| incomeIgnoresTransfersAndExcludedEntries | 4.7 |
| analysisItemsTagExpenseAndIncomeSeparately | 3.8 |
| analysisItemsIncomeHonorsAnalysisExclusion | 3.8 |
| rollUpFoldsSubcategoriesIntoParent | 4.8 |
| rollUpBucketsTotalsPerChildAndDirect | 4.8 |
| rollUpUncategorizedFormsOwnBucket | 4.8 |

### 6.3 Dart-only additions

| Test | Task | Why |
|---|---|---|
| Half-open window boundary | 4.9 | The port's `[start, end)` rule deviates from Swift's closed interval |
| Archived account is skipped but still an endpoint | 2.4 | Pins the existence-set rule from the direction most likely to be broken |

## 7. Adversarial review findings

Filed at the Phase 2 boundary against a baseline of 432 passing tests and a clean analyzer. Three
angles reported: spec conformance, correctness and robustness, invariants and illegal states. The
mutation angle could not run alongside the others and is task 7.1.

Two angles disagreed on the id-canonicalization severity. The one that produced a triggering call
against a mutator-built ledger prevailed, since a silent misattribution of money outranks an
inconsistency; 7.8 carries the result.

Groups 1 to 6 are unaffected. Every finding below was verified by reading the cited line.

- [x] 7.1 Run the deferred mutation-testing angle, alone. It writes a defect into `accounting.dart`
      and runs the suite, so it cannot share the working tree with another agent reading those files.
      Backups from the aborted run are in the scratchpad. Report surviving mutants and add a test for
      each rule left unpinned. 79 mutants attempted, 62 died, 13 survived, 4 discarded as equivalent
      or non-compiling. The survivors are filed as 7.17 through 7.24
- [x] 7.2 `ledger_state_categories.dart:114` — `_validateParent` inspects only the incoming row's
      parent, never its descendants, so `updateCategory` may give a parent to a category that already
      has children and push those children to depth 3. `rollUp` then buckets their money under a
      category that is not top-level, and the one-level parent-exclusion gate in `resolveCategory`
      never sees the grandparent. Reject a non-null `parentID` when `_children(category.id)` is
      non-empty. `_children` already exists at line 108
- [x] 7.3 Test: a category with children cannot be given a parent, through `updateCategory`
- [x] 7.4 `ledger_state_categories.dart:114` — `_validateParent` does not reject
      `parentID == category.id`, so a category may be its own parent. No loop results and no money is
      lost, but the row becomes unusable as a parent and trips invariant clause 5 on every later
      mutation in debug. Throw on self-parenting
- [x] 7.5 Test: a category cannot be made its own parent
- [x] 7.6 `ledger_state_invariants.dart:110` — no clause compares an entry's `sourceID` to its
      `destinationID`, so a self-transfer built through the `LedgerState` constructor passes
      `assertInvariants`. It nets to zero in `balance`, but `classify` emits a full-amount phantom
      expense when the holder has `incomingTransfersAsExpenses`. The mutator path is already closed
      by `SelfTransfer` in `ledger_state_entries.dart`; only replay and seeding reach it. Add the
      clause

      EDIT 10 Aug: fixed a different way, and the clause was not added. The finding assumed a
      self-transfer is invalid. It is not. A PayNow to yourself deducts and credits the same account,
      so it is a real transaction a user needs to record, and the fix was to accept it rather than
      reject it harder. The `SelfTransfer` throw and error case were removed instead. Probing this
      also surfaced the larger defect behind the phantom expense, that `classify` never emitted the
      outgoing leg for any transfer, so a transfer out of a flagged source produced nothing. Each leg
      now reads the flag off its own end, which is why `classify` returns a list and why a
      self-transfer nets to zero without a `sourceID == destinationID` branch. Recorded in
      `design.md`
- [x] 7.7 Test: a self-transfer through the `LedgerState` constructor is rejected, and does not
      produce an analysis item

      EDIT 10 Aug: inverted along with 7.6. The committed tests pin that a self-transfer is accepted
      and stored, contributes zero to `balance`, and nets to zero in analysis through the symmetric
      legs rather than through a special case
- [x] 7.8 `accounting.dart:181` — `mainBucketID` does not canonicalize `leafID` before the lookup, so
      a non-canonical id returns null, the Uncategorized bucket, instead of the real main bucket. The
      wrong answer is silent and it misattributes money: through `rollUp`, an item carrying a
      non-canonical `bucketID` lands under `null` rather than its parent. `AnalysisItem` does not
      canonicalize `bucketID` either, so nothing upstream repairs it. Canonicalize the lookup and
      return `category.parentID ?? category.id` so the result is canonical too
- [x] 7.9 Apply the same rule to the other raw-id entry points, so the module is consistent:
      `balance`'s `of`, and the `buckets` sets on `filtered` and `total`, which currently match
      nothing rather than returning zero. Every public query in `ledger_state_queries.dart`
      canonicalizes its `raw…ID` parameter; `Accounting` is the outlier. Record the rule in
      `design.md` once it holds

      EDIT 10 Aug: `total` delegates to `filtered`, so the one canonicalization in `filtered` covers
      both. `sourceIDs`, `activePockets` and the `of` that `accountTotal` passes down are left alone
      deliberately, since they are built from already-canonical `moneySources.keys` and
      `activeSources` and re-canonicalizing them costs a pass per member on the net-worth path.
      Reasoning recorded in `design.md`
- [x] 7.10 Test: `mainBucketID` with a mixed-case leaf id against a mutator-built ledger returns the
      parent, and the matching `rollUp` case puts the money under the parent rather than `null`
- [x] 7.11 `accounting.dart:175` — `fraction` returns `Infinity` when the ratio exceeds `double`'s
      range, because `Rational.toDouble()` overflows rather than clamping. Entry amounts carry no
      magnitude bound, so an infinite slice can reach presentation code and produce a NaN layout. The
      `over <= 0` guard covers division by zero but not overflow. Guard the result as well.
      EDIT 10 Aug: the guard saturates to `±1.0` rather than `0.0`, since the value feeds a slice
      sweep and an overflowed ratio means the amount dwarfs the total, so a full slice is the
      truthful answer where zero would collapse the largest slice to invisible. The negative side is
      reachable and clamps to `-1.0`. NaN is not reachable, `over <= 0` already blocking `0/0`
- [x] 7.12 Test: a `fraction` whose ratio overflows `double` returns a finite value
- [x] 7.13 `accounting.dart:99` — `analysisItems`, `filtered` and `rollUp` each return a mutable
      collection, and the docstring invites callers to cache the result across a frame. None aliases
      `LedgerState`, so the ledger cannot be corrupted through them, but one consumer can mutate a
      result another is holding. Return unmodifiable views, or state the ownership transfer
- [x] 7.14 `date_range.dart:12` — `contains` compares instants without normalizing, so a range built
      from local bounds and a date stored as UTC fall in different windows. Half-open tiling itself is
      correct in either convention. This becomes live when Phase 4 stores dates as UTC and Phase 5
      builds month windows from local dates, so fix it with that ruling rather than guessing now.
      EDIT 11 Aug: ruling is UTC, so `date_range.dart` is unchanged and the fix normalizes at the
      `Entry` and `AnalysisItem` constructors instead, `contains` being correct once its inputs are
      days. Normalization is day-preserving `DateTime.utc(y, m, d)`, never instant-preserving
      `.toUtc()`, which would move an entry a month east of Greenwich. `startOfDayUtc` moved to
      `calendar_day.dart`. Convention recorded in `design.md`
- [x] 7.15 Test: a UTC instant against local-built bounds, pinning whichever convention 7.14 settles
- [x] 7.16 Consider `toString` on `NetWorth`, `AnalysisItem`, `DateRange` and `CategoryResolution`.
      They are the assertion targets of the 33 parity tests, and a failure currently prints
      `Instance of 'NetWorth'`

Tasks 7.17 through 7.24 come from the mutation angle. Each names a rule the suite does not pin, found
by writing that exact defect into the source and watching all 432 tests still pass. They are test
tasks, not source fixes, except where noted.

- [ ] 7.17 Test: `accounting.dart:100` — swapping `analysisItems`'s `ledger.moneySources.keys.toSet()`
      for `ledger.activeSources` survives the suite, so nothing pins the existence-set rule here.
      `netWorth` is pinned against the same swap. Archiving a source would silently erase its past
      expenses from Stats, shrinking historical months. Add an archived source keeping its analysis
      items, and an archived transfer destination keeping its treat-as-expense item, mirroring
      `accounting_net_worth_test.dart:68`
- [ ] 7.18 Test: `accounting.dart:125` and `:149` — replacing either `date: entry.date` with a
      constant survives, so the wire from `Entry.date` to `AnalysisItem.date` is untested. The window
      group at `accounting_analysis_test.dart:378` only exercises hand-built items. Assert a produced
      item's date, and that it totals inside its own month and to zero in the month before, on both
      the transfer arm and the income/expense arm
- [ ] 7.19 Test: `date_range.dart:12` — dropping the start bound survives, because every window test
      probes only the `end` boundary and interior points. Half of `[start, end)` is unpinned, and a
      dropped start turns every window into cumulative-to-date. Add a date strictly before `start`
- [ ] 7.20 Test: `net_worth.dart:14` — dropping either field from `==`, or reducing `hashCode` to
      `asset.hashCode`, survives. The existing pair at `accounting_net_worth_test.dart:134` differs in
      both fields at once, so it cannot catch a single dropped field. Add pairs differing in exactly
      one field, and a `hashCode` inequality
- [ ] 7.21 Test: `analysis_item.dart:25` — dropping `amount` or `date` from `==`, or dropping either
      from `hashCode`, survives. The `isNot` pairs at `accounting_analysis_test.dart:413` vary only
      `kind` and `bucketID`. Add pairs differing in exactly `amount`, and in exactly `date`
- [ ] 7.22 Test: `date_range.dart:15` — dropping `end` from `==` or reducing `hashCode` to
      `start.hashCode` survives. `DateRange` has hand-written equality with no assertion anywhere in
      the suite. The Phase 3 `AnalysisCache` is specified to key on the window, so two windows
      comparing equal would serve one month's numbers for another. Add a value-equality group
- [ ] 7.23 Test: `category_resolution.dart:15` and `:40` — widening `Excluded.operator ==` to
      `other is CategoryResolution` survives, because `accounting_analysis_test.dart:482` asserts only
      `Excluded() != Uncategorized()`, which evaluates `Uncategorized.==`. Add the reverse direction
      and an `InCategory` case. Separately, `InCategory.hashCode` reduced to `0` survives, so add a
      hash inequality across differing ids
- [ ] 7.24 Fix the test: `accounting_analysis_test.dart:489` asserts
      `InCategory(cat.toUpperCase()).id == cat`, but `uuid(n)` at `test/support/builders.dart:75`
      emits only digits and hyphens, so `toUpperCase()` is identity and the assertion is `x == x`.
      Deleting canonicalization from `InCategory`'s constructor entirely leaves the suite green. Use a
      literal containing hex letters, then sweep `id_normalization_test.dart` and
      `ledger_state_id_normalization_test.dart` for the same vacuity, which was not audited

### Rejected, and why

`rollUp` merging a genuinely uncategorized item with one whose category row is gone is the spec's
stated fallback, not a defect. Totals are preserved and only provenance is lost. Revisit only if a
screen must tell the two apart.

The pocket and holder states probed against `netWorth` and `accountTotal` are all blocked, either by
`IdCollision` and the link-ownership rules on the write path or by invariant clauses 2, 3 and 15.
`referenceOnly` holders continuing to count through `applies` is the recorded existence-set rule.

Three mutants survived because they are equivalent to the original, not because a rule is untested.
Do not file them as gaps. Dropping the `kind == null` early return at `accounting.dart:143`: the arm
is the non-transfer branch of a switch, and `expectedCategoryKind` is null only for transfers.
Returning `entry.categoryID` instead of `null` from the transfer arm at `:123`: a transfer carrying a
category is rejected at `ledger_state_entries.dart:79` and again by invariant clause 6. Folding the
null guard at `:179` into the map lookup: both paths return null.
