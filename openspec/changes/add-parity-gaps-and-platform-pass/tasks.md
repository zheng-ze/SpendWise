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

- [ ] 1.1 Append `loan` and `overdraft` to `AccountType` with new explicit codes. APPEND ONLY —
      inserting a case silently changes what every stored code above it means (`design.md`)
- [ ] 1.2 Add `allowsTransfersAsExpense` gating eligibility: blocked for cash, checking, card and
      prepaid
- [ ] 1.3 Force `incomingTransfersAsExpenses` false on save for an ineligible type — do not merely
      hide the control, or a stale true flag survives a type change
- [ ] 1.4 Test: data written with the old codes still loads with the same types — this is the test
      that catches an inserted case
- [ ] 1.5 Test: set the flag, change to an ineligible type, save, confirm the flag is false
- [ ] 1.6 Update the holder form to show the toggle only for eligible types

## 2. Synthetic buckets

- [ ] 2.1 Add deterministic synthetic bucket ids derived per account type — derived, never stored, so
      there is no migration and every device agrees
- [ ] 2.2 Change `classify` so a treat-as-expense transfer buckets by the destination account's type
      instead of carrying no category
- [ ] 2.3 A pocket destination resolves to its parent account's type
- [ ] 2.4 These buckets are expense-only — a transfer never produces an income item through this path
- [ ] 2.5 Test: two accounts of one type share a bucket; a pocket destination buckets by its parent;
      no synthetic bucket appears in income analysis
- [ ] 2.6 Update the existing accounting and analysis tests whose expectations change, one visible
      edit at a time

## 3. Synthetic slice presentation

- [ ] 3.1 Slices for synthetic buckets carry their own name and symbol rather than a category's, and
      render in a neutral color
- [ ] 3.2 They are NOT navigable — there is no category row behind them to open
- [ ] 3.3 Test: tapping a synthetic slice pushes nothing

## 4. Totals ruling

- [ ] 4.1 Make the transactions-versus-stats totals ruling with both screens in front of you: either
      route both through the same analysis gates, or record the divergence as intentional. Earlier
      phases kept the call site singular so this is a one-line change (`design.md`)
- [ ] 4.2 Record the ruling inline in `docs/Flutter_Port_Tech_Doc.md` §5, which reserves a spot for it
- [ ] 4.3 Apply it at the single call site
- [ ] 4.4 If the divergence is kept, state it where a user can see it rather than leaving it to be
      discovered
- [ ] 4.5 Test: the same month reported by both screens matches the ruling

## 5. Scope-aware transfer display

- [ ] 5.1 Add scope-aware transfer sign and color: leaving the scope reads as a loss, entering it as a
      gain, both endpoints inside or an unscoped list stays neutral
- [ ] 5.2 Account scope is the account plus its active pockets; pocket scope is that pocket alone
- [ ] 5.3 Test the three-way matrix — out, in, both — at account scope and at pocket scope
- [ ] 5.4 Test: an account-to-own-pocket transfer is neutral at account scope and a gain at pocket
      scope

## 6. Accessibility

- [ ] 6.1 Add semantics to every custom widget
- [ ] 6.2 Give the donut a text alternative conveying each bucket, its amount and its share. V1 hid it
      from assistive technology with no fallback, so the screen conveyed nothing
- [ ] 6.3 Add labels or custom actions for the expanding action button, the two-column picker and every
      swipe action — all are gesture-only affordances today
- [ ] 6.4 Test: the donut exposes its text alternative; swipe actions appear as custom actions

## 7. Localization

- [ ] 7.1 Add `flutter_localizations` and the localization scaffolding
- [ ] 7.2 Declare user-facing strings through it rather than inline
- [ ] 7.3 Route every shared format from the UI foundation through the localization layer
- [ ] 7.4 Do NOT rewrite stored entry names — "Opening balance" and "Balance adjustment" are data. The
      structural marker reserved at schema day one is what lets display-time naming take over later
- [ ] 7.5 Test: an entry stored with an English name keeps it

## 8. Layout polish and close-out

- [ ] 8.1 Polish the adaptive rail layout on wide windows
- [ ] 8.2 Run `cd packages/domain && dart analyze && dart test` and `cd app && flutter analyze &&
      flutter test`. Analyzer at zero issues, not just zero errors
- [ ] 8.3 Review every test expectation this change altered and confirm each was edited deliberately
- [ ] 8.4 Confirm no stored enum code changed meaning: load a fixture written before group 1
