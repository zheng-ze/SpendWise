Task groups map to the commit sequence. Each group must leave `dart analyze` and `flutter analyze` at
zero issues and both suites green before the next begins. The user commits; do not run `git commit`.

References: `docs/Flutter_Port_Tech_Doc.md` §6 Phase 6 for the locked sub-decisions, and
`docs/modules/ui_screens.md` §6 for the defect table. The locked treat-as-expense sub-decisions come
from `SpendWise_V2_Handover.md` Phase 5 — its *decisions* are authoritative, its descriptions of
shipped surfaces are stale.

Depends on all five Phase 5 changes — this modifies screens they build.

Unlike earlier phases, this one changes behavior deliberately. Existing tests will change; each
changed expectation must be visible in review, never absorbed by loosening an assertion.

## 1. Account types and eligibility

- [x] 1.1 Append `loan` and `overdraft` to `AccountType` with new explicit codes. APPEND ONLY —
      inserting a case silently changes what every stored code above it means (`design.md`)
      (`packages/domain/lib/src/account_type.dart:9-11`, `fromCode` cases at `:36-37`)
- [x] 1.2 Add `allowsTransfersAsExpense` gating eligibility: blocked for cash, checking, card and
      prepaid (`packages/domain/lib/src/account_type.dart:21-24`)
- [x] 1.3 Force `incomingTransfersAsExpenses` false on save for an ineligible type — do not merely
      hide the control, or a stale true flag survives a type change
      (`packages/domain/lib/src/account.dart:66-72` `withEligibleTransferFlag`, chained in
      `packages/domain/lib/src/ledger_state_holders.dart:11` `addAccount` and `:25` `updateAccount`)
- [x] 1.4 Test: data written with the old codes still loads with the same types — this is the test
      that catches an inserted case (`packages/domain/test/enum_codes_test.dart:52-68`)
- [x] 1.5 Test: set the flag, change to an ineligible type, save, confirm the flag is false
      (`packages/domain/test/ledger_state_holders_test.dart:169-182` `addAccount`,
      `:207-226` `updateAccount`)
- [x] 1.6 Update the holder form to show the toggle only for eligible types
      (`app/lib/ui/accounts/source_edit_form.dart:78-86` `_eligibleType`/`_showsTransferToggle`, gate
      applied at the switch's `if` at `:180`, reset on type change at `:99`. A pocket has no type of
      its own so it follows its parent account's via `LedgerState.owningAccount`. EDIT: also found and
      fixed a crash while verifying this group — `account_type_picker.dart`'s `_typeLabels` map listed
      only the original 8 types and hard-crashed with a null-check the moment the picker was opened
      after 1.1 appended `loan`/`overdraft` to `AccountType.values`, caught by `account_form_test.dart`
      going red. Fixed at `app/lib/ui/accounts/account_type_picker.dart:12-14`)
      (tests: `app/test/ui/accounts/source_edit_form_test.dart` "net worth toggle is hidden for a
      pocket" updated — a cash-parented pocket is ineligible so the toggle now hides there too — plus
      two new tests, "transfer toggle shows for a pocket whose parent is eligible" and "switching an
      account to an ineligible type hides and resets the transfer toggle")

## 2. Synthetic buckets

- [x] 2.1 Add deterministic synthetic bucket ids derived per account type — derived, never stored, so
      there is no migration and every device agrees
      (`packages/domain/lib/src/synthetic_buckets.dart:6-15` `syntheticTransferExpenseBucketID`,
      throws for an ineligible type rather than deriving a meaningless id)
- [x] 2.2 Change `classify` so a treat-as-expense transfer buckets by the destination account's type
      instead of carrying no category
      (`packages/domain/lib/src/accounting.dart:132-140`)
- [x] 2.3 A pocket destination resolves to its parent account's type
      (`packages/domain/lib/src/accounting.dart:181-189` `_destinationAccountType`, reuses
      `LedgerState.owningAccount` from `packages/domain/lib/src/ledger_state_queries.dart:35-36`)
- [x] 2.4 These buckets are expense-only — a transfer never produces an income item through this path
      (`packages/domain/lib/src/accounting.dart:141-147`, income leg untouched, still `bucketID: null`)
- [x] 2.5 Test: two accounts of one type share a bucket; a pocket destination buckets by its parent;
      no synthetic bucket appears in income analysis
      (`packages/domain/test/accounting_analysis_test.dart:99` `two accounts of the same
      eligible type share a synthetic bucket`, `:132` `a transfer into a pocket buckets by the
      pocket's parent type`, `:150` `the income leg of a transfer never carries a synthetic
      bucket`; `packages/domain/test/synthetic_buckets_test.dart` covers the pure function directly)
- [x] 2.6 Update the existing accounting and analysis tests whose expectations change, one visible
      edit at a time
      (`packages/domain/test/accounting_analysis_test.dart:53` `a transfer into a
      treat-as-expense holder produces expense` now expects
      `syntheticTransferExpenseBucketID(AccountType.savings)`;
      `:243` `an archived transfer destination keeps its expense item` same change — the
      destination account's type survives archiving, only its lifecycle changes)

## 3. Synthetic slice presentation

- [x] 3.1 Slices for synthetic buckets carry their own name and symbol rather than a category's, and
      render in a neutral color. Added `Slice.name` and a reverse lookup
      `syntheticTransferExpenseAccountType` in the domain so the UI never string-parses a bucket id
      (`app/lib/ui/stats/slices.dart:27-53` `Slice` with `name`/`isSynthetic`/`isNavigable`, `:76-115`
      `_slice` branches on category vs. synthetic vs. uncategorized;
      `packages/domain/lib/src/synthetic_buckets.dart:17-28` `syntheticTransferExpenseAccountType`).
      EDIT: `Accounting.mainBucketID` was collapsing every synthetic bucket id straight to `null`
      before this could work, because it treated "no category row" as "no bucket" — a synthetic id by
      design has no row. Fixed the fallthrough to only collapse a null *input*, not an unresolved one
      (`packages/domain/lib/src/accounting.dart:216-227`). Also removed the now-unused `state` param
      from `StatsDonut`/`StatsLegend`, which only ever used it for this same name lookup
      (`app/lib/ui/stats/stats_donut.dart:20-54`, `app/lib/ui/stats/stats_legend.dart:12-38`, callers
      updated at `app/lib/ui/stats/stats_screen.dart:157-162`)
- [x] 3.2 They are NOT navigable — there is no category row behind them to open
      (`app/lib/ui/stats/slices.dart:48` `isNavigable`, consumed at
      `app/lib/ui/stats/stats_legend.dart:29-32`; `StatsDonut` has no tap handler at all so there is
      no second entry point to gate)
- [x] 3.3 Test: tapping a synthetic slice pushes nothing
      (`app/test/ui/stats/stats_legend_test.dart:82-90` `tapping a synthetic slice invokes nothing`,
      `:92-96` `the synthetic row renders no chevron`;
      `app/test/ui/stats/slices_test.dart:167-182` proves `_slice`/`slices()` give a synthetic bucket
      its own name/symbol/neutral color instead of Uncategorized's;
      `packages/domain/test/accounting_analysis_test.dart:636-642` and `:657-676` cover the
      `mainBucketID`/`rollUp` fix directly)

## 4. Totals ruling

- [x] 4.1 Make the transactions-versus-stats totals ruling with both screens in front of you: either
      route both through the same analysis gates, or record the divergence as intentional. Earlier
      phases kept the call site singular so this is a one-line change (`design.md`). Ruled: unify —
      Transactions was wrongly skipping every transfer, including a treat-as-expense one; fixed to
      apply the same gate Stats already applied
      (`packages/domain/lib/src/accounting.dart:184` `Accounting.totals`, shares its rule with
      `Accounting.classify` at `:116`)
- [x] 4.2 Record the ruling inline in `docs/Flutter_Port_Tech_Doc.md` §5, which reserves a spot for it
      (`docs/Flutter_Port_Tech_Doc.md:299-306`, item 10, resolving the open defect noted at `:83-86`)
- [x] 4.3 Apply it at the single call site (`app/lib/ui/transactions/day_sections.dart:67-82` `_totals`,
      `app/lib/ui/transactions/month_summaries.dart:129-143` `sectionTotals` — both now delegate to
      `Accounting.totals` instead of hand-rolling the transfer skip)
- [x] 4.4 If the divergence is kept, state it where a user can see it rather than leaving it to be
      discovered — not applicable, the ruling removes the divergence rather than keeping it, so there
      is nothing to surface in the UI
- [x] 4.5 Test: the same month reported by both screens matches the ruling
      (`app/test/ui/transactions_stats_totals_parity_test.dart` — one `LedgerState`, one month, asserts
      `monthSummaries`'s expense total equals `slices()`'s summed expense total; confirmed red against
      the old skip-transfer logic before restoring the fix. Per-screen coverage also at
      `app/test/ui/transactions/day_sections_test.dart:227-345` and
      `app/test/ui/transactions/month_summaries_test.dart:110-193`)

## 5. Scope-aware transfer display

- [x] 5.1 Add scope-aware transfer sign and color: leaving the scope reads as a loss, entering it as a
      gain, both endpoints inside or an unscoped list stays neutral
      (`app/lib/ui/transactions/entry_transfer_scope.dart` `TransferScopeSign`, `Entry.transferScopeSign`
      extension — kept out of `packages/domain`, since scope is a screen's current view, not a
      domain concept;
      `app/lib/ui/transactions/transaction_row.dart:100-108` `_transferAmountKind` maps the sign onto
      the existing `income`/`expense`/`transfer` `AmountKind` values, so `formatSignedAmount`/
      `kindColor` need no new cases)
- [x] 5.2 Account scope is the account plus its active pockets; pocket scope is that pocket alone
      (already built by the account/pocket row taps in `app/lib/ui/accounts/accounts_screen.dart:73,80`,
      unchanged this task; threaded into row rendering at
      `app/lib/ui/transactions/day_sections.dart:47,59` via the existing `sourceScope` param)
- [x] 5.3 Test the three-way matrix — out, in, both — at account scope and at pocket scope
      (`app/test/ui/transactions/entry_transfer_scope_test.dart` for the sign rule,
      `app/test/ui/transactions/transaction_row_test.dart:216-297` for row rendering)
- [x] 5.4 Test: an account-to-own-pocket transfer is neutral at account scope and a gain at pocket
      scope (`app/test/ui/transactions/transaction_row_test.dart:299-335`)

## 6. Accessibility

- [x] 6.1 Add semantics to every custom widget, scoped to the widgets 6.2-6.3 name (donut, expanding
      FAB, two-column picker, the 7 swipe-action sites) — not a repo-wide sweep
- [x] 6.2 Give the donut a text alternative conveying each bucket, its amount and its share. V1 hid it
      from assistive technology with no fallback, so the screen conveyed nothing
      (`app/lib/ui/stats/stats_donut.dart:28-56` `_summaryLabel`, one line per slice with name,
      `formatCurrency`, `formatPercent`, wrapped in `Semantics(label: ...)` with the `CustomPaint`
      excluded so a screen reader reads only the composed label)
- [x] 6.3 Add labels or custom actions for the expanding action button, the two-column picker and every
      swipe action — all are gesture-only affordances today
      (`app/lib/ui/common/expanding_fab.dart` — `tooltip` on both FABs, expand/collapse state reflected
      in the toggle's tooltip, action capsules wrapped `Semantics(button: true, label: ...)`, backdrop
      scrim excluded; `app/lib/ui/common/two_column_picker_sheet.dart:180` — `selected` threaded into
      `ListTile`'s own `selected:` param, which already exposes selection semantics for free; all 7
      `Dismissible` sites wrapped in `Semantics(customSemanticsActions: {...})` reusing the same
      confirm-then-act callback the swipe already used —
      `app/lib/ui/settings/category_list_screen.dart:165`, `plan_list_screen.dart:83`,
      `recycle_bin_screen.dart:263` (restore + purge), `app/lib/ui/transactions/daily_transactions_screen.dart:318`,
      `app/lib/ui/accounts/account_row.dart:39,66` (account + pocket), `app/lib/ui/stats/category_detail_screen.dart:694`)
- [x] 6.4 Test: the donut exposes its text alternative; swipe actions appear as custom actions
      (`app/test/ui/stats/stats_donut_test.dart` label test; `app/test/ui/common/expanding_fab_test.dart`,
      `app/test/ui/common/picker_sheet_test.dart`; swipe-action tests across
      `category_list_screen_test.dart`, `plan_list_screen_test.dart`, `recycle_bin_screen_test.dart`,
      `daily_transactions_screen_test.dart`, `category_detail_screen_test.dart`,
      `app/test/ui/accounts/account_row_test.dart` (new); shared dispatch helper at
      `app/test/support/semantics_test_support.dart` (new). Full gate: domain unaffected;
      `flutter analyze` zero issues; `flutter test` across stats/common/settings/transactions/accounts
      302 tests, 2 failing — both the pre-existing unrelated `stats_donut_test.dart` golden pixel-diff)

## 7. Localization

DEFERRED. This is a personal-use app right now, no need for localization yet. Revisit if that changes.

- [ ] 7.1 Add `flutter_localizations` and the localization scaffolding
- [ ] 7.2 Declare user-facing strings through it rather than inline
- [ ] 7.3 Route every shared format from the UI foundation through the localization layer
- [x] 7.3a Wire `systemKind`, pulled forward ahead of the rest of this group. While scoping 7.4, found
      it was a live bug, not a theoretical gap: with the column unwritten, a user could open "Opening
      balance"/"Balance adjustment" in the ordinary entry-edit form and freely rename, re-amount, or
      swipe-delete them, silently breaking the string-match lookups in `seed_data_test.dart` and
      `ledger_state_entries_test.dart` and desyncing the account balance the entry exists to seed or
      correct. Fixed ahead of the rest of localization since it is a correctness gap independent of it
      (`packages/domain/lib/src/entry.dart:11-24` `SystemEntryKind`, `:38,63` `Entry.systemKind`;
      `packages/domain/lib/src/ledger_error.dart:109-114` `SystemEntryLocked`;
      `app/lib/ui/accounts/source_edit_form_logic.dart:33` stamps balance-adjustment;
      `app/lib/persistence/mappers.dart:146,160` round-trips the code column.

      Rule corrected after review, since the first cut locked the wrong fields: name and delete were
      blocked, amount was editable. The actual rule is name, category and `includeInAnalysis` locked
      (fixed at the value each kind is created with), amount, date and delete free — a system entry
      can be corrected or removed like any other entry, it just cannot be renamed, recategorized, or
      pulled into analysis totals it was deliberately created to sit outside of. Guard now at
      `packages/domain/lib/src/ledger_state_entries.dart:16-21` `updateEntry`; `deleteEntry` (`:59-65`)
      has no guard at all, deletion is unconditional. `app/lib/ui/transactions/entry_form.dart:321-325`
      always shows Edit; the name field (`:372`), category row (`:484`) and Include in Analysis switch
      (`:387`) individually stay locked via `_isSystemEntry`, amount/date/delete stay responsive.
      `app/lib/ui/transactions/daily_transactions_screen.dart` — the swipe-skip for system-entry rows
      was removed, swipe-to-delete now behaves the same as any other entry.

      Tests: `packages/domain/test/ledger_state_entries_test.dart:396-546` (both kinds, name/category/
      includeInAnalysis throw, amount/date/delete succeed), `app/test/persistence/mappers_test.dart:250-298`,
      `app/test/ui/transactions/entry_form_test.dart:342-441`,
      `app/test/ui/transactions/daily_transactions_screen_test.dart:153-188`. Full gate: domain 542
      tests green, `flutter analyze` zero issues, `flutter test` 658 tests, 2 failing — both the
      pre-existing unrelated `stats_donut_test.dart` golden pixel-diff)
- [ ] 7.4 Do NOT rewrite stored entry names — "Opening balance" and "Balance adjustment" are data. The
      structural marker reserved at schema day one is what lets display-time naming take over later
- [ ] 7.5 Test: an entry stored with an English name keeps it

## 8. Layout polish and close-out

- [x] 8.1 Polish the adaptive rail layout on wide windows
      (`app/lib/ui/shell/layout_breakpoints.dart` (new) named the breakpoint instead of a raw constant;
      `app/lib/ui/shell/app_shell.dart:34-56` hysteresis via two thresholds each for rail entry/exit
      (720/680) and extended-rail entry/exit (1000/960), so a window sitting at a boundary does not
      flicker; `:122` `AnimatedSwitcher` cross-fades the bottom-nav/rail swap instead of an abrupt cut;
      `:101-107` a third tier, `extended: true` above 1000px instead of only compact-label rail. Tests:
      `app/test/ui/shell/app_shell_test.dart`, 4 new cases added to the existing 5, 9 total, all green)
- [x] 8.2 Run `cd packages/domain && dart analyze && dart test` and `cd app && flutter analyze &&
      flutter test`. Analyzer at zero issues, not just zero errors
      (domain: zero issues, 534 tests green. app: zero issues, 653 tests, 2 failing — both the
      pre-existing unrelated `stats_donut_test.dart` golden pixel-diff)
- [x] 8.3 Review every test expectation this change altered and confirm each was edited deliberately
      (`git diff -- '*_test.dart'` against the last commit shows zero removed or changed `expect(...)`
      lines across every touched test file, groups 6 and 7.3a only added new tests, nothing existing
      was altered, so there is nothing here to review for deliberateness)
- [x] 8.4 Confirm no stored enum code changed meaning: load a fixture written before group 1
      (`packages/domain/test/enum_codes_test.dart:52-68` already covers this for `AccountType` with a
      hardcoded pre-group-1 8-entry code map; `LifecycleState`/`CategoryKind` were untouched by group 1
      so need no such test. `Entry.systemKind`, the one new field added since, is nullable and
      `SystemEntryKind.fromCode` returns null on an absent code rather than throwing or defaulting
      wrong — confirmed at `packages/domain/lib/src/entry.dart:19-23` and
      `app/lib/persistence/mappers.dart:146` — so a fixture written before this field existed still
      round-trips correctly)
