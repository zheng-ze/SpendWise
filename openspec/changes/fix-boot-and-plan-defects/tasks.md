# Tasks

Found during a phase-boundary adversarial review of domain-accounting, ledger-runtime, drift-store
and app-shell-and-boot, before `add-transactions-ui` starts. 1 blocks that change's entry form (its
save and plan-edit paths reuse `updatePlan`); 2-4 are independent of any screen but sit in the boot
path every screen depends on.

- [x] 1 Fix `updatePlan` in `packages/domain/lib/src/ledger_state_plans.dart:12-18` to revalidate
      resolution state when `anchor` or `frequency` changes. `_validatePlan` (same file, lines 27-56)
      never compares the incoming plan's `anchor`/`frequency` against its own `lastResolvedDate`, and
      `OccurrenceID.make` (`packages/domain/lib/src/occurrence_id.dart`) keys only on
      `(planID, occurrenceDay)`, so shifting the anchor produces occurrence days the old cursor never
      saw and mints new entries alongside the ones already resolved under the old anchor. Reproduced:
      a monthly plan anchored 2026-01-15, resolved through 2026-03-20 (2 entries), then edited to
      anchor 2026-01-20 with `lastResolvedDate` rewound to 2026-01-15 and re-resolved, produces 5
      entries (3 duplicates) instead of 2. Add a test in `ledger_state_plans_test.dart` pinning this
      scenario post-fix. Severity: critical (duplicate real-money entries reachable through the public
      API once the entry form's edit path calls `updatePlan`)
      EDIT: a rewound `lastResolvedDate` cannot fix this — the old and new schedules land on
      disjoint calendar days, so no cursor value makes them overlap. Fixed by rejecting an
      anchor/frequency edit outright once the plan has resolved anything, via a new
      `StaleResolutionCursor` error (`ledger_error.dart:102`), not by accepting a rewind.
- [x] 2 Wire `AppBoot`'s `WidgetsBindingObserver` mixin to the actual platform lifecycle in
      `app/lib/boot/providers.dart` (or wherever `appBootProvider`'s consumer roots the widget tree) —
      `WidgetsBinding.instance.addObserver(boot)` is never called anywhere in `app/lib/`, confirmed by
      `rg -n "WidgetsBinding" app/lib app/test` returning only the mixin declaration at
      `app/lib/boot/app_boot.dart:16`. `didChangeAppLifecycleState` (lines 74-89) — flush-on-background
      and resolve-plans-on-resume — is consequently dead code in the running app; every test that
      exercises it (`app/test/boot/app_lifecycle_test.dart`,
      `app/test/boot/app_boot_retry_test.dart:122`) calls the method directly rather than through a
      registered observer, so the suite is green despite the gap. Add a widget-level test that drives
      the real `WidgetsBinding` lifecycle notification and asserts the observer fires. Severity:
      critical (pending writes are not flushed when the app backgrounds; a killed process loses them)
      EDIT: wired in `app/lib/boot/providers.dart:67-68` (`addObserver`/`removeObserver` around
      `appBootProvider`'s creation), matching the file's existing listener/dispose pattern. Proof test
      drives the real binding via `tester.binding.handleAppLifecycleStateChanged(...)`, not a direct
      method call. Landing it exposed that `providers_test.dart` read `appBootProvider` without an
      initialized `WidgetsBinding`, fixed with `TestWidgetsFlutterBinding.ensureInitialized()`.
- [x] 3 Fix the resource leak in `AppBoot.start()` (`app/lib/boot/app_boot.dart:45-70`): `_teardown()`
      (lines 94-104) only disposes `phase is Ready`, but `_bus`, `persistence` and `ledger` are created
      and partially wired (`persistence.start()` subscribes to the bus) before the phase is set to
      `Ready` at line 63. A throw between lines 56 and 66 on a retry leaves `persistence`'s
      `StreamSubscription` on `_bus` unreachable and undisposed, since `_teardown()`'s next run only
      finds `phase is Failed` and skips the block. Add a test that forces `Ledger`/`resolvePlans` to
      throw mid-`start()` and asserts no dangling subscription survives a retry. Severity: high
      EDIT: replaced the `phase is Ready` gate with `_persistence`/`_ledger` fields tracked
      independent of phase, so `_teardown()` finds and disposes them whenever a throw lands, including
      one after `Ready` is reached (the actual repro: `resolvePlans` throwing at the end of `start()`).
- [x] 4 Fix `AppBoot.dispose()` (`app/lib/boot/app_boot.dart:106-110`) firing `_teardown()` unawaited
      — `super.dispose()` runs before the flush/dispose chain completes, so a `ProviderContainer`
      teardown mid-flush drops the pending write with no error surfaced. Decide and document the
      intended contract (e.g. expose an async `disposeAndFlush()` for callers that can await, keeping
      sync `dispose()` best-effort) and add a test proving data survives a mid-flush disposal under the
      chosen contract. Severity: medium
      EDIT: added async `disposeAndFlush()` for callers that can await; sync `dispose()` stays
      best-effort since `ChangeNotifier.dispose()` can't await. A `_disposed` guard shared by both
      paths keeps Riverpod's own later `dispose()` call a no-op instead of a double-dispose crash.
- [x] 5 Add a validation guard rejecting `endDate` earlier than `anchor` in `_validatePlan`
      (`packages/domain/lib/src/ledger_state_plans.dart:27-56`) or in `RecurringPlan`'s own
      construction. Currently such a plan passes `addPlan` (its `lastResolvedDate.isBefore(endDate)`
      check is satisfied vacuously), produces zero occurrences from `occurrences()`
      (`packages/domain/lib/src/recurring_plan.dart:57-71`, since the ceiling is before the anchor),
      and is silently deleted as exhausted on the very next `resolvePlans` — dead on arrival with no
      signal to the caller. Add a test pinning the rejection. Severity: low, becomes a real footgun
      once `add-transactions-ui`'s plan editor lets a user pick both dates independently
