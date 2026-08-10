Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ui_screens.md` §4, which is more detailed than the
specs in this change.

Depends on `add-app-shell-and-boot` and `add-transactions-ui` — rows navigate to the scoped
transactions screen, and the source edit form is reached from its action button.

## 1. Summary and sections

- [ ] 1.1 Add the screen scaffold: header row with an add button, summary bar, divider, grouped list.
      The tab owns its own navigation stack
- [ ] 1.2 Add the summary bar from `Accounting.netWorth` — assets, liabilities, and their difference.
      Do not recompute the split here
- [ ] 1.3 Add `accountSections(state)` as a pure function: group active accounts by type, emit in the
      fixed type order, skip types with no accounts
- [ ] 1.4 Per row derive the total (own balance plus active pockets) and the own balance excluding
      pockets, plus the pocket sub-rows
- [ ] 1.5 Non-card section header shows the summed row totals, colored when negative
- [ ] 1.6 Card section header shows two labelled figures, payable and outstanding, each summed over
      its rows. Do NOT port V1's mixed subtotal reduce — card sections never render it (`design.md`)
- [ ] 1.7 Test: grouping, the fixed order, empty-type skipping, and both section header shapes

## 2. Card math

- [ ] 2.1 Add `statementCut(statementDay, now)` as a pure function taking `now` as a parameter —
      never reading the clock internally
- [ ] 2.2 Anchor month is the current month when today's day is on or after the statement day, else
      the previous month
- [ ] 2.3 Build the cut date with the shared clamping helper so a statement day beyond the month's
      length lands on its last day. Dart's `DateTime` rolls over silently, so an unclamped port is
      wrong by construction (`design.md` — this is the V1 defect being fixed)
- [ ] 2.4 Add `payable(accountTotal)`: the negated total clamped at zero
- [ ] 2.5 Add `outstanding(entries, accountID, cut, now)`: negated sum over entries sourced from the
      card account itself, not transfers, negative, dated on or after the cut and not after now
- [ ] 2.6 Test the clamp matrix: statement days 28, 29, 30, 31 against February, a leap February, a
      30-day month and a 31-day month
- [ ] 2.7 Test the anchor month on both sides of the statement day
- [ ] 2.8 Test the outstanding filter matrix — a transfer, a positive amount, a pocket-sourced entry
      and an out-of-window entry must each be excluded
- [ ] 2.9 Test payable clamping at zero for a card in credit

## 3. Rows, expansion, navigation

- [ ] 3.1 Add the account row: expansion chevron with its own hit target and only when the account has
      pockets, name, and the amount display or the card two-column form
- [ ] 3.2 Tapping the row body opens the transactions screen titled with the account name, scoped to
      the account plus all its pocket ids
- [ ] 3.3 Add expansion, one account at a time, with an excluding-subpockets row scoped to the account
      alone and showing its own balance, plus one row per pocket scoped to that pocket
- [ ] 3.4 Golden test the account row, including the card variant
- [ ] 3.5 Test: expansion is single-open; each scoped navigation carries the right id set

## 4. Deletion

- [ ] 4.1 Add swipe-delete on account and pocket rows, archiving to the recycle bin
- [ ] 4.2 Confirmation names the holder and states how many entries keep its name — V1 computed this
      count and never displayed it (`design.md`, deliberate deviation)
- [ ] 4.3 Deleting an expanded account collapses it
- [ ] 4.4 Test: the confirmation's reference count; the collapse on delete

## 5. Account form

- [ ] 5.1 Add the creation sheet with an account/subpocket segmented choice, locked to account when no
      account can hold a pocket
- [ ] 5.2 Pocketable parents are active non-card accounts sorted by name — cards cannot hold pockets,
      guarded in both the picker and the controller
- [ ] 5.3 Account mode: name, type picker, statement day picker shown only for cards, optional opening
      balance
- [ ] 5.4 Subpocket mode: name and parent picker
- [ ] 5.5 `canSave`: trimmed name non-empty; a subpocket also needs a parent
- [ ] 5.6 Save an account via `addAccount`, persisting the statement day only for cards, then post the
      opening balance via `setOpeningBalance` when it is non-zero. Save a subpocket via `addPocket`
- [ ] 5.7 Errors surface in the form's error section
- [ ] 5.8 Test: the pocketable-parents filter; the locked-kind case; statement day persisted only for
      cards; no opening entry when the balance is zero

## 6. Source edit form

- [ ] 6.1 Add the edit sheet titled for an account or a subpocket, reached from the scoped
      transactions screen's action button
- [ ] 6.2 Name on both; type picker and card statement day on accounts only
- [ ] 6.3 Add the balance field allowing negatives, pre-filled with the current derived balance
- [ ] 6.4 On save, when the entered balance differs from the current one, post ONE adjustment entry
      for the difference with analysis excluded. Never rewrite stored entries — the entry log is the
      source of truth for every balance (`design.md`)
- [ ] 6.5 No difference means no entry. An empty balance field counts as zero
- [ ] 6.6 Add the treat-as-expense toggle on both, with its explanatory footer, and the net-worth
      toggle on accounts only
- [ ] 6.7 `canSave`: name non-empty and the balance parses
- [ ] 6.8 Save via `updateAccount` or `updatePocket`, then the adjustment, then dismiss
- [ ] 6.9 Test the balance-adjustment delta logic including the no-delta case, which must post nothing

## 7. Close-out

- [ ] 7.1 Run `cd app && flutter analyze && flutter test`. Analyzer at zero issues, not just zero errors
- [ ] 7.2 Confirm no `double` money reached `app/lib/`
- [ ] 7.3 Confirm no naive `DateTime(y, m, d)` construction for the statement cut:
      `grep -rn "DateTime(" app/lib/ui/accounts/`
- [ ] 7.4 Confirm the derivation functions carry no widget imports
