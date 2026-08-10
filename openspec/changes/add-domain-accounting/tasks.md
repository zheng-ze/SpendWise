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

- [ ] 3.1 Add `lib/src/analysis_item.dart`: `AnalysisItem` with `String? bucketID`, `Decimal amount`,
      `DateTime date`, `CategoryKind kind`, value equality
- [ ] 3.2 Add `lib/src/category_resolution.dart`: sealed `CategoryResolution` with `Excluded`,
      `Uncategorized`, `InCategory(String id)`
- [ ] 3.3 Add `resolveCategory(entry, ledger)` in resolution order: null category → `Uncategorized`;
      id absent from `ledger.categories` → `Uncategorized`; `includeInAnalysis == false` → `Excluded`;
      parent present and excluded → `Excluded`; otherwise `InCategory`
- [ ] 3.4 Add `classify(entry, sourceIDs, ledger)`: gate on `applies` and `entry.includeInAnalysis`,
      then switch on entry kind. Transfer → item only when the destination holder exists and has
      `incomingTransfersAsExpenses`, carrying the stored amount, null bucket, expense kind.
      Income/expense → resolve the category, then take `kind` from the signed amount BEFORE storing
      `abs(amount)`
- [ ] 3.5 Add `analysisItems(ledger)`: one pass over `entries.values` with `sourceIDs` = all
      `moneySources` keys, dropping nulls. Output order unspecified — tests sort or use set semantics
- [ ] 3.6 Test the gates: `normalExpenseProducesItemWithAbsoluteAmount`, `incomeProducesNoExpenseItem`,
      `plainTransferProducesNoExpenseItem`, `transferIntoTreatAsExpenseHolderProducesItem`,
      `excludedFromAnalysisEntryProducesNoItem`
- [ ] 3.7 Test category resolution: `categoryExcludedFromAnalysisHidesItsExpenses`,
      `parentExcludedFromAnalysisHidesChildExpenses`, `uncategorizedExpenseIsIncluded`,
      `archivedCategoryStillBucketsUnderItsID`, `unresolvableCategoryRendersAsUncategorized`
- [ ] 3.8 Test kind tagging: `analysisItemsTagExpenseAndIncomeSeparately`,
      `analysisItemsIncomeHonorsAnalysisExclusion`
- [ ] 3.9 Mutation-test the ordering constraint in 3.4: take `abs` before deciding `kind`. If no test
      dies, the income/expense split is untested — add the test before proceeding

## 4. Filtering, totals, roll-up

- [ ] 4.1 Add `filtered({kind, buckets, interval})` as an extension on `List<AnalysisItem>`, each null
      parameter meaning no constraint, `buckets` typed `Set<String?>` so null is selectable
- [ ] 4.2 Interval filtering is half-open `[start, end)` — `start <= date < end`. This is a sanctioned
      deviation from Swift's closed `DateInterval.contains`; see `design.md`
- [ ] 4.3 Add `total({kind, buckets, interval})` summing `filtered` from `Decimal.zero`
- [ ] 4.4 Add `fraction(Decimal amount, Decimal over) -> double`: `over <= 0` returns `0.0`. The only
      sanctioned `double` in the domain — it is a presentation ratio, not money (`design.md`)
- [ ] 4.5 Add `mainBucketID(String? leafID, LedgerState)`: null or absent leaf → null, else
      `parentID ?? leafID`
- [ ] 4.6 Add `rollUp(items, state) -> Map<String?, Decimal>` grouping amounts by `mainBucketID`
- [ ] 4.7 Test income totals: `incomeSumsPositiveNonTransferEntries`,
      `incomeIgnoresTransfersAndExcludedEntries`
- [ ] 4.8 Test roll-up: `rollUpFoldsSubcategoriesIntoParent`, `rollUpBucketsTotalsPerChildAndDirect`,
      `rollUpUncategorizedFormsOwnBucket`
- [ ] 4.9 Test the half-open boundary (Dart-only, required by 4.2): an item timestamped exactly on the
      instant shared by two adjacent month windows appears in the later window only

## 5. Barrel and close-out

- [ ] 5.1 Export `accounting.dart`, `net_worth.dart`, `analysis_item.dart`, `category_resolution.dart`
      from `lib/domain.dart`; extend `test/barrel_exports_test.dart`
- [ ] 5.2 Run `cd packages/domain && dart analyze && dart test` and `cd app && flutter analyze`.
      Analyzer at zero issues, not just zero errors
- [ ] 5.3 Confirm no `double` reached `packages/domain/lib/` except `fraction`'s return:
      `grep -rn "double" packages/domain/lib/`
- [ ] 5.4 Confirm the coverage map below is complete — every one of the 33 Swift scenarios maps to a
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
