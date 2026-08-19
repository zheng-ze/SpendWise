## 1. Boot retry lockout (finding 1)

- [ ] 1.1 Write a test that fails the store/database connection once (fake an `openLedgerConnection`
  or `LazyDatabase` opener that throws on its first call and succeeds on its second), drives
  `AppBoot` to the failed phase, calls `retry()`, and asserts the app reaches `Ready` instead of
  `Failed` again. Run it against the unfixed code and confirm it goes red — today's `retry()` reuses
  the same cached, poisoned `storeProvider`, so the second attempt fails identically to the first.
- [ ] 1.2 Fix `AppBoot.retry()` (or `providers.dart`) to invalidate `storeProvider` and
  `databaseConnectionProvider` before re-reading them, so a retry opens a fresh connection instead of
  replaying the first attempt's cached failure. Watch 1.1 go green.

## 2. Boot error handling and messaging (findings 10, 11)

- [ ] 2.1 Write a test asserting that when `phase.persistence.flush()` throws during
  `AppBoot.dispose()` or during a backgrounding lifecycle event, the error is caught (e.g. surfaces
  through a logging hook or a test-visible callback) rather than becoming an unhandled async error
  that a test harness would report as a failure. Confirm red against the unfixed `unawaited(...)`
  calls at `app_boot.dart:95,137-143` (no zone/async-error handler currently catches it).
- [ ] 2.2 Add `.catchError` to both `unawaited()` calls in `app_boot.dart`, matching the pattern
  already used in `analysis_cache.dart:84-89`. Watch 2.1 go green.
- [ ] 2.3 Write a widget test for `boot_chrome.dart`'s failed-phase view asserting the displayed text
  is not the raw exception's `toString()` (drive a boot failure with a distinctive exception message
  like a fake `DriftException`, assert that exact string is NOT found in the rendered text, and a
  friendly fallback string IS found). Confirm red against `Text('$error', ...)`.
- [ ] 2.4 Replace the raw interpolation in `boot_chrome.dart` with a friendly fallback message,
  keeping the real error available for logging only. Watch 2.3 go green.

## 3. Account type round-trip (finding 3)

- [ ] 3.1 Write a test in the mappers test suite that round-trips an account of type
  `AccountType.loan` and one of type `AccountType.overdraft` through `accountToRow`/`accountFromRow`
  (or the full store save/load path) and asserts the type comes back unchanged. Confirm red — today
  both silently decode as `AccountType.other`.
- [ ] 3.2 Add explicit `8 => AccountType.loan` and `9 => AccountType.overdraft` cases to
  `_accountType` in `mappers.dart`. Watch 3.1 go green.
- [ ] 3.3 Note in the PR/commit description (not in code) that this does not repair any account
  already miscoded as `other` on an existing local database — new saves and loads are correct going
  forward only. No migration is in scope for this task group.

## 4. resolvePlans cursor on partial failure (finding 2)

- [ ] 4.1 Write a test: a recurring plan has two due occurrences: an earlier one whose source holder
  has since been archived (so it fails validation) and a later one that would succeed. Resolve the
  plan once, restore the holder, resolve again, and assert the earlier occurrence is now materialized
  rather than permanently skipped. Confirm red against the unfixed code — today's unconditional
  `plan.resolvedAt(now)` advances the cursor past the failed date on the first sweep, so the second
  sweep has nothing left to regenerate it from.
- [ ] 4.2 Fix `resolvePlans` in `ledger_state_plans.dart` so the new cursor stops at the earliest
  failed occurrence within the current `due` list, per design.md's "Plan cursor on partial failure"
  decision, instead of always advancing to `now`. Watch 4.1 go green.
- [ ] 4.3 Add a second test confirming the existing all-succeed case is unaffected: a plan with only
  successful due occurrences still advances its cursor all the way to `now` (not the last occurrence
  date), matching current behavior for the common case.

## 5. referenceOnly release-mode guard (finding 4)

- [ ] 5.1 Write a test that calls `updateAccount` (and separately `updateCategory`) with
  `lifecycle: LifecycleState.referenceOnly` on a row that has no referencing entries, and asserts it
  throws rather than succeeding. Run it once with `assert` disabled (or directly call the mutator in
  a context that bypasses the debug-only check) to confirm today's code only catches this under
  `assert`, i.e. it would silently succeed in a release build. Note in the test or its surrounding
  comment that no current UI code exercises this path — this closes an API hole, not an
  actively-triggered bug, so the test's job is to pin the illegal-states-unreachable guarantee
  before a future caller can exploit the gap.
- [ ] 5.2 Add a real throw to `updateAccount`, `updatePocket`, and `updateCategory` (or centrally in
  `_editableLifecycle`) when the incoming lifecycle is `referenceOnly` and the row is not already
  `referenceOnly` and would fail the same referencedness check `_isHolderReferenced`/
  `_isCategoryReferenced` already run for purge. Reuse those existing helpers rather than duplicating
  the check. design.md's open question is resolved: add a new sealed `LedgerError` subclass,
  `StillReferenced(id)`, rather than reusing `InactiveReference` — the two mean opposite things
  (creating a reference to an inactive row vs. retiring a row still referenced elsewhere) and a new
  `_case` string is a safe additive change, not the renaming the persistence comment warns against.
  Watch 5.1 go green.
- [ ] 5.3 Confirm the existing debug-only invariant test suite still passes unchanged — this task
  adds a release-reachable throw ahead of where the invariant already caught the same problem in
  debug, so no existing test should need to change, only the new one from 5.1 should newly pass.

## 6. Replay validation (finding 5)

- [ ] 6.1 Write a test that builds a change stream producing a state violating an existing invariant
  (e.g. an entry referencing a holder id that stream never upserts — this is a stand-in for the kind
  of gap a future schema-drift bug or partial migration could produce, not disk-level corruption,
  which SQLite's own journal already guards against) and asserts that replaying it raises a catchable
  error instead of returning the broken state. Confirm red against `LedgerStateReplay.apply`'s
  current bare loop.
- [ ] 6.2 Make `LedgerStateReplay.apply` (or its caller) call `assertInvariants()` directly after the
  loop completes, unconditionally rather than through the debug-only `assert(() {...}())` wrapper,
  and surface a real, catchable load error when it fails. Watch 6.1 go green.
- [ ] 6.3 Write a test confirming a well-formed change stream still loads normally and unmodified —
  guards against the validation call accidentally rejecting valid states.

## 7. Picker mounted guards (finding 6)

- [ ] 7.1 Write a test for at least one representative picker flow (e.g. `entry_form.dart`'s
  `_pickCategory`) that opens the form, triggers the picker, disposes the form's widget while the
  picker's future is still pending, then resolves the picker, and asserts no `setState`-after-dispose
  error occurs. Confirm red against the current unguarded `setState`.
- [ ] 7.2 Add `if (!mounted) return;` before the `setState` in all six affected methods:
  `entry_form.dart`'s `_pickSource`, `_pickDestination`, `_pickCategory`, `_pickRecurrence`,
  `_pickDate`, `_pickEndDate`; `account_form.dart`'s `_pickParent`; `category_form.dart`'s
  `_pickSymbol`, `_pickParent`; `plan_form.dart`'s `_pickRecurrence`, `_pickAnchor`, `_pickEndDate`.
  Watch 7.1 go green.

## 8. Friendly domain error messages (finding 8)

- [ ] 8.1 Write a test asserting that when `ErrorSection` (or the form save path that feeds it) is
  given a `LedgerError` such as `InactiveReference` or `CategoryKindMismatch`, the rendered text does
  not contain the error's raw `toString()` form (e.g. does not contain the literal substring
  `LedgerError.`) and does contain a plain-language message. Confirm red against today's direct
  string interpolation in `error_section.dart:20`.
- [ ] 8.2 Add a `friendlyLedgerErrorMessage(LedgerError error)` function near `error_section.dart`
  mapping each `LedgerError` subclass to a plain-language string, and have `ErrorSection` call it
  instead of interpolating the error directly. Watch 8.1 go green. This single function covers every
  call site listed in the proposal (`entry_form.dart`, `account_form.dart`, `source_edit_form.dart`,
  `category_form.dart`) since they all already route through `ErrorSection`.

## 9. Stats screen shared month state (finding 7)

- [ ] 9.1 Write a widget test that sets `selectedMonthProvider` from outside the Stats screen (e.g.
  via `container.read(selectedMonthProvider.notifier).state = ...`, matching the existing pattern in
  `app_shell_test.dart:147`) and asserts the Stats screen's displayed month reflects that change.
  Confirm red — today's `_StatsScreenBodyState._selectedDate` is independent local state.
- [ ] 9.2 Replace `_StatsScreenBodyState._selectedDate` with reads/writes through
  `selectedMonthProvider`, converting the relevant widget to consume Riverpod state for the date
  while leaving `_kind` and `_range` as local state (out of scope per design.md). Watch 9.1 go green.
- [ ] 9.3 Run the existing Stats screen test suite and confirm no regression — the month-stepping
  and period-selection behavior described in the `stats-screen` spec's "Kind and period selection"
  requirement must be unchanged, only its state source moves.

## 10. Spec-only corrections, no code change (findings 12, 13, 14)

- [ ] 10.1 Confirm the `ledger-mutations` delta spec's new "system-entry-locked" scenario in this
  change matches the actual guard at `ledger_state_entries.dart:16-21` (already the case — this task
  is a verification step before archive, not new work, since finding 12 is a documentation gap only).
- [ ] 10.2 Confirm the `accessibility-and-localization` delta spec's rewritten "Localization
  scaffolding" requirement matches the decision already recorded in
  `openspec/changes/add-parity-gaps-and-platform-pass/tasks.md` and `docs/NAVIGATION.md` (already the
  case — verification step only).
- [ ] 10.3 Confirm the `ledger-analysis` delta spec's rewritten "Roll-up to main buckets" requirement
  matches `Accounting.mainBucketID` at `accounting.dart:253-264` and the existing test at
  `accounting_analysis_test.dart:644-655` (already the case — verification step only).

## 11. Final gate

- [ ] 11.1 Run `cd packages/domain && dart format . && dart analyze && dart test` — zero analyzer
  issues, all tests green.
- [ ] 11.2 Run `cd app && flutter analyze` — zero issues.
- [ ] 11.3 Run the full `app` test suite and confirm no regressions beyond the new tests added above.
