## 1. Boot retry lockout (finding 1)

- [x] 1.1 Wrote `retryAfterAFailedConnectionReachesReadyInsteadOfFailingAgain` in
  `app/test/boot/app_boot_retry_provider_test.dart` — overrides `databaseConnectionProvider` with a
  fake opener that throws on its first call and opens an in-memory Drift database on its second,
  drives `appBootProvider` to `Failed`, calls `retry()`, asserts `Ready`. Confirmed red against
  unfixed code: `Expected: Ready, Actual: Failed` (second attempt replayed the same cached error via
  `LazyDatabase`).
- [x] 1.2 Fixed by adding `AppBoot.onRetry` (`app/lib/boot/app_boot.dart:52-54,88-91`, called from
  `retry()` before `start()`) and wiring it in `appBootProvider`
  (`app/lib/boot/providers.dart:58-64`) to `ref.invalidate(storeProvider)` and
  `ref.invalidate(databaseConnectionProvider)`. Also guarded the `LedgerDatabase.close()` dispose hook
  in `storeProvider` (`app/lib/boot/providers.dart:33`) with `.catchError((_) {})`, since disposing
  the old poisoned `LazyDatabase` after invalidation rethrows the original open error from `close()`
  and that would otherwise surface as an unhandled async error (the failure itself was already
  surfaced through the `Failed` phase). 1.1 goes green; full `flutter test test/boot/` (82 tests) and
  `flutter analyze` (0 issues) both pass.

## 2. Boot error handling and messaging (findings 10, 11)

- [x] 2.1 Wrote `aFlushErrorDuringBackgroundingIsCaughtNotUnhandled` in
  `app/test/boot/app_lifecycle_test.dart` (backgrounding path, `didChangeAppLifecycleState(paused)`
  with a `RecordingLedgerStore..failOn = StoreCall.flushNow`) and
  `aFlushErrorDuringSynchronousDisposeIsCaughtNotUnhandled` in
  `app/test/boot/app_boot_dispose_test.dart` (dispose path, a `_FailingFlushStore` whose `flushNow`
  always throws). Both wrap the triggering call in `runZonedGuarded` and assert the zone's error
  list stays empty — a real unhandled async error from `unawaited(...)` surfaces there, not as a
  thrown exception from the call itself. Note: task group 1 already relocated the code, so the
  actual unguarded calls were `app_boot.dart:104` (`unawaited(phase.persistence.flush())`, the
  backgrounding case) and `app_boot.dart:150` (`unawaited(_teardown())`, the dispose case; `_teardown`
  calls `persistence.flush()` internally) — not the `95,137-143` cited in the original task text.
  Confirmed both red: the zone handler caught `StateError` (`store failed` / `flush failed`) that
  the old code let escape unhandled.
- [x] 2.2 Added `.catchError((Object error, StackTrace stackTrace) { debugPrint(...); })` to both
  `unawaited()` calls in `app_boot.dart`: the backgrounding flush at `app_boot.dart:104-110` and the
  dispose teardown at `app_boot.dart:156-160` (wrapping `_teardown()`, which covers the flush inside
  it). Same shape as `analysis_cache.dart`'s `.onError` pattern, with parameter types spelled out
  explicitly since `Future<void>.catchError` (unlike `Future<T>.onError`) doesn't infer them from
  context — `flutter analyze` flagged `inference_failure_on_untyped_parameter` without the types.
  Watched 2.1 go green.
- [x] 2.3 Added `failure does not leak the raw exception text to the user` in
  `app/test/ui/shell/boot_chrome_test.dart` — drives boot to fail with
  `Exception('DriftException: disk image is malformed')`, asserts that exact string is
  `findsNothing` and a friendly fallback string is `findsOneWidget`. Also renamed and trimmed the
  pre-existing `failure shows the headline, the cause and retry` test (it asserted
  `find.textContaining('disk on fire')`, which directly encoded the bug) to drop that assertion.
  Confirmed the new test red against `Text('$error', ...)`.
- [x] 2.4 Replaced the raw interpolation in `boot_chrome.dart:66-75` with the fixed string
  `'Something went wrong loading your data. Please try again.'`. Added a `debugPrint('AppBoot failed
  to load: $error')` at the top of `_LoadFailure.build` (`boot_chrome.dart:53-55`) so the real error
  stays available for logging — otherwise the `error` field would have gone unused once the widget
  stopped rendering it. Watched 2.3 go green.

## 3. Account type round-trip (finding 3)

- [x] 3.1 Wrote `a loan account type survives the round trip` and `an overdraft account type
  survives the round trip` in `app/test/persistence/mappers_test.dart` (account group, right after
  the null-statement-day test), round-tripping through `accountToRow`/`accountFromRow`. Note: the
  actual file is `app/lib/persistence/mappers.dart` (Flutter app), not `packages/domain` — the task
  brief's location was off, code confirmed via `rg`. Both went red against unfixed code: expected
  `AccountType.loan`/`AccountType.overdraft`, got `AccountType.other`.
- [x] 3.2 Added `8 => AccountType.loan` and `9 => AccountType.overdraft` cases to `_accountType` in
  `app/lib/persistence/mappers.dart:13-24`, ahead of the existing default fallback. Both new tests go
  green; full `mappers_test.dart` suite (50 tests) passes, including the existing "an unknown account
  type falls back to other" (code 99) test, confirming the fallback still covers genuinely unknown
  codes.
- [x] 3.3 PR/commit note: this fix does not repair any account already miscoded as `other` on an
  existing local database — new saves and loads are correct going forward only. No migration is in
  scope for this task group (see design.md's Risks section, "Existing corrupted accounts").

## 4. resolvePlans cursor on partial failure (finding 2)

- [x] 4.1 Wrote `test/ledger_state_plans_test.dart:421` "a failed occurrence is regenerated once the
  holder is restored instead of being permanently skipped" — archives the plan's source pocket,
  resolves once (both due occurrences fail), restores the pocket, resolves again, asserts both
  occurrences (including the earlier one) are now materialized. Confirmed red against the unfixed
  code: the second sweep found no entries, since the first sweep's unconditional
  `plan.resolvedAt(now)` had already advanced the cursor past both failed dates.
- [x] 4.2 Fixed `resolvePlans` in `packages/domain/lib/src/ledger_state_plans.dart:73-126` — tracks a
  `cursor` that only advances past occurrences that materialized or were already present, and a
  `sawFailure` flag; the final `plan.resolvedAt(...)` call uses `now` when nothing failed (unchanged
  common case) or the stalled `cursor` (the point just before the first failure) when something did,
  per design.md's "Plan cursor on partial failure" decision and the `ledger-plans` spec's "stop at
  the earliest failed occurrence" / "advances to just before the first failure" wording. Watched 4.1
  go green.
- [x] 4.3 Added `test/ledger_state_plans_test.dart:445` "a plan with only successful occurrences
  advances its cursor all the way to now, not just to the last occurrence date" — resolves a healthy
  plan, asserts `lastResolvedDate` lands on `now` rather than the last due date, then sweeps again and
  asserts nothing changes. Passes both before and after the fix (proves the common case is
  unaffected, not a red/green pair).

## 5. referenceOnly release-mode guard (finding 4)

- [x] 5.1 Wrote 4 tests in `ledger_state_invariants_test.dart`'s "clause 12, lifecycle monotonicity"
  group proving edit cannot move an active row's lifecycle in any direction, not just to
  `referenceOnly`: "an edit cannot move an active, unreferenced account to referenceOnly", "...an
  active pocket to referenceOnly", "...an active category to referenceOnly", "an edit cannot archive
  an active account". Confirmed all 4 red against the pre-fix `_editableLifecycle` by temporarily
  restoring its old two-argument logic and rerunning — the debug-only `assert` (invariant 11) is
  what caught the first three, exactly matching the original finding's "only asserts, doesn't throw
  in release" description; the fourth (archive-via-edit) had no invariant guarding it at all and
  just silently succeeded, confirming it was a real, unguarded gap.
- [x] 5.2 The fix landed wider than a guarded throw: `_editableLifecycle` in `ledger_state.dart` now
  always returns the stored lifecycle (`LifecycleState _editableLifecycle(LifecycleState stored) =>
  stored`), so edit can never move lifecycle in any direction. `delete`/`purge`/`restore` already own
  every legal transition with their own preconditions; edit accepting lifecycle as input duplicated
  that authority and, for the `referenceOnly` direction specifically, duplicated it without a guard.
  No new `LedgerError` case was needed — design.md's Open Questions is updated to record why.
  Updated the 3 call sites (`ledger_state_holders.dart` x2, `ledger_state_categories.dart` x1).
- [x] 5.3 Full suite green (541 tests), `dart analyze` and `flutter analyze` both zero issues. 5
  pre-existing tests that exercised archive-via-edit as a real feature (not just the referenceOnly
  leak) failed once lifecycle was frozen — see design.md's Decisions section for the full breakdown
  of which were deleted (4, testing a capability now intentionally removed) versus rewritten (1,
  `does not exempt a holder...` swapped its `updateAccount(lifecycle: archived)` setup for
  `deleteAccount`) versus deleted outright because the scenario became unreachable through the public
  API (`does not exempt a holder the stored plan already references` — needed an archived holder with
  an intact referencing plan, a state `deleteAccount`'s own cascade never produces).

## 6. Replay validation (finding 5)

- [x] 6.1 Wrote `replaying a stream that never upserted a referenced holder throws` in
  `packages/domain/test/ledger_state_replay_test.dart:61-73` (entry names a holder id the stream
  never upserts). Confirmed red against the unfixed bare loop — replay returned the broken state
  with no error.
- [x] 6.2 Fixed in `packages/domain/lib/src/ledger_state.dart:38-47`: the `LedgerState.replaying`
  constructor now calls `assertInvariants()` directly (unconditional `StateError`, not the
  debug-only `_checked`/`assert(() {...}())` wrapper) right after `apply(changes)` completes. Left
  the check in the constructor rather than inside `LedgerStateReplay.apply` itself, since `apply` is
  also called mid-stream on an already-valid state (see the "replaying that same deletion leaves the
  parent link in place" test at `ledger_state_replay_test.dart:50-59`, which applies a single delete
  that is intentionally not yet invariant-clean). Watch 6.1 go green.
- [x] 6.3 Wrote `a well-formed stream still loads normally through replaying` in
  `ledger_state_replay_test.dart:75-83`, green from the start.
- [x] Known lifecycle-monotonicity risk (invariant/clause 12 in `ledger_state_invariants.dart`) did
  not manifest: `assertInvariants()` never calls `_assertLifecycleMonotonic` (that stays gated inside
  `_assertChecked`, and replay has no prior snapshot to compare against regardless), so no existing
  test broke on that clause. One existing test did rely on the exact bug this task fixes:
  `barrel_exports_test.dart`'s "replay is nameable through the barrel alone" built a replay stream
  with an `UpsertEntry` naming an account id the stream never upserted (invariant 4, dangling entry
  reference) — its point was barrel-export nameability, not dangling-reference behavior, so it was
  fixed (not deleted) by adding the missing `UpsertAccount` for that id;
  `barrel_exports_test.dart:36-46`. Full domain suite green (545 tests) after the fix.

## 7. Picker mounted guards (finding 6, 11 call sites)

- [x] 7.1 Wrote `resolving the category picker after the form is popped does not throw` in
  `app/test/ui/transactions/entry_form_test.dart` (picker mounted guard group) — pushes `EntryForm`
  via a captured `MaterialPageRoute`, opens the category picker sheet (which lands on the same root
  navigator as the form, above it, since `showModalBottomSheet` defaults to `useRootNavigator: true`),
  removes the form's route directly with `NavigatorState.removeRoute` while the sheet stays open and
  the picker future is still pending, then taps an option to resolve it. Confirmed red against
  unguarded code: `setState() called after dispose(): _EntryFormState... defunct, not mounted`,
  thrown from `_applyPickerOutcome` (`entry_form.dart:151`) via `_pickCategory`.
- [x] 7.2 Added `if (!mounted) return;` before the `setState` in all eleven affected methods (10 guard
  additions — `entry_form.dart`'s three picker-outcome methods share one `setState` inside
  `_applyPickerOutcome`, guarded once):
  - `app/lib/ui/transactions/entry_form.dart:151` — `_applyPickerOutcome`, covers `_pickSource`,
    `_pickDestination`, `_pickCategory`
  - `app/lib/ui/transactions/entry_form.dart:200` — `_pickRecurrence`
  - `app/lib/ui/transactions/entry_form.dart:231` — `_pickDate`
  - `app/lib/ui/transactions/entry_form.dart:246` — `_pickEndDate`
  - `app/lib/ui/accounts/account_form.dart:94` — `_pickParent`
  - `app/lib/ui/settings/category_form.dart:136` — `_pickSymbol` (folded into the existing
    `if (chosen != null)` condition rather than a separate early return)
  - `app/lib/ui/settings/category_form.dart:160` — `_pickParent`
  - `app/lib/ui/settings/plan_form.dart:81` — `_pickRecurrence`
  - `app/lib/ui/settings/plan_form.dart:93` — `_pickAnchor`
  - `app/lib/ui/settings/plan_form.dart:107` — `_pickEndDate`

  Watched 7.1 go green. `flutter analyze` zero issues; full `flutter test` 667/669 green (the 2
  failures are the pre-existing `stats_donut_test.dart` golden pixel-diffs from task group 9, a file
  this task group never touches).

## 8. Friendly domain error messages (finding 8)

- [x] 8.1 Write a test asserting that when `ErrorSection` (or the form save path that feeds it) is
  given a `LedgerError` such as `InactiveReference` or `CategoryKindMismatch`, the rendered text does
  not contain the error's raw `toString()` form (e.g. does not contain the literal substring
  `LedgerError.`) and does contain a plain-language message. Confirm red against today's direct
  string interpolation in `error_section.dart:20`.
  Test `error_section_test.dart` (`app/test/ui/common/error_section_test.dart:15` and `:27`), one
  case each for `InactiveReference` and `CategoryKindMismatch`. Confirmed red: since `ErrorSection`
  only accepted a `String?`, passing a `LedgerError` was a compile error, which is as red as it gets.
- [x] 8.2 Add a `friendlyLedgerErrorMessage(LedgerError error)` function near `error_section.dart`
  mapping each `LedgerError` subclass to a plain-language string, and have `ErrorSection` call it
  instead of interpolating the error directly. Watch 8.1 go green. This single function covers every
  call site listed in the proposal (`entry_form.dart`, `account_form.dart`, `source_edit_form.dart`,
  `category_form.dart`) since they all already route through `ErrorSection`.
  Fix at `app/lib/ui/common/error_section.dart:33` (function), `:19` (call site). `ErrorSection.error`
  changed from `String?` to `LedgerError?` so the widget can map it itself instead of receiving an
  already-stringified message. The 4 forms' `ErrorSection(subject: ..., error: _error)` call sites
  are unchanged; each form only had its `_error` field retyped from `String?` to `LedgerError?` and
  its catch block changed from `_error = error.toString()` to `_error = error` (same one-line shape
  in all 5 forms, including `plan_form.dart` which also routes through `ErrorSection` but wasn't
  named in the proposal's call-site list). Also had to fix `shared_components_test.dart`'s two
  `ErrorSection` tests (`app/test/ui/common/shared_components_test.dart:161`, `:176`), which predated
  this change and exercised the widget with a raw string rather than a `LedgerError`; they now pass a
  real `LedgerError` and assert against `friendlyLedgerErrorMessage`'s output. 8.1 confirmed green,
  `flutter analyze` zero issues (switch exhaustiveness checked), full relevant test run passes (49
  tests across `error_section_test.dart`, `shared_components_test.dart`, `entry_form_test.dart`,
  `account_form_test.dart`, `source_edit_form_test.dart`, `category_form_logic_test.dart`).

## 9. Stats screen shared month state (finding 7)

- [x] 9.1 Wrote `reflects a month set on selectedMonthProvider from outside the screen` in
  `test/ui/stats/stats_screen_test.dart:75-103`, mounting `StatsScreen` under an external
  `ProviderContainer`/`UncontrolledProviderScope` (matching `app_shell_test.dart:147`'s pattern) and
  writing `selectedMonthProvider` from outside the widget tree. Confirmed red against the unfixed
  code — `_StatsScreenBodyState._selectedDate` was independent local state, so the label still showed
  the current month instead of "Mar 2019".
- [x] 9.2 Fixed in `lib/ui/stats/stats_screen.dart`: `_StatsScreenBody` is now a
  `ConsumerStatefulWidget`/`ConsumerState` (was `StatefulWidget`/`State`); the `_selectedDate` field is
  gone and `build` reads `ref.watch(selectedMonthProvider)` (line 84), the `MonthYearSelector.onChanged`
  callback writes `ref.read(selectedMonthProvider.notifier).state = value` (line 111-115), and
  `_onTapCategory` reads `ref.read(selectedMonthProvider)` (line 74) for the detail screen's initial
  date. `_kind` and `_range` stay untouched local `State` fields, out of scope per design.md. Grepped
  the whole app package for `_StatsScreenBodyState` before converting: the only matches are the file's
  own `class`/`createState` declarations — no test or other file type-checks against the private State
  class, so the conversion was safe. Watched 9.1 go green.
- [x] 9.3 Ran `test/ui/stats/stats_screen_test.dart` (5/5 green) and the full `test/ui/stats/`
  directory (31/33 green — the 2 failures are pre-existing `stats_donut_test.dart` golden pixel-diffs
  in a file this change never touches, confirmed via `git status` showing no local modification to
  `stats_donut.dart` or its goldens). Month-stepping (prev/next chevrons via `MonthYearSelector`) and
  period selection (`Monthly`/`Annually` popup menu, `_range`) are unchanged — same widgets, same
  callbacks, only the month's state source moved.

## 10. Spec-only corrections, no code change (findings 12, 13, 14)

- [x] 10.1 Confirmed. `ledger_state_entries.dart:16-21`'s guard matches the spec exactly: locks
  name/categoryID/includeInAnalysis on a system-kind entry, throws `SystemEntryLocked`, leaves
  amount/date/holders editable.
- [x] 10.2 Confirmed. `docs/NAVIGATION.md:47-48` records the same decision the spec states:
  localization is skipped for this personal-use, single-language app, revisit if that changes.
- [x] 10.3 Confirmed. `Accounting.mainBucketID` (`accounting.dart:253-264`) matches the spec: no
  category row keeps the id as its own bucket (covers synthetic ids), a real category rolls up to
  its parent or itself. `accounting_analysis_test.dart:644-655` proves the synthetic-bucket case.

## 11. Final gate

- [x] 11.1 `cd packages/domain && dart format . && dart analyze && dart test` — 0 files changed, 0
  analyzer issues, 545 tests passed.
- [x] 11.2 `cd app && flutter analyze` — 0 issues.
- [x] 11.3 Full `app` test suite: 667/669 passed. The 2 failures are `stats_donut_test.dart`'s golden
  pixel-diff tests, pre-existing and unrelated to any of the 13 findings in this change (the file is
  untouched by this change, confirmed via `git log`/`git status`) — every task group that ran the
  full suite independently observed and flagged the same 2 failures. No regressions beyond that.
