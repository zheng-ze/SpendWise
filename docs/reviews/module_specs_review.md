# Module Specs Review — adversarial pass before implementation

**Scope:** the five behavior specs in `docs/modules/`, verified line-by-line against the frozen
Swift app (`../SpendWise-SwiftUI/SpendWise/` + `SpendWiseTests/`) on 2026-08-08. Code wins over
every doc. The master plan (`docs/Flutter_Port_Tech_Doc.md`) and the completed gap review
(`docs/reviews/port_plan_gap_review.md`, findings C1/C2) were read as context; plan-vs-spec
mismatches are reported only where the specs must reconcile with a recorded decision (last
section) — never as spec errors when the spec is faithful to code.

Verification method: every Swift file the specs cite was read in full (all 14 Model files,
Services, Repository incl. Persistence + SwiftData, `SpendWiseApp.swift`, all 12 ViewModels,
every View except Previews, all 6 test suites). The OccurrenceID pin was **recomputed
independently** (SHA-1 UUIDv5 by hand and via a second implementation): seconds `794016000`,
id `cca271e1-a2dc-56cf-9462-a710c0c21922` — the spec's pinned triple is correct. Test counts
were re-tallied per suite: LedgerState 68, RecurringPlan 20, Accounting 16, AccountingAnalysis 17,
EventDriven 16, Persistence 22.

Severity: **BLOCKER** = wrong behavior if implemented as written / **MAJOR** = contradiction or
gap needing an edit / **MINOR** = polish.

---

## 1. `domain_models.md`

**DM-1 · MINOR — §1.4 "no opening balance of their own" re-opens gap-review C2.**
Evidence: spec §1.4 vs `Ledger+Sample.swift:92-93` (`setOpeningBalance(8000, for: emergency.id)`),
`LedgerState.swift:113-121` (guards holder existence only), `SourceEditViewModel.swift:80-90`
(pocket balance adjustment). The sentence is true of the *struct* (no stored field) but reads as a
domain rule; a defensive implementer could add an account-only guard to `setOpeningBalance`,
which would silently thin the seed and break pocket balance editing — exactly the C2 failure mode.
The spec's own §3.2 ("Throws `unknownHolder` if the **holder** is missing") and the runtime spec's
seed dataset (pocket opening balances 8000/650) are correct.
**Correction:** append to §1.4: "No opening-balance *field* — like accounts. `setOpeningBalance`
(§3.2) accepts **any** holder including pockets; the sample seed and the balance-edit flow depend
on it."

Everything else checked out against code, including the hard parts: the 12 `LedgerError` cases and
their trigger table (`LedgerState.swift:10-23` + every throw site), the full §3.3 validation order
including both prior-reference exemptions and transfer normalization (`LedgerState.swift:135-182`),
exact change-list contents and order for every mutator (verified against the 15 emission tests),
`updateAccount`'s two field overrides (`:55-66`), `addPocket` change order (`:68-79`), restore
blocking guards (`:380-405`), purge fork + atomic pocket detach (`:436-460`), the dereference
sweep (`:492-510`), all 11 invariant clauses (`LedgerState+Invariants.swift`), the queries table
(`LedgerState+Queries.swift`), enum raw values (`LifecycleState.swift:12-17`, `Account.swift:10-19`,
`TransactionCategory.swift:10-13`), and the §7 defect description — the Swift `purgeAccount` really
does purge the account **first** (`:411-420`), and the corrected order/reference-rule/cascade in §7
is internally consistent with the amended invariant 11. The §8 inventory maps 1:1 onto the actual
68 tests (recounted; category groups sum correctly).

**Verdict: READY** (apply DM-1 while touching the file).

---

## 2. `plans_and_accounting.md`

**PA-1 · MINOR — §5.3 pseudo-code derives `kind` from the already-absolute amount.**
Evidence: spec §5.3 last line — "`amount = abs(entry.amount), kind = expense if amount < 0 else
income`". Read in order, `amount` is now non-negative, so `kind` would always be `income`. Swift
uses `entry.expectedCategoryKind`, i.e. the **signed** stored amount decides
(`Accounting+Analysis.swift:69-77`, `Entry.swift:64-75`).
**Correction:** "`kind = entry.kind` mapped to `CategoryKind` (sign of the *stored, signed*
amount); `amount = abs(entry.amount)`."

Verified clean, including everything flagged for aggressive spot-checks: `occurrences` boundary
matrix (from exclusive / to inclusive / endDate inclusive / `ceiling >= anchor` guard,
`RecurringPlan.swift:101-116`), `nextOccurrence` on-or-after (`:82-92`), `isExhausted` strict/
inclusive pair (`:96-99`), the no-exemption plan validation order and what it deliberately does
NOT check (`LedgerState.swift:241-263`), `resolvePlans` dedupe-before-validate, report-once
failures, retirement-without-upsert, nothing-due-no-persist (`:270-304`), the deleteAccount-only
cascade + deliberate deletePocket/deleteCategory asymmetry (`:306-312, :318-335`), frequency raw
values and anchor-relative stepping (`RecurrenceFrequency.swift`), Foundation-clamp semantics and
the recovery-after-short-month property, the OccurrenceID algorithm byte-for-byte
(`OccurrenceID.swift:16-42` — namespace, uppercase `uuidString`, reference-date seconds, `|`
separator, v5 masking) **and the pin value recomputed independently** (794016000 →
`cca271e1-a2dc-56cf-9462-a710c0c21922`), `applies`/`balance`/`accountTotal`/`netWorth` including
the existence-set subtlety and sign-not-type liability split (`Accounting.swift`), the sealed
`CategoryResolution` mapping of Swift's `UUID??` (`Accounting+Analysis.swift:82-96`),
`filtered`/`total`/`fraction`/`mainBucketID`/`rollUp`, the §7 treat-as-expense freeze (matches
`bucketID: nil` at `:66` and the locked Phase-6 deferral), and all 53 inventoried tests against
the real suites (20 + 16 + 17, names and pinned values exact — e.g. Jan 31 → [Feb 28],
biweekly [Jan 15, Jan 29], endDate caps [Feb 1, Mar 1]).

Note: §5.5's end-inclusive interval rule is faithful to Foundation `DateInterval.contains` — but
see cross-cutting X-1 before implementing.

**Verdict: READY** (apply PA-1).

---

## 3. `ledger_runtime.md`

**LR-1 · MINOR — §7.1 header says "15 tests"; the suite (and the spec's own tables) have 16.**
Evidence: `grep -c "@Test" EventDrivenTests.swift` → 16; the §7.1 tables list 6 + 4 + 4 + 2 = 16.
**Correction:** change the count.

**LR-2 · MINOR — §5.3 misstates V1 cold-start behavior ("Same observable behavior as V1").**
Evidence: `SpendWiseApp.swift:34-44` — the `onChange(of: scenePhase)` handler guards
`case .ready`, and boot (`start()`, `:67-92`) is async. On a cold start the initial
`.active` transition typically fires while phase is still `.loading`, so V1 frequently does
**not** resolve plans at launch — they materialize on the next foregrounding. The spec's
resolve-once-on-entering-`ready` is the right design, but it is a (desirable) fix of a latent V1
race, not parity.
**Correction:** reword the note: "V1's initial `.active` races the async boot and is usually
swallowed by the `ready` guard; the explicit resolve on entering `ready` fixes that latent race —
a flagged deviation, strictly more reliable."

**LR-3 · MINOR — §6.2 `month(offset, day:)` helper is not what Swift does on edge days.**
Evidence: `Ledger+Sample.swift:106-109` uses `calendar.date(bySetting: .day, ...)`, which searches
**forward** for the next matching day and can leave the month: with today = Aug 30,
`month(-1, day: 25)` → shift to Jul 30 → bySetting 25 → **Aug 25**, not Jul 25. The spec's
"shift months, set day-of-month (clamped)" is deterministic and stays in the target month.
The spec's version is saner, but it silently deviates from V1 seed dates for runs late in the
month. **Correction:** keep the spec's semantics but add one line recording the deviation from
Foundation's forward-search quirk as deliberate.

**LR-4 · MINOR — seed failure-tolerance decision not carried into §6.**
Evidence: `Ledger+Sample.swift:82-100,174-176,200-201` builds through `try?` (a validation
tightening silently thins the seed — gap review D7); master plan §4.3 already decides "the Dart
seed builder throws/asserts in debug". §6 owns seeding but never says it.
**Correction:** one sentence in §6.1: the Dart seed builder asserts/throws in debug; a seed
regression must be loud.

**LR-5 · MINOR — which calendar does the Dart `resolvePlans` get?**
Evidence: §1.2/§1.4 pass `calendar` through without saying which one; Swift production defaults to
`Calendar.current` (`Ledger.swift:141`), but the port's recorded decision is UTC for all plan math
(`plans_and_accounting.md` §3.3, master plan §4.1). An implementer wiring `AppLifecycleListener` →
`ledger.resolvePlans()` could plausibly inject a device-local calendar and re-create the
timezone-dependent ids the decision kills.
**Correction:** state in §1.4 (and §5.3): the injected calendar is the fixed UTC calendar per the
plans spec §3.3, everywhere, including the boot-time and post-plan-creation calls.

Verified clean: the `mutate` pipeline order and failure semantics (`Ledger.swift:23-29` — throw
means no publish, pinned by `rejectedMutationPublishesNothing`), the full 24-method API surface
with throws/non-throws split (checked method-by-method against `Ledger.swift`; no invented
members), `categories(of:)` ordering incl. orphan-children drop and ordinal `<` sort (`:61-72`),
`resolvePlans` → `onPlanError` after-mutate ordering (`:141-151`), the EventBus guarantee set and
the Swift mechanism it restates (`EventBus.swift`), the documented Dart broadcast-stream semantic
shift plus the boot-order rule that neutralizes it, AnalysisCache initial values
(`revision 0` / `lastComputed -1` / first-refresh-computes), claim-before-compute and stale
discard (`AnalysisCache.swift:40-55`), `start` idempotence (`:24-34`), the isolate-copy-as-
snapshot argument for §3.4 (an acceptable instantiation of gap-review A12's "written argument"
branch; web sync path correct), PersistenceProcessor subscribe-before-await (`PersistenceProcessor.swift:19-27`),
the exact 9-step boot order (`SpendWiseApp.swift:67-92` — matches step for step, including
error-handler-before-seed), banner strings and precedence (`planError ?? saveState.message`,
`:55`, `:121-129`), distinct-plan-ID counting and the 4 s cancel-and-rearm dismissal (`:94-105`),
and the complete sample dataset — 3 accounts, 2 pockets, statementDay 15, all four opening
balances (incl. pockets — C2-consistent), 6 categories with exact hexes/symbols, all 15 entries
(every amount/name/category/source/dest re-checked against `Ledger+Sample.swift:111-172`), both
plans with `lastResolvedDate = anchor`, and the seeding contract (flag-not-emptiness,
flag-set-then-enqueue-then-flush, `SwiftDataLedgerStore.swift:261-267`).

**Verdict: READY-AFTER-EDITS** (five one-line edits, nothing structural).

---

## 4. `persistence.md`

**PS-1 · MINOR — §5 invents a change-stream flow that does not exist.**
Evidence: §5 "Domain-driven tombstoning … arrives as an **upsert carrying
`lifecycle = tombstoned`** in some flows and as a delete change in others." No domain path emits
such an upsert: `tombstoneHolder` emits `deleteMoneySource` (`LedgerState.swift:448-460`), the
category sweep emits `deleteCategory` (`:502-508`), and invariant 10 guarantees no stored
tombstoned value can ever ride an upsert payload. Handling it defensively in the store is fine;
asserting it happens is wrong and could send a Dart implementer hunting for a phantom emitter.
**Correction:** reword to "the change stream only ever expresses tombstoning via `delete*`
changes; the store's `update(from:)` writing the lifecycle column would also handle a hypothetical
tombstoned upsert identically, which is acceptable defense."

**PS-2 · MINOR — §1 "batch boundary is preserved into the pending buffer" is false in code and in
the spec's own §4.1.** Evidence: `SwiftDataLedgerStore.buffer` does `pending += changes`
(`:99-107`) — boundaries dissolve on concatenation; only the ingest queue holds batches, and §4.1
says so correctly ("concatenating batches in arrival order"). **Correction:** drop the clause or
say "batch boundaries exist only on the ingest queue; `pending` is a flat ordered concatenation."

Verified clean, aggressively: the `LedgerStore` contract table, `SaveBannerState` semantics with
both PORT FIXes correctly framed as sanctioned deviations (the clear-on-transition rule is the
master plan §4.3's own decision, correctly cited — not a silent improvement), the
`InMemoryLedgerStore` table member-by-member (`InMemoryLedgerStore.swift` — barrier `flushNow`,
no-op error handler, `applyForTesting`/`snapshot`), the schema against `SDModels.swift` column for
column (incl. the flattened `template_*` columns, no parent pointer on pockets, `store_meta`
without vector/lifecycle — the `CHECK (id = 0)` strengthening is explicitly flagged as such),
all mapping rules against `SDModels+Mapping.swift` (per-table update column sets exact; the
`parent_id`-immutable-on-upsert quirk real, `:101-108`; `SDPlan` lifecycle hardcoded active in
both init and update, `:181,196`; all four enum fallbacks `:49,54,114,119,161,210`), constants
250 ms / 2 retries / 200 ms (`SwiftDataLedgerStore.swift:30-32`), ordered ingest + last-index
coalescing preserving survivor order (`:146-153`), the flush cycle (fresh `taken` per attempt,
rollback, `0...maxRetries` = 3 attempts, batch never dropped, `:124-144`), serialization via the
single `flushTask` (`:111-120`), the §8.1 bug description (matches `flushNow` `:87-95` +
`flush()`'s early-return `:112-115` exactly), the §8.2 fix staying inside the sanctioned defect
list, delete-goes-to-account-table-first (`:190-195`), tombstone = lifecycle 3 + bump, `load()`
fetch-filter/order/replay (`:34-58`), replay's validation bypass with the pocket-link caveat
(`LedgerState+Replay.swift`), `VersionVector` bump/dominates/isConcurrent (`VersionVector.swift` —
the dominates quantifier is exactly "every device in *other*"), the Swift alternating-array wire
format (real Codable behavior for UUID-keyed dicts) with encode-or-empty/decode-or-empty
(`SDModels+Mapping.swift:10-18`), seeding atomicity reasoning (flag mutation rides the flush's
`modelContext.save()`), `seedChanges` order and `isEmpty` (`LedgerState+SeedChanges.swift`), and
the full 22-test inventory (4 + 3 + 8 + 7, names and pinned details — 50 conflicting upserts →
v50, raw-SQL tombstone check with vector counter-sum ≥ 1 — all match `PersistenceTests.swift`).

But see X-2/X-3: two master-plan schema/codec decisions are silently contradicted or omitted.

**Verdict: READY-AFTER-EDITS** (PS-1/PS-2 plus the X-2/X-3 reconciliation).

---

## 5. `ui_screens.md`

**UI-1 · MAJOR — §5.6 claims restoring a pocket restores its binned parent. It does not.**
Evidence: spec §5.6 "restoring a pocket whose parent is binned restores the parent too — the UI
just calls restore". The UI does just call restore (`RecycleBinViewModel.swift:82`), but the
domain `restorePocket` is a **silent no-op while the parent is archived**
(`LedgerState.swift:380-387`), and nothing anywhere restores the parent. The spec's own sibling
(`domain_models.md` §3.7, "restore the account first") and the test
`restorePocketBlockedWhileParentArchived` say the opposite of this sentence. Since archiving an
account archives its pockets, the bin really does show pocket rows whose swipe-restore does
nothing. An implementer following §5.6 would build an unsanctioned parent-restore cascade; one
following the domain spec would ship a UI whose documented UX is wrong.
**Correction:** "Restore on a pocket whose parent account is still binned is a **silent no-op**
(domain rule §3.7 — restore the account first). Port that faithfully; if the dead swipe is judged
worth fixing, that is a flagged Phase-6 UX change (disable the action or restore-parent-with-
confirmation), not a port default."

**UI-2 · MAJOR — §3.4 subcategory-table row order is wrong.**
Evidence: spec — "first **All \<Main\>** row …; then child slices sorted desc; **then** a
**Direct** row … only when main − Σchildren > 0". Code: the "All" row is view-side and first
(`CategoryDetailView.swift:139-166`) ✓, but `subSlices` appends Direct to the children and then
sorts the **combined** list by amount descending (`CategoryDetailViewModel.swift:59-78`) — Direct
lands wherever its amount ranks, not last. A spec-faithful Dart implementation would reorder a
shipped screen.
**Correction:** "child slices **and the Direct slice sorted together** by amount descending
(Direct appears wherever its amount ranks); Direct exists only when main − Σchildren > 0."

**UI-3 · MINOR — "the entry's note" implies a field `Entry.note` that does not exist.**
Evidence: §2.2 delete-dialog copy and §2.3's "title / optional note". `Entry` has no note field
(`Entry.swift:10-48`; its absence is gap-review B3). The row's `note` **is** `entry.name`, and
the row's `title` is the category name (`TransactionRow.swift:41,59`); the dialog message is
`row.note.isEmpty ? row.title : row.note` (`TransactionsTableView.swift:80-89`).
**Correction:** one sentence in §2.3: "`TransactionRow.note` = `Entry.name` (the free-text the
user typed); `title` is derived from the category. There is no `Entry.note` field in V1."

**UI-4 · MINOR — §5.4 "ties by name" overstates the plan-list sort.**
Evidence: `PlanSettingsViewModel.swift:42-49` — the name tiebreak exists **only** in the
`(nil, nil)` branch (two ended plans). Two live plans with the same next-occurrence date get
comparator `false` both ways: order unspecified in V1.
**Correction:** "ended plans tie-break by name; equal non-nil next dates are unspecified in V1 —
pick and document a deterministic tiebreak (name) as a flagged strengthening."

**UI-5 · MINOR — §5.6 omits bin-row ordering.** Evidence: all three sections sort by name
ascending (`RecycleBinViewModel.swift:44,58,74`). Spec is silent; Dart map iteration would
produce arbitrary order. **Correction:** add "rows in each section sorted by name ascending".

**UI-6 · MINOR — §2.8 misses the future-year edge.** Evidence:
`TransactionsViewModel.monthSummaries` (`:58-75`) computes
`upperBound = min(yearEnd, currentMonthEnd)`; selecting a **future** year yields an **empty**
month list (upperBound precedes yearStart). Spec covers past ("all 12") and current ("up to
current month") but not future. **Correction:** add "a future year renders zero month rows" so
the pure function pins all three cases.

Verified clean — and this spec covered an enormous surface accurately: shell/tab order + icons +
per-tab stacks (`RootView.swift`), boot chrome and both banners (`SpendWiseApp.swift:47-129` —
strings exact), `daySections` scope-then-resolve-then-interval order, desc/desc sorting, and the
include-gated section aggregates (`TransactionRow.swift:80-125`), row resolution incl.
"Parent/Child", "Unknown", `questionmark.circle`, transfer chrome (`:38-77`), the income/expense
bar and `.black` hazard (`TransactionsView.swift:86-100`), swipe-delete dialog title/copy,
empty-state ("tray" + "No transactions"), the full entry form (mode/title/leading/trailing
matrix, kind-clears-category, end-date `>= date` constraint, canSave predicate, sign matrix,
edit-stays-open-flips-read-only, plan creation `anchor = date` + cursor `date − 1 s` +
immediate `resolvePlans`, prefill, unconfirmed in-form delete — all at
`EntryFormView.swift`/`EntryFormViewModel.swift:152-193`), both picker sheets and the
TwoColumnPickerSheet interaction rules incl. second-tap-selects-parent and None-only-when-allowed
(`TwoColumnPickerSheet.swift:82-107`), RecurrencePicker rows, ExpandingFAB single-vs-multi
behavior with the (correctly described) invisible backdrop (`ExpandingFAB.swift`), month
breakdown rendering incl. spillover weeks at full range, one-month-expansion, week-tap
month-level jump, and the end-exclusive range text (`MonthBreakdownView.swift:106-111`,
`TransactionsViewModel.swift:94-122`), Stats totals/donut geometry (60 % ring, 0.58 inner, 12
o'clock clockwise, 1.5° gap, negative clamp, 14 pt elbow + 12 pt run leader lines, on-canvas
clamping — `DonutChart.swift`), legend behavior incl. non-navigable Uncategorized, the
iOS-only-toolbar gap called out correctly (`StatsView.swift:54-84`), detail-screen scope math,
trend windows (6-month asc / 12-month year), `matchingCategoryIDs`, `itemsRevision`-keyed
memoization (`CategoryDetailViewModel.swift:112-124,158-195`), accounts sections/order/skip-empty,
payable clamp, outstanding filter set, the statement-cut anchor rule and the sanctioned clamp fix
(`AccountsViewModel.swift:122-143`), rows/expansion/scoped navigation/never-shown entry count
(`AccountsView.swift`), both account-side forms incl. the balance-adjustment delta contract
(`SourceEditViewModel.swift:80-90`, exact footer string), category list/form/kind-lock/symbol
picker (9 × 10 catalog verified = 90 symbols, `CategorySymbols.swift`), plan list/form incl.
sign preservation and the ignored "One time" binding (`PlanFormView.swift:71-97`), recycle-bin
sections/copy incl. the accurate "good.Existing" interpolation-bug description
(`RecycleBinView.swift:42-49` — the `\` continuation really swallows the separator), the
formatting rules (`AmountFormat` sanitize/plain, `Color.netAmount`, hex parse/emit with gray
fallback and uppercase clamped write-back — `AmountField.swift`, `PlatformColor.swift`), and the
§0.3 chrome-symbol list (every listed name found in the views).

**Verdict: READY-AFTER-EDITS** (UI-1 and UI-2 are the two that matter; the rest are one-liners).

---

## Cross-cutting

### Contradictions between specs

The only true inter-spec contradiction found is **UI-1** (ui_screens §5.6 vs domain_models §3.7 on
pocket restore), reported above. Everything else lines up: id casing (lowercase everywhere,
uppercase only inside the OccurrenceID name string), lifecycle/AccountType/CategoryKind/frequency
codes identical across domain_models §1 and persistence §2, change-list orders quoted identically
by domain_models §3 and the runtime test tables, the boot order in ledger_runtime §5.2 vs
ui_screens §1.1, the seeding contract and the full sample dataset (ledger_runtime §6 is the owner;
ui_screens defers), banner strings byte-identical in ledger_runtime §5.4 / persistence §1 /
ui_screens §1.1, `categories(of:)` ordering consumed consistently by ui_screens §2.6/§5.1, the
entry-form sign matrix vs the domain's transfer normalization, and the occurrence-id UTC decision
(plans spec §3.3 = master plan §4.1; pin value independently recomputed — gap-review **C1 is
resolved consistently**; **C2** is consistent everywhere except the DM-1 phrasing).

### X — Decision-sync with the master plan (not spec-vs-code errors; both docs must end up agreeing)

The plan is being revised in parallel; these are places where a spec silently contradicts or drops
a decision the plan already records. Each needs one ruling written in **both** places, because an
implementer reading only the module spec will build the opposite of the plan.

**X-1 · MAJOR — window-boundary semantics.** Master plan §5 hazard 8 pins **half-open
`[start, end)` for ALL window filters** (the `<=`-boundary blind spot). `plans_and_accounting.md`
§5.5 pins the opposite: Foundation-faithful **end-inclusive** `DateInterval.contains`
(`Accounting+Analysis.swift:26`), and ui_screens' `daySections`/week totals inherit the same
inclusive `range.contains` without stating it (`TransactionRow.swift:108-110`). Both cannot hold;
worse, a mixed implementation (analysis half-open, day-sections inclusive) would widen the
Transactions-vs-Stats divergence the plan is trying to contain. Decide once — half-open (plan) with
a flagged faithful-port deviation note, or inclusive (Swift parity) and rewrite hazard 8 — and
state it in plans_and_accounting §5.5, ui_screens §2.2, and the plan.

**X-2 · MAJOR — version-vector decode failure.** Master plan §4.3: decode failure "is an
**error**, not an empty vector" (gap-review A13 — the empty-vector fallback silently resets causal
history). `persistence.md` §6: "Decode (**never throws**) … → empty vector" (faithful to
`SDModels+Mapping.swift:15-17`). Direct contradiction on a recorded decision. Pick one; if the
tolerant decode stays, the plan's sentence must be rewritten and the future-sync hazard
re-accepted explicitly.

**X-3 · MAJOR — day-one schema reservations dropped.** Master plan §4.3: "**Reserve two columns
at schema day one**: `entries.note TEXT` (locked V2 split-wizard prerequisite, gap-review B3) and
the system-entry marker" (for the persisted "Opening balance"/"Balance adjustment" strings, plan
§1 defect 9). `persistence.md` §2's `entries` table has neither, and nothing marks the two
synthetic entry names structurally. Either the schema section adds the reserved columns (free
now, a migration later) or the plan records the deferral. The spec, as the schema's
source of truth for Phase 4, currently guarantees the migration cost.

**X-4 · MINOR — seed loudness** (same as LR-4): plan §4.3 decides debug-assert seeding;
ledger_runtime §6 omits it. Covered by the LR-4 edit.

---

## Checked, no finding (summary)

OccurrenceID pin recomputed and confirmed; all six test-suite counts and inventories match
(68/20/16/17/16/22 — ledger_runtime's "15" is LR-1); validation and error-precedence orders exact;
change-emission orders exact; boot order exact; sample dataset exact (all 15 entries, 6
categories, 4 opening balances incl. pockets, both plan cursors); banner strings, dialog copy,
empty-state strings, and the recycle-bin interpolation bug all byte-accurate; debounce/retry/
backoff constants, coalescing, barrier, seeding atomicity, mapping column sets, enum fallbacks,
and both sanctioned store fixes correctly framed; the five sanctioned defect fixes (orphan-pocket
purge, statement-day clamp, flushNow loop, timed failedWillRetry retry, view-logic extraction)
are each present, flagged, and none of the specs smuggles in an additional silent behavior change
beyond the items reported above; no Swift source behavior was found that no spec covers
(file-by-file sweep of Model/, Services/, Repository/, ViewModel/, View/ minus Previews, and the
empty UI-test template).

## Verdicts

| Spec | Verdict | Gating items |
|---|---|---|
| `domain_models.md` | **ready** | DM-1 (one-line clarification) |
| `plans_and_accounting.md` | **ready** | PA-1 (one-line fix) + X-1 ruling before coding §5.5 |
| `ledger_runtime.md` | **ready-after-edits** | LR-1…LR-5 (all one-liners) |
| `persistence.md` | **ready-after-edits** | PS-1, PS-2 + X-2/X-3 rulings before Phase 4 schema |
| `ui_screens.md` | **ready-after-edits** | UI-1, UI-2 (behavioral), UI-3…UI-6 (one-liners) |

No BLOCKERs: nothing in the specs corrupts data or breaks the domain if built as written. The two
MAJOR spec errors (UI-1, UI-2) would ship visible behavior diverging from V1, and the three MAJOR
decision-sync items (X-1–X-3) must be ruled on before Phases 2 and 4 respectively.
