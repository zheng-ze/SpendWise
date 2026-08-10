# Port Plan Gap Review — old SwiftUI app + docs vs `Flutter_Port_Tech_Doc.md`

**Scope:** adversarial pass over the frozen SwiftUI repo (`../SpendWise-SwiftUI`) and the old
design/critique docs (`../job-applications/outputs/apple-eee-ios/`), checked against the master
port plan (`docs/Flutter_Port_Tech_Doc.md`, read in full). Module behavior specs in
`docs/modules/` were deliberately NOT reviewed (separate pass). Every claim below was verified
against the actual file cited, on 2026-08-08. Where docs and code disagree, code wins; stale doc
claims are marked as such.

Verdict up front: the plan's "Known defects" list (§1) is accurate and covers the big critique-v2
items well. What it inherits from the same blind spots: **two of its own sections contradict each
other on occurrence-id timezone handling**, it repeats one **false domain claim about pocket
opening balances**, it **drops most of the locked treat-as-expense sub-decisions**, and it is
**silent on currency, search, scope-aware transfer sign, `Entry.note`, and the passive
failed-save retry**.

---

## 1. Gap inventory with coverage verdicts

Legend: **COVERED** (plan handles it, section cited) / **PARTIAL** (handled but with a hole) /
**MISSED** (not in the plan at all).

### A. Defects in the shipped code

| # | Gap | Evidence | Why it matters for the port | Verdict |
|---|---|---|---|---|
| A1 | Account-tombstone orphan bug: purging an account whose money lives only in its pockets tombstones the parent while pockets stay `referenceOnly`; invariant #3 crash in debug | `LedgerState.swift:436-459` (`purgeHolder`/`tombstoneHolder`), `LedgerState.swift:486-488` (`entriesReferencing` counts direct refs only); Critique v2 Con 1 | Only known data-integrity defect; must not be translated verbatim | **COVERED** — plan §1 defect 1, Phase 1 regression test |
| A2 | Transactions vs Stats totals diverge: `TransactionDaySection.income/expenses` applies only entry-level `includeInAnalysis`; Stats adds category gates + treat-as-expense transfers | `TransactionRow.swift:83-93` vs `Accounting+Analysis.swift:50-96`; Critique v2 Con 2 | Same numbers on two tabs disagree; decision needed before building the Flutter list | **COVERED** — plan §1 defect 2, Phase 6 |
| A3 | `statementCut` day-overflow: naive `comps.day = day` date build | `AccountsViewModel.swift:135-143` | Dart date math overflows harder | **COVERED** — plan §1 defect 3, §5.1. **Nuance the plan misses:** the Swift UI already limits the picker to 1–28 (`SourceEditView.swift:56`, `AccountFormView.swift:53`), but the **domain never validates the range** (`Account.swift:30-31` is doc-comment only, `LedgerState.updateAccount:55-66` passes it through). The Dart domain should validate/clamp `statementDay` itself, not just the cut math, since drift rows and the future Realbyte import bypass the picker |
| A4 | View-layer types own view-model logic: `TransactionRow.daySections` + `MonthYearSelectorMode.interval` live in `View/`, called by three VMs | `TransactionRow.swift:96-140`, `DateSelector.swift:10-21`; Critique v2 Con 3 | Untestable aggregation seam | **COVERED** — plan §1 defect 4, §4.4 |
| A5 | Zero view-model tests; the layer with `statementCut`, day sections, month summaries, trend windows has no coverage | `SpendWiseTests/` has no VM suite; Critique v2 Con 9 | Port re-litigates these bugs blind | **COVERED** — plan §1 defect 5, Phase 5. Small addition: `AccountsViewModel.outstanding`/`statementCut` read `Date()` directly (`AccountsViewModel.swift:124,137`); the Dart controllers need an injected clock or the promised tests can't pin the statement window |
| A6 | Accessibility + localization never happened (two `accessibilityHidden(true)` total; hardcoded English everywhere) | Critique v2 Con 10; e.g. `SpendWiseApp.swift:96-98,125-128,137-143` | Spec commitments with zero movement across two reviews | **PARTIAL** — Phase 6 budgets "localization scaffolding (intl) + semantics/a11y pass", but see A7: some strings are *data*, not UI |
| A7 | English strings persisted as data: `"Opening balance"` and `"Balance adjustment"` are stored entry **names**, written into the ledger forever | `LedgerState.swift:125` (`name: "Opening balance"`), `SourceEditViewModel.swift:85` (`name: "Balance adjustment"`) | An `intl` pass cannot retro-localize rows already on disk; also nothing structural marks these entries beyond `includeInAnalysis: false` | **MISSED** — plan treats l10n as a UI pass. Decide in the Dart domain: a structural marker (entry subtype/flag) with display-time naming, not a persisted English literal |
| A8 | `flushNow` hole: racing a debounced flush can return before its own batch is on disk | Critique v2 Con 6; `SwiftDataLedgerStore.swift:111-120` | Backgrounding is exactly when it matters | **COVERED** — plan §4.3 "flushNow loops until pending is empty" |
| A9 | `failedWillRetry` is passive: after the final retry fails the batch stays pending but **nothing schedules another attempt**; banner says "will retry shortly" and lies | `SwiftDataLedgerStore.swift:124-144` (returns after `report(.failedWillRetry)`, no timer), `SpendWiseApp.swift:127` (banner text); Critique v2 Con 7 | Plan §4.3 replicates the same design (2 retries, then `failedWillRetry`) without fixing the passivity | **MISSED** — add a timed re-flush (or flush on next lifecycle event) or soften the banner text; either way, decide it in §4.3 |
| A10 | Per-render full scans outside analysis (`monthSummaries` ~17 ledger passes per render, `AccountsViewModel.sections`) | Critique v2 Con 8; `TransactionsViewModel.swift:58-122` | Perf at personal scale is fine | **COVERED** — roadmap #6 explicitly defers memoization |
| A11 | View-model lifetime fragility: `RootView` builds all four VMs inline in `body`, no `@State` ownership; re-evaluation would silently reset tab state (selected month, mode, kind) | `RootView.swift:14-33`; Critique v2 Con 4 | Riverpod fixes this structurally, but only if per-screen UI state (selected month/mode/kind) lives in providers, which the plan never says | **PARTIAL** — §3 picks Riverpod; add one sentence to §4.4: screen state such as selected month/mode/kind lives in providers, never in widget-local state that a rebuild can recreate |
| A12 | `AnalysisCache` snapshot semantics: the Swift off-main recompute is only safe because `LedgerState` is a **value struct** (a free immutable snapshot crosses into `Task.detached`; Critique v2 Pros noted this explicitly). Plan §3 changes `LedgerState` to a mutable class mutated in place ("value semantics were an implementation detail") — for `AnalysisCache` they were load-bearing | `AnalysisCache.swift:40-55` (captures the struct copy), plan §3 state-shape decision, §4.2 | `Isolate.run` deep-copies captured objects (hidden per-recompute cost, and the copy moment vs mutation timing needs a rule); web fallback reads the live object | **MISSED** — §3 must state the snapshot rule: either an explicit cheap clone/immutable snapshot handed to the isolate, or a written argument why the implicit isolate copy is safe and affordable. Do not leave it implicit |
| A13 | Silent decode fallbacks in persistence mapping: unknown `AccountType` → `.other`, `kind` → `.expense`, `lifecycle` → `.active`, `frequency` → `.monthly`; corrupt `versionData` decodes to an **empty VersionVector** (`(try? decode) ?? VersionVector()`) | `SDModels+Mapping.swift:49,54,81,114,119,161,210`, `SDModels+Mapping.swift:12-16` | The empty-vector fallback silently resets a row's causal history, which is a real hazard once the sync engine exists; the enum fallbacks matter for the drift mappers too | **MISSED** — §4.3 drift section should state the fallback policy per column and treat version-vector decode failure as an error, not an empty vector |
| A14 | UI test target is an untouched Xcode template (`testExample` empty) | `SpendWiseUITests/SpendWiseUITests.swift` | The "159 tests" story includes zero end-to-end coverage | **PARTIAL** — Phase 5 golden/provider tests; Phase 7 smoke checklist is manual. Cheap add: one `integration_test` boot-and-tap smoke per platform in Phase 7 |

### B. Promised-but-unbuilt features (from README / spec / V2 docs)

| # | Gap | Evidence | Verdict |
|---|---|---|---|
| B1 | Budgets (rollover derived by walking windows, `RolloverMode { none, unspentOnly, signed }`, category-SET keying, `deleteCategory` prunes budget sets) | README Roadmap; V2 Tech Doc locked decisions 4–5; V2 Handover Track 2 | **COVERED** — roadmap #1 matches the locked decisions (derived carry, RolloverMode). Set-keying and the delete-cascade are module-spec granularity, fine to omit here |
| B2 | Amortise + split-payment wizards (both on `RecurringPlan`; amortise = recognition-only via treat-as-expense pocket + hidden yearly cash-out; split = real deduction, flat + reducing-balance interest) | README Roadmap; V2 Tech Doc locked decision 1a/1b | **COVERED** — roadmap #2 matches. But see B3 |
| B3 | **`Entry.note` field** — V2 locked prerequisite: the split wizard writes the principal/interest breakdown into `Entry.note` (distinct from `Entry.name`); confirmed absent from `Entry.swift` | V2 Handover Track 2 "REMAINING": "`Entry.note` field (V2 doc §1/§7) ... Used by the split-payment wizard"; `Entry.swift:10-48` has no note | **MISSED** — the plan ports `Entry` 1:1 and never mentions `note`. Adding the column at drift-schema day one (§4.3) is free; adding it in Phase 6+ is a migration. Decide now: reserve the column or record the deferral |
| B4 | Treat-as-expense bucketing sub-decisions (locked, revised 11 Jul): bucket by destination account **type** via a **deterministic synthetic UUID per type**; `AccountType` gains **`loan` + `overdraft`** (appended so rawValues stay stable); **eligibility gate** `allowsTransfersAsExpense` (blocked for cash/checking/card/prepaid, forced false on save); a pocket destination resolves to its **parent account's type**; expense-only (no reverse/income rule); slices render self-carried name/symbol (no `TransactionCategory` behind them), grey, non-navigable | V2 Handover Phase 5 (full build spec); V2 Tech Doc "Revised 11 Jul" note; current code drops these transfers into `bucketID: nil` (`Accounting+Analysis.swift:57-66`) | **PARTIAL** — plan §1 defect 7 + Phase 6 say only "bucket by destination account type". The eligibility restriction, the two new account types, synthetic ids, and pocket→parent resolution are all part of the same locked decision and are nowhere in the plan. Phase 6 should cite V2 Handover Phase 5 as its spec, and §4.3 should note the enum-encoding stability rule (`loan`/`overdraft` appended) |
| B5 | **Scope-aware transfer sign/color** (designed, unbuilt): on an account page, a transfer out of scope renders red/−, into scope blue/+, both-in-scope or global neutral; pocket scope = account + its active pockets | V2 Handover Phase 6 second half (`transferDirection`, `scopedHolderIDs`); current code always renders transfers neutral/unsigned (`TransactionCell.swift:22-30`) | **MISSED** — plan's Phase 6 takes only the totals-unification half of the old Phase 6. The transfer-direction half is dropped without a word. Add to Phase 6 or explicitly cut it |
| B6 | **Search/filter** — spec lists it as in-scope Realbyte parity ("recurring entries ..., budgets per category, search/filter"); never built (the only `.searchable` in the app is the SF-symbol picker) | `SwiftUI_Project_Spec.md:142`; `CategoryFormView.swift:220` | **MISSED** — not in plan §4.4 nor roadmap §7. Add to roadmap (or record the cut) |
| B7 | Export/backup — spec Session 9 says "Realbyte data import/export"; app is offline-first with no backup path at all | `SwiftUI_Project_Spec.md:346`; README "Offline-first" | **PARTIAL** — roadmap #5 covers **import** only. An offline-first app across six platforms needs an export/backup story (even file-level); one line in roadmap #5 |
| B8 | Receipt scan (on-device OCR → corrections lookup → classifier) | README Roadmap | **COVERED** — roadmap #4, faithful translation to ML Kit |
| B9 | Sync engine (version vectors + deterministic ids; merge + transport unbuilt) | README Roadmap; `SwiftUI_Project_Spec.md:389` | **COVERED** — roadmap #3, offline-first constraint kept |
| B10 | Adaptive layout (NavigationSplitView promised; V1 ships phone shell everywhere, macOS runs stopgaps: fixed `minHeight` forms pending a master/detail redesign) | README "Mac and iPad"; repo CLAUDE.md macOS-gotchas paragraph | **COVERED** — §4.4 rail/bar shell "leapfrogs" it; the macOS form stopgap dies with the platform-conditional code. Fine |
| B11 | Widgets/quick-add, plan-due notifications | README-adjacent, old roadmap | **COVERED** — roadmap #6 |

### C. Plan self-contradictions and factual errors (verified against code)

| # | Gap | Evidence | Verdict |
|---|---|---|---|
| C1 | **Occurrence-id timezone contradiction.** §4.1 mandates byte-for-byte Swift compat: name = `"<planID-uppercase>\|<seconds-since-2001-01-01-of-start-of-day>"` pinned by a triple from the Swift app. But Swift's `calendar.startOfDay` is **local-timezone** (`OccurrenceID.swift:19-22`, `Calendar.current` at every call site), so the seconds value depends on the device timezone. §5.3 mandates the opposite: "Use UTC dates ... so a timezone move cannot change generated ids." Both cannot hold: UTC normalization produces different ids from the native app for any non-UTC device | Plan §4.1 vs §5.3; `OccurrenceID.swift:19-22`; `Ledger.resolvePlans` default `calendar: .current` (`Ledger.swift:141`) | **MISSED (internal conflict)** — reconcile in one place: either (a) UTC/date-only normalization, accepting that native-app data migration re-derives ids (write the migration note), or (b) replicate local-tz `startOfDay`, accepting the timezone-move duplication risk the plan itself warns about. The pin test is only meaningful after this decision, and must state the timezone it was generated in |
| C2 | **"Pockets have no opening balance" (§1) is false at the domain level.** `setOpeningBalance` accepts any holder (`LedgerState.swift:113-130`, guards existence only); the sample data seeds pocket opening balances (`Ledger+Sample.swift:92-93`: `setOpeningBalance(8000, for: emergency.id)`); the balance-edit flow posts "Balance adjustment" entries for pockets too (`SourceEditView.swift:64-66`, `SourceEditViewModel.swift:80-90`). Only the account-creation **form** restricts opening balance to accounts | Plan §1 bullet 2 | **MISSED (plan error)** — if a Dart validator enforces the plan's sentence, the ported sample seed silently thins (it is built with `try?`-equivalent tolerance today, `Ledger+Sample.swift:82-100`) and pocket balance-editing breaks. Correct §1 to "pocket opening balance is a form-level restriction, not a domain rule" |
| C3 | ~~Test count is wrong~~ **RETRACTED (reviewer arithmetic error):** the per-file counts in this very row (68+22+20+17+16+16) sum to 159, and an independent recount confirms 159 `@Test` functions. The plan's figure was correct; the "119" headline was the review's own mistake. Plan wording updated to "frozen suite (159 `@Test` functions)" anyway | `grep -c "@Test" SpendWiseTests/*.swift` re-run 2026-08-08: 68/22/20/17/16/16, total 159 | **NO FINDING** |
| C4 | Stale-doc hazard in the roadmap: §7 says V2 Tech Doc decisions are "locked unless revisited", but that doc's "shipped surface" section references machinery that **no longer exists** (`Period`, `CalendarConfig`, `periodWindow`, `expenseItems`, `flowItems`; "deleteCategory re-homes entries to nil" — superseded by the lifecycle system). An implementer following it verbatim will reference deleted types | `SpendWise_V2_Tech_Doc.md` locked decision 3 + "Shipped surface" section; Critique v2 status #7 (CalendarConfig deleted); repo has no `Period`/`CalendarConfig` | **PARTIAL** — add one warning line to §7: only the *decisions* are locked; the V2 doc's descriptions of shipped code are stale, behavior comes from the frozen repo |
| C5 | Repo CLAUDE.md is stale (pre-EventBus: "bumps `revision` and forwards to `store?.enqueue`"; `Ledger` has neither) — the plan correctly describes the bus architecture, so no error, but worth stating that the frozen repo's own CLAUDE.md is NOT a trusted source | `SpendWise-SwiftUI/CLAUDE.md:19` vs `Ledger.swift` (no revision, no store reference); Critique v2 Con 11 | **COVERED in practice** (plan verified against code); optional one-liner in the plan's preamble |

### D. Corner-case behaviors the plan is silent on

| # | Gap | Evidence | Verdict |
|---|---|---|---|
| D1 | **Currency is hardcoded** in ~26 call sites: `.formatted(.currency(code: "SGD"))` across every money label, plus a literal `"$"` prefix in `AmountField` | e.g. `TransactionCell.swift:24`, `AccountsView.swift:108-312`, `StatsView.swift:97,166`, `PlanListView.swift:80`, `AmountField.swift:48`; single-currency was a deliberate spec cut (`SwiftUI_Project_Spec.md:32,50`: "`currency` intentionally omitted") | **MISSED** — the plan never says the word currency. Record the single-currency decision, centralize formatting in ONE Dart helper (do not scatter 26 hardcoded codes again), and note whether the code is a constant or a setting. Cheap now, painful later |
| D2 | Amount input parsing is dot-decimal English-only: `AmountFormat.sanitize` accepts only `.` as separator and truncates to 2 fraction digits; form parsing is `Decimal(string:)` on that text | `AmountField.swift:18-37`, `SourceEditView.swift:85-87` | **MISSED (small)** — §5 hazard-list addition: define amount-input locale behavior (accept locale separators or force dot) and keep the 2-dp rule with the currency decision (D1) |
| D3 | Week-start convention: month-breakdown weeks come from `calendar.dateInterval(of: .weekOfYear)` on `Calendar.current`, so the week boundary follows the device locale (Sun vs Mon start) | `TransactionsViewModel.swift:95-122` | **MISSED (small)** — Dart has no `weekOfYear` interval; the hand-written helper must pick a convention (locale-driven or fixed) and test both week-start cases |
| D4 | Interval boundary semantics: Foundation's `DateInterval.contains` is **end-inclusive**, and month intervals end at the next month's first instant, so an entry timestamped exactly at that boundary double-counts in both windows (`filtered(in:)` and `daySections`' `range.contains`) | `Accounting+Analysis.swift:26` (`interval?.contains`), `TransactionRow.swift:105-107`; `TransactionsViewModel.swift:52` | **MISSED (small)** — latent in Swift, easy to fossilize in Dart. Pin half-open `[start, end)` semantics for all window filters in the domain, with a boundary test (this is the `<=`-boundary blind spot again) |
| D5 | Plan-resolution triggers: `resolvePlans` runs on scene-active AND immediately after creating a plan from the entry form (`ledger.resolvePlans(calendar:)` in `addPlan`), and the form sets `lastResolvedDate = anchor − 1s` so the anchor day materializes instantly; the sample's plans use `lastResolvedDate = anchor` (anchor skipped) | `EntryFormViewModel.swift:184-193`; `Ledger+Sample.swift:178-199` | **PARTIAL** — §4.3 lifecycle covers only `resumed`. One line: resolve also fires after plan creation; the cursor-vs-anchor convention is a behavior to pin (module specs should own the detail) |
| D6 | Archiving an account permanently deletes plans referencing it or its pockets; restore does NOT bring plans back ("plans are regenerable config, not history") | `LedgerState.swift:317-335` (`removePlansReferencing` inside `deleteAccount`) | **COVERED implicitly** — §4.1 "port first, no redesign" + Phase 2 test parity carries it; listed here so the asymmetry (restorable account, unrestorable plans) is not "fixed" as a bug during the port |
| D7 | Seeding is failure-tolerant to a fault: `Ledger.sample()` builds through `try?` on every mutation; any validation tightening in the Dart domain silently thins the seed instead of failing | `Ledger+Sample.swift:82-100,174-176,200-201`; `SwiftDataLedgerStore.swift:261-267` (`hasSeeded` set before the flush) | **MISSED (small)** — make the Dart seed builder throw/assert in debug so a seed regression is loud; ties directly to C2 |

---

## 2. Prioritized edits to `Flutter_Port_Tech_Doc.md`

1. **§4.1 + §5.3 — resolve the occurrence-id timezone contradiction (C1).** One decision,
   stated once: UTC/date-only normalization with a native-data migration note, OR byte-compat
   local-tz replication. Rewrite the pin-test instruction to name the timezone of the captured
   triple.
2. **§1 — fix the pocket opening-balance claim (C2).** Replace "Pockets have no opening balance"
   with "opening balance is form-restricted to accounts; the domain accepts a synthetic opening
   entry for any holder, and the sample seed + balance-adjust flow rely on that". Add the
   sample-seed-must-not-silently-thin note (D7).
3. **Phase 6 — expand the treat-as-expense item into the locked spec (B4).** Reference V2
   Handover Phase 5 explicitly; enumerate: `loan`/`overdraft` appended to `AccountType`
   (encoding-stable), `allowsTransfersAsExpense` gate + forced-false on save, deterministic
   synthetic per-type bucket ids, pocket→parent-type resolution, expense-only, self-carried
   slice name/symbol rendering.
4. **§3 or §4.3 — currency policy (D1) + amount-input locale (D2).** Single-currency decision
   recorded, one money-formatting helper, one amount-parsing rule. Add both to the §5 hazard
   list.
5. **Phase 6 or §7 — scope-aware transfer direction (B5).** Add the designed
   `transferDirection` behavior (in/out/neutral by viewed scope) next to the totals-unification
   decision it was designed with, or write down that it is cut.
6. **§4.3 drift schema — reserve `Entry.note` (B3)** (or record its deferral as a conscious
   migration cost), and state the column-decode fallback policy including version-vector
   decode failure as an error, not an empty vector (A13).
7. **§4.3 — fix `failedWillRetry` passivity (A9):** timed re-flush or retry on next lifecycle
   event, and make the banner text truthful. Add to the §8 definition of done alongside the
   other two store fixes.
8. **§3 state-shape — write the `AnalysisCache` snapshot rule (A12):** explicit snapshot/clone
   handed to `Isolate.run`, or a stated argument for relying on the isolate's implicit copy;
   note the web (sync, live-object) path is only safe because it is synchronous.
9. **§5 hazards — add three small ones:** half-open window semantics `[start, end)` everywhere
   with a boundary test (D4); week-start convention for week summaries (D3); domain-level
   `statementDay` range validation, not just clamped cut math (A3 nuance).
10. **§7 roadmap — add search/filter (B6) and an export/backup line to the import item (B7);**
    plus one warning that the V2 doc's "shipped surface" descriptions are stale, only its
    decisions are locked (C4).
11. **§4.4 — one sentence on screen-state ownership (A11):** selected month/mode/kind live in
    providers so widget rebuilds cannot reset them; also persisted-string decision for
    "Opening balance"/"Balance adjustment" entries (A7): structural marker + display-time
    naming instead of stored English literals.
12. **§1/§8 — correct the test count (C3):** 119 `@Test` functions today; make "parity with the
    actual frozen suite" the wording. Optionally add one `integration_test` smoke per platform
    to Phase 7 (A14).

---

## 3. Explicitly checked, no finding

To keep the empty categories honest: `LedgerError` really has 12 cases, `LedgerChange` 9,
the invariant sweep 11 numbered clauses, debounce 250 ms / 2 retries / 200 ms backoff, barrier
`flushNow`, seed gated on `hasSeeded` (not emptiness), boot phase machine, plan-failure
banners, per-device UUID in store meta — all as the plan states. The event-driven architecture
docs' serial-queue/command/generation-guard design was **rejected during the build**
(EventDriven Handover "Scope decisions"); the plan correctly describes only the shipped
bus + subscribers and does not resurrect the phantom machinery. No TODO/FIXME markers exist in
the Swift sources. The V2 Handover's "REMAINING Phase 7" items (resolvePlans hardening,
write-path ordering, rename nit) were all subsequently built and are in the frozen code.
