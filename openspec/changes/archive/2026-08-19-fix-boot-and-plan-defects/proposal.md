# Fix defects found in the phase 2-5 adversarial review

## Why

An adversarial pass across domain-accounting, ledger-runtime, drift-store and app-shell-and-boot,
run before starting `add-transactions-ui`, found five confirmed defects. Two are critical: editing a
recurring plan's anchor can mint duplicate entries on the next resolve, and `AppBoot` never registers
its `WidgetsBindingObserver`, so background flush and resume-driven plan resolution are dead code in
the running app.

These sit in the boot path and the plan mutator every later screen depends on, `add-transactions-ui`
included, so they are fixed here rather than folded into that change's own tasks.

## What Changes

- Fix `updatePlan` to revalidate resolution state when `anchor` or `frequency` changes, closing the
  duplicate-entry path.
- Register `AppBoot` as a `WidgetsBindingObserver` so background flush and resume-driven plan
  resolution actually run.
- Fix `AppBoot._teardown` to dispose a partially wired boot (bus subscription) on a failed retry, not
  only a `Ready` one.
- Decide and document `AppBoot.dispose()`'s contract for a flush in flight at teardown.
- Add a validation guard rejecting an `endDate` before `anchor` on a recurring plan.

Not **BREAKING**: bug fixes to existing behavior, no new capability and no contract change beyond
tightening validation that was already supposed to hold.

## Capabilities

No new capabilities. Touches the existing `ledger-plans` and boot/runtime behavior delivered in
`add-ledger-runtime`.
