# Sync: repair gate

Last reconciled: 38bf33c

## Overview

`SyncRepairGate` is the process-lifetime, per-`LedgerDatabase` concurrency gate for sync
repair. One instance exists per database via the `Expando`-cached
`SyncRepairGate.forDatabase(database)` singleton. It admits bound sync RPCs only while open
and bound at an allowed phase, serializes every state-mutating operation through one
internal `Future`-chain queue (`withMutation`), scopes repair-exit releases to the repair
episode that latched them, and carries a `BoundRpcLease` to each durable-write call site so
a late RPC success arriving after the gate closes cannot commit sync-metadata state. It
also provides the shared `withSecretMutationLock` used by both the coordinator and the
enrollment service for every device-secret mutation. Source:
`app/lib/sync/sync_repair_gate.dart` - `SyncRepairGate`, `BoundRpcLease`,
`BoundRpcAdmission`, `GateMutation`.

## Key locations

- `app/lib/sync/sync_repair_gate.dart` - gate, lease, admission, and mutation-turn types.
- `app/lib/sync/sync_coordinator.dart` - `_sendBoundRpc`, `_latchForBindingRepair`,
  `_latchForSessionRepair`, lease-guarded durable commits.
- `app/lib/sync/sync_enrollment_service.dart` - `_commitRepairExit`, `_enterBindingRepair`,
  `_enterSessionRepair`, secret mutations under `withSecretMutationLock`.
- `app/lib/sync/sync_enrollment_composition.dart` - passes the shared
  `SyncRepairGate.forDatabase(database)` into the enrollment service.
- `packages/sync/lib/src/protocol/credential.dart` - `BoundDeviceCredential.hasSameBearerAs`,
  `BoundDeviceCredential.hasSameDeviceSecretAs`.
- `app/test/sync/sync_repair_gate_test.dart` - gate admission, lease, episode, and
  serialization contracts.

## Interactions

`SyncCoordinator.create` builds `SyncRepairGate.forDatabase(database)` and reseeds it once
from the startup snapshot; reseeding is first-write-wins and latches the gate unless the
snapshot is bound at an allowed phase. The hosted-enrollment factory passes the same
per-database instance into `SyncEnrollmentService`, so coordinator and enrollment serialize
through one lock. Source: `app/lib/sync/sync_coordinator.dart` -
`SyncCoordinator.create`; `app/lib/sync/sync_repair_gate.dart` -
`SyncRepairGate.reseed`; `app/lib/sync/sync_enrollment_composition.dart` -
`composeSyncEnrollment`.

The coordinator's pull, acknowledgement, and push paths all go through `_sendBoundRpc`,
which admits via the gate, checks `validateHostedOperationState` legality separately from
admission, resolves the credential with `withBoundCredentialAndSecret`, re-checks
`isCurrent` before and after the backend call, and returns the outcome with its lease.
Durable commits (`recordPulledPage`, `clearPendingAcknowledgementIfMatches`,
`setAcknowledgedVector`) run inside `withCurrentLease`, so a success whose lease was
superseded throws instead of writing. Source: `app/lib/sync/sync_coordinator.dart` -
`SyncCoordinator._sendBoundRpc`, `_finalizeAndMaybeAcknowledge`,
`_recoverOneAcknowledgement`, `_pushCollectionLocked`;
`app/lib/sync/credential_provider.dart` -
`CredentialProvider.withBoundCredentialAndSecret`.

`CredentialUnavailableException` (except storage/identity failures, which rethrow) and
typed backend failures (`CredentialExpired`, `DeviceAuthorizationRequired`) route through
secret-first classification into latch flows that re-read current state inside
`withMutation` before latching: credential-expiry latching requires the stored credential
to still carry the presented bearer (`hasSameBearerAs`); device-authorization latching
requires the stored device secret to still equal the presented one
(`hasSameDeviceSecretAs` in enrollment, stored-secret equality in the coordinator). A
superseded failure therefore latches nothing and reports a superseded-credential error.
Source: `app/lib/sync/sync_coordinator.dart` -
`SyncCoordinator._routeCoordinatorCredentialUnavailable`,
`_routeCoordinatorCredentialExpired`, `_routeCoordinatorDeviceAuthorizationRequired`;
`app/lib/sync/sync_enrollment_service.dart` - `_routeCredentialUnavailable`,
`_routeBoundFailure`, `_enterSessionReauthOrThrow`.

The enrollment service captures its repair episode once per `enroll()` via
`repairGate.repairEpisode()` and exits repair only through `_commitRepairExit`, which
runs the metadata transition and the episode-scoped `release` atomically inside
`withMutation` and throws `StateError` when a different repair has since latched. Its
binding-flow decision logic (OTP sequencing, phase advancement conditions) is unchanged;
only the concurrency plumbing changed. Source:
`app/lib/sync/sync_enrollment_service.dart` - `SyncEnrollmentService.enroll`,
`_commitRepairExit`, `_stepBindingAuthorizationRequired`, `_stepSessionReauthRequired`.

## Contracts and invariants

- Admission grants a `BoundRpcLease` only when the gate is open and the freshly read
  snapshot is bound at `snapshotInProgress`, `reconciliationComplete`, or `gateEnabled`.
  A latched gate yields no lease; an unbound or disallowed-phase snapshot latches the gate
  and yields no lease. Source: `app/lib/sync/sync_repair_gate.dart` -
  `SyncRepairGate.admit`, `_isBoundAtAllowedPhase`.
- `release(generation)` is scoped to the repair episode that latched the gate: it opens
  the gate only when latched and the generation matches, and is otherwise a no-op. Both
  latch and release bump the generation counter. Source:
  `app/lib/sync/sync_repair_gate.dart` - `SyncRepairGate._latch`,
  `SyncRepairGate._release`.
- `isCurrent(lease)` is true only while open with a matching generation; every lease
  check and every `withCurrentLease` commit runs serialized inside `withMutation`, so a
  repair that lands between an RPC response and its durable commit invalidates the lease
  before the commit runs. Source: `app/lib/sync/sync_repair_gate.dart` -
  `SyncRepairGate.isCurrent`, `SyncRepairGate.withCurrentLease`.
- `GateMutation` turns are single-use: `latch`, `isCurrentEpisode`, and `release` throw
  `StateError` once the turn ends. Source: `app/lib/sync/sync_repair_gate.dart` -
  `GateMutation`.
- Latching is idempotent with respect to the target repair state: binding-repair latches
  only when not already at bound-repair metadata or when the gate is open, and
  session-repair latches only when not already in session reauth (or when the gate is
  open), never overwriting a pending binding repair with a session repair. Source:
  `app/lib/sync/sync_coordinator.dart` - `_latchForBindingRepair`,
  `_latchForSessionRepair`; `app/lib/sync/sync_enrollment_service.dart` -
  `_enterBindingRepair`, `_enterSessionRepair`.
- `hasSameBearerAs` compares only device ID plus bearer token, so a stale 401 is
  detected without false-positiving on an unrelated secret rotation;
  `hasSameDeviceSecretAs` compares device ID plus device secret. Source:
  `packages/sync/lib/src/protocol/credential.dart` - `BoundDeviceCredential`.

## Entry points and flows

- `SyncRepairGate.forDatabase(database)` returns the per-database shared instance.
  `reseed(snapshot)` initializes it once at coordinator creation. Source:
  `app/lib/sync/sync_repair_gate.dart` - `SyncRepairGate.forDatabase`,
  `SyncRepairGate.reseed`.
- `admit(readSnapshot)` reads one snapshot inside the mutation turn and returns the
  snapshot with an optional lease. `repairEpisode()` returns the current generation for
  episode-scoped exits. Source: `app/lib/sync/sync_repair_gate.dart` -
  `SyncRepairGate.admit`, `SyncRepairGate.repairEpisode`.
- `withMutation(work)` serializes state-mutating turns on one `Future` chain.
  `withSecretMutationLock(work)` runs device-secret reads, writes, and deletes through
  that same chain; both the coordinator and the enrollment service route every
  `syncCredentialSecretKey`/`syncDeviceSecretKey` mutation through it. Source:
  `app/lib/sync/sync_repair_gate.dart` - `SyncRepairGate.withMutation`,
  `SyncRepairGate.withSecretMutationLock`.

## Gotchas

- Admission and metadata legality are two separate checks: `admit` enforces the
  bound-at-allowed-phase rule, while `_sendBoundRpc` additionally rejects snapshots that
  `validateHostedOperationState` deems illegal. Do not assume an admitted snapshot is
  legal, or a legal snapshot is admitted. Source: `app/lib/sync/sync_coordinator.dart` -
  `SyncCoordinator._sendBoundRpc`.
- A discarded late success surfaces as `StateError` (from `isCurrent` or
  `withCurrentLease`), which `_runOnePass` delivers to `onPassFailure` like other
  pass-level `StateError`s; it never partially commits metadata. Source:
  `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator._sendBoundRpc`,
  `SyncCoordinator._runOnePass`.
- `repairEpisode()` itself runs inside `withMutation`, so the episode captured at
  `enroll()` start is ordered against concurrent latch/release turns rather than racing
  them. Source: `app/lib/sync/sync_repair_gate.dart` -
  `SyncRepairGate.repairEpisode`; `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService.enroll`.
