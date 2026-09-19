# Sync: run scheduler

Last reconciled: 0b47300

## Overview

`SyncRunScheduler` is a pure-Dart, callback-driven scheduling utility. It owns no I/O, backend,
persistence, coordinator, or status state beyond whether a pass is running. Callers supply the
pass through `runPass` and receive running-state transitions through `onStatusChanged`. It has no
production caller yet; a future integration will connect it to `SyncCoordinator` (#167). Source:
`app/lib/sync/sync_run_scheduler.dart` - `SyncRunScheduler`.

## Key locations

- `app/lib/sync/sync_run_scheduler.dart` - single-flight scheduling contract and callback boundary.
- `app/test/sync/sync_run_scheduler_test.dart` - coalescing, waiting, status, and failure coverage.

## Contracts and invariants

- At most one pass runs at once. While it runs, requests reserve at most one coalesced trailing
  pass; further `requestRun()` calls do nothing until that capacity changes. Source:
  `app/lib/sync/sync_run_scheduler.dart` - `SyncRunScheduler.requestRun`, `_drain`,
  `_chainTrailing`.
- `requestRun()` is fire-and-forget. It starts a pass while idle or ensures the one trailing slot
  while active. `runNow()` starts and waits for the active pass while idle; while active, it waits
  for the shared trailing pass rather than the currently active one. Source:
  `app/lib/sync/sync_run_scheduler.dart` - `SyncRunScheduler.requestRun`,
  `SyncRunScheduler.runNow`.
- `onStatusChanged(true)` begins a run sequence and `onStatusChanged(false)` occurs only after the
  scheduler settles idle. A chained trailing pass remains continuously running, with no idle
  transition between passes. Source: `app/lib/sync/sync_run_scheduler.dart` - `_launch`,
  `_drain`, `_settleIdle`, `_chainTrailing`.

## Gotchas

- A `runPass` failure completes every pending `runNow()` future with the same error and stack trace.
  If no `runNow()` caller is waiting, the drain loop rethrows after its bookkeeping settles, making
  the failure a zone-level unhandled asynchronous error rather than silently dropping it. Source:
  `app/lib/sync/sync_run_scheduler.dart` - `_drain`, `_failPending`;
  `app/test/sync/sync_run_scheduler_test.dart` - group `SyncRunScheduler failure`.
