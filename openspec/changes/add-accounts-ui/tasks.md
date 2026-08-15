Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ui_screens.md` §4, which is more detailed than the
specs in this change.

Depends on `add-app-shell-and-boot` and `add-transactions-ui` — rows navigate to the scoped
transactions screen, and the source edit form is reached from its action button.

## 1. Summary and sections

- [x] 1.1 Add the screen scaffold: header row with an add button, summary bar, divider, grouped list.
      The tab owns its own navigation stack
      (`app/lib/ui/accounts/accounts_screen.dart:27`, wired into the shell at
      `app/lib/ui/shell/boot_chrome.dart:21`)
      EDIT: the accounts tab pushes `MaterialPageRoute`s directly from its own
      `Navigator` (the one the shell already gives each destination in
      `app_shell.dart`) rather than opening a second nested `Navigator` — the
      shell's per-destination `Navigator` already is the tab's own stack.
- [x] 1.2 Add the summary bar from `Accounting.netWorth` — assets, liabilities, and their difference.
      Do not recompute the split here (`app/lib/ui/accounts/accounts_screen.dart:150`)
- [x] 1.3 Add `accountSections(state)` as a pure function: group active accounts by type, emit in the
      fixed type order, skip types with no accounts
      (`app/lib/ui/accounts/account_sections.dart:100`)
      EDIT: signature is `accountSections(LedgerState state, {required DateTime now})` — `now` has to
      reach the card rows' statement-cut math, so it is threaded through here rather than read by a
      card row on its own.
- [x] 1.4 Per row derive the total (own balance plus active pockets) and the own balance excluding
      pockets, plus the pocket sub-rows (`app/lib/ui/accounts/account_sections.dart:137`)
- [x] 1.5 Non-card section header shows the summed row totals, colored when negative
      (`app/lib/ui/accounts/account_sections.dart:191`)
      EDIT: the derivation returns the raw subtotal only; coloring is a widget-layer decision left for
      task 1.1's screen, since a pure function with no widget imports cannot carry a `Color`.
- [x] 1.6 Card section header shows two labelled figures, payable and outstanding, each summed over
      its rows. Do NOT port V1's mixed subtotal reduce — card sections never render it (`design.md`)
      (`app/lib/ui/accounts/account_sections.dart:191`)
- [x] 1.7 Test: grouping, the fixed order, empty-type skipping, and both section header shapes
      (`app/test/ui/accounts/account_sections_test.dart`, 6 tests)

## 2. Card math

- [x] 2.1 Add `statementCut(statementDay, now)` as a pure function taking `now` as a parameter —
      never reading the clock internally (`app/lib/ui/accounts/card_math.dart:3`)
- [x] 2.2 Anchor month is the current month when today's day is on or after the statement day, else
      the previous month (`app/lib/ui/accounts/card_math.dart:3`)
- [x] 2.3 Build the cut date with the shared clamping helper so a statement day beyond the month's
      length lands on its last day. Dart's `DateTime` rolls over silently, so an unclamped port is
      wrong by construction (`design.md` — this is the V1 defect being fixed)
      (`app/lib/ui/accounts/card_math.dart:9`)
      EDIT: reused `shiftMonthThenClampDayUtc` from `calendar_day.dart` with `months: 0` rather than
      writing a separate same-month clamp helper — passing zero shifts leaves the month unchanged and
      the day clamp is what runs, so the existing helper covers this without a near-duplicate.
- [x] 2.4 Add `payable(accountTotal)`: the negated total clamped at zero
      (`app/lib/ui/accounts/card_math.dart:12`)
- [x] 2.5 Add `outstanding(entries, accountID, cut, now)`: negated sum over entries sourced from the
      card account itself, not transfers, negative, dated on or after the cut and not after now
      (`app/lib/ui/accounts/card_math.dart:17`)
- [x] 2.6 Test the clamp matrix: statement days 28, 29, 30, 31 against February, a leap February, a
      30-day month and a 31-day month (`app/test/ui/accounts/card_math_test.dart`, 7 cases)
- [x] 2.7 Test the anchor month on both sides of the statement day
      (`app/test/ui/accounts/card_math_test.dart`, 4 tests)
- [x] 2.8 Test the outstanding filter matrix — a transfer, a positive amount, a pocket-sourced entry
      and an out-of-window entry must each be excluded
      (`app/test/ui/accounts/card_math_test.dart`, one test per exclusion reason plus a boundary-sum
      test)
- [x] 2.9 Test payable clamping at zero for a card in credit
      (`app/test/ui/accounts/card_math_test.dart`)

## 3. Rows, expansion, navigation

- [x] 3.1 Add the account row: expansion chevron with its own hit target and only when the account has
      pockets, name, and the amount display or the card two-column form
      (`app/lib/ui/accounts/account_row.dart:8`, chevron `account_row.dart:100`)
- [x] 3.2 Tapping the row body opens the transactions screen titled with the account name, scoped to
      the account plus all its pocket ids
      (`app/lib/ui/accounts/accounts_screen.dart:60`)
      EDIT: the scoped id set travels through a new `TransactionsScreen.scopeIDs` field
      (`app/lib/ui/transactions/daily_transactions_screen.dart:29`) rather than widening the existing
      `sourceScope` string. `sourceScope` still identifies the screen for its date-state provider and
      prefills the add-entry form with the account itself; `scopeIDs` (falling back to `{sourceScope}`
      when omitted) is what `daySections` now filters against, since a pocket can be referenced without
      being the account. `daySections`'s own `sourceScope` parameter widened from `String?` to
      `Set<String>?` to take it (`app/lib/ui/transactions/day_sections.dart:25`), covered by a new
      multi-id test (`app/test/ui/transactions/day_sections_test.dart`).
- [x] 3.3 Add expansion, one account at a time, with an excluding-subpockets row scoped to the account
      alone and showing its own balance, plus one row per pocket scoped to that pocket
      (`app/lib/ui/accounts/accounts_screen.dart:51`, state field `_expandedAccountID`)
      EDIT: plain `StatefulWidget` field rather than a Riverpod notifier — the transactions screen's
      `NotifierProvider.family` pattern exists to key per-scope date/mode state that must survive a tab
      switch; this is a single transient "which row is open" flag with no such persistence need.
- [x] 3.4 Golden test the account row, including the card variant
      (`app/test/ui/accounts/account_row_golden_test.dart`,
      `app/test/ui/accounts/goldens/account_row.png`)
- [x] 3.5 Test: expansion is single-open; each scoped navigation carries the right id set
      (`app/test/ui/accounts/accounts_screen_test.dart`, 8 tests)

## 4. Deletion

- [x] 4.1 Add swipe-delete on account and pocket rows, archiving to the recycle bin
      (`app/lib/ui/accounts/account_row.dart:38` account, `:58` pocket; mutators
      `Ledger.deleteAccount`/`deletePocket` called from `accounts_screen.dart:98,113`)
- [x] 4.2 Confirmation names the holder and states how many entries keep its name — V1 computed this
      count and never displayed it (`design.md`, deliberate deviation)
      (`app/lib/ui/accounts/delete_holder_confirmation.dart:5`, count from
      `LedgerState.entriesReferencing` called at `accounts_screen.dart:89,105`)
- [x] 4.3 Deleting an expanded account collapses it
      (`app/lib/ui/accounts/accounts_screen.dart:99`)
- [x] 4.4 Test: the confirmation's reference count; the collapse on delete
      (`app/test/ui/accounts/accounts_screen_test.dart`)

## 5. Account form

- [x] 5.1 Add the creation sheet with an account/subpocket segmented choice, locked to account when no
      account can hold a pocket
      (`app/lib/ui/accounts/account_form.dart:20`)
- [x] 5.2 Pocketable parents are active non-card accounts sorted by name — cards cannot hold pockets,
      guarded in both the picker and the controller
      (`app/lib/ui/accounts/account_form_logic.dart:7`, guarded again at `account_form.dart:100`
      for save)
- [x] 5.3 Account mode: name, type picker, statement day picker shown only for cards, optional opening
      balance
      (`app/lib/ui/accounts/account_form.dart:178`)
- [x] 5.4 Subpocket mode: name and parent picker
      (`app/lib/ui/accounts/account_form.dart:197`)
- [x] 5.5 `canSave`: trimmed name non-empty; a subpocket also needs a parent
      (`app/lib/ui/accounts/account_form_logic.dart:15`)
- [x] 5.6 Save an account via `addAccount`, persisting the statement day only for cards, then post the
      opening balance via `setOpeningBalance` when it is non-zero. Save a subpocket via `addPocket`
      (`app/lib/ui/accounts/account_form.dart:97`)
- [x] 5.7 Errors surface in the form's error section
      (`app/lib/ui/accounts/account_form.dart:123`, `account_form.dart:190`)
- [x] 5.8 Test: the pocketable-parents filter; the locked-kind case; statement day persisted only for
      cards; no opening entry when the balance is zero
      (`app/test/ui/accounts/account_form_logic_test.dart`, 6 tests;
      `app/test/ui/accounts/account_form_test.dart`, 6 tests)

## 6. Source edit form

- [x] 6.1 Add the edit sheet titled for an account or a subpocket, reached from the scoped
      transactions screen's action button
      (`app/lib/ui/accounts/source_edit_form.dart:22`, wired at
      `app/lib/ui/transactions/daily_transactions_screen.dart:165`)
      EDIT: `TransactionsScreen.sourceScope` is a single `String?`, so the FAB's secondary action
      fires whenever it is non-null, matching "reached when `sourceScope` is a single holder id" —
      the wider `scopeIDs` set used for row filtering is unaffected.
- [x] 6.2 Name on both; type picker and card statement day on accounts only
      (`app/lib/ui/accounts/source_edit_form.dart:163`)
- [x] 6.3 Add the balance field allowing negatives, pre-filled with the current derived balance
      (`app/lib/ui/accounts/source_edit_form.dart:52`, `source_edit_form.dart:173`)
- [x] 6.4 On save, when the entered balance differs from the current one, post ONE adjustment entry
      for the difference with analysis excluded. Never rewrite stored entries — the entry log is the
      source of truth for every balance (`design.md`)
      (`app/lib/ui/accounts/source_edit_form_logic.dart:18` — `balanceAdjustmentEntry`, called from
      `source_edit_form.dart:133`)
- [x] 6.5 No difference means no entry. An empty balance field counts as zero
      (`app/lib/ui/accounts/source_edit_form_logic.dart:23` returns null on zero delta;
      `parseEnteredBalance` at line 12 treats blank text as zero)
- [x] 6.6 Add the treat-as-expense toggle on both, with its explanatory footer, and the net-worth
      toggle on accounts only
      (`app/lib/ui/accounts/source_edit_form.dart:180`)
      EDIT: the domain flag is `incomingTransfersAsExpenses` on both `Account` and `SubPocket`
      (`packages/domain/lib/src/account.dart:16`, `packages/domain/lib/src/sub_pocket.dart:10`), not
      `treatIncomingTransfersAsExpense` as sketched in the brief.
- [x] 6.7 `canSave`: name non-empty and the balance parses
      (`app/lib/ui/accounts/source_edit_form_logic.dart:3`)
- [x] 6.8 Save via `updateAccount` or `updatePocket`, then the adjustment, then dismiss
      (`app/lib/ui/accounts/source_edit_form.dart:103`)
- [x] 6.9 Test the balance-adjustment delta logic including the no-delta case, which must post nothing
      (`app/test/ui/accounts/source_edit_form_logic_test.dart`, 8 tests;
      `app/test/ui/accounts/source_edit_form_test.dart`, 6 tests)

## 7. Close-out

- [x] 7.1 Run `cd app && flutter analyze && flutter test`. Analyzer at zero issues, not just zero errors
      (505/505 green, zero analyzer issues, verified independently at repo root)
- [x] 7.2 Confirm no `double` money reached `app/lib/`
      (`rg '\bdouble\b' app/lib/ui/accounts/` — zero hits)
- [x] 7.3 Confirm no naive `DateTime(y, m, d)` construction for the statement cut:
      `grep -rn "DateTime(" app/lib/ui/accounts/`
      (zero hits — `statementCut` builds via `shiftMonthThenClampDayUtc`, `card_math.dart:9`)
- [x] 7.4 Confirm the derivation functions carry no widget imports
      (`account_sections.dart`, `card_math.dart`, `account_form_logic.dart`,
      `source_edit_form_logic.dart` — no `flutter/material` import in any)
