# Sync: enrollment

Last reconciled: ad25ece

## Overview

`SyncEnrollmentService` owns the app-layer enrollment phase machine. It acquires
or recovers a device credential, ensures an E2E key exists, completes the
initial reconciliation handshake, and enables writes only after reconciliation
is durably complete. It is separate from `SyncCoordinator.create`: no shipped
composition path constructs or calls this service yet. Source:
`app/lib/sync/sync_enrollment_service.dart` - `SyncEnrollmentService`;
`app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.create`.

## Key locations

- `app/lib/sync/sync_enrollment_service.dart` - enrollment orchestration,
  crash recovery, and remote-failure translation.
- `app/lib/sync/sync_e2e_key_provider.dart` - shared stored-key decoder and
  validator.
- `app/lib/sync/sync_metadata_store.dart` - durable enrollment phases and
  write-gate guard.
- `app/lib/sync/reconciliation_snapshot_hasher.dart` - pages one fixed-watermark
  snapshot per collection and hashes it, per collection, for `CompleteReconcile`.
- `app/test/sync/sync_enrollment_service_test.dart` - phase-machine recovery,
  key, reconciliation, and failure contracts.
- `app/test/sync/reconciliation_snapshot_hasher_test.dart` - paging, hashing,
  and malformed-page contracts.

## Interactions

Each `enroll()` invocation begins from the fresh durable phase returned by
`SyncMetadataStore.snapshot()`. Its exhaustive phase switch advances
`notEnrolled`, `credentialAcquired`, `snapshotInProgress`, and
`reconciliationComplete` to `gateEnabled`; phase presence, rather than a
credential or key alone, determines the next step. Source:
`app/lib/sync/sync_enrollment_service.dart` - `SyncEnrollmentService.enroll`,
`SyncEnrollmentService._advance`.

The service restores credentials through `CredentialProvider`, validates stored
keys through `decodeAndValidateSyncE2EKey`, and calls `SyncBackend.reconcile`
directly for `BeginReconcile` and `CompleteReconcile`. It neither wraps that
backend interaction nor waits for steady-state pull/apply machinery. Source:
`app/lib/sync/sync_enrollment_service.dart` -
`SyncEnrollmentService._stepSnapshotInProgress`,
`SyncEnrollmentService._stepCredentialAcquired`.

Between `BeginReconcile` and `CompleteReconcile`, the service builds a
`ReconciliationSnapshotHasher` through its injected `buildSnapshotHasher`
factory and calls `hashAll` with the `ReconciliationContext` decoded from
`BeginReconcile`'s response. The hasher belongs to `app/lib/sync/`, not
`packages/sync`: it calls `SyncBackend.pull` directly with
`PullRequest.reconciliation`, so its snapshot-paging loop lives at the same
layer as the rest of enrollment orchestration. Source:
`app/lib/sync/reconciliation_snapshot_hasher.dart` -
`ReconciliationSnapshotHasher`; `app/lib/sync/sync_enrollment_service.dart` -
`SyncEnrollmentService._stepSnapshotInProgress`.

`decodeAndValidateSyncE2EKey` is the shared unpadded-base64url decoder and
32-byte validator used by both `SyncE2EKeyProvider` and the enrollment service.
It reports malformed and wrong-length values through
`SyncE2EKeyUnavailableException`. Source:
`app/lib/sync/sync_e2e_key_provider.dart` -
`decodeAndValidateSyncE2EKey`, `SyncE2EKeyProvider._readKey`;
`app/lib/sync/sync_enrollment_service.dart` -
`SyncEnrollmentService._stepCredentialAcquired`.

## Contracts and invariants

- If `notEnrolled` finds a stored credential that restores and matches
  `deviceID(database)`, it records `credentialAcquired` without repeating the
  handshake. This recovers a crash after credential write and before phase
  persistence. A malformed or mismatched stored credential is deleted before a
  fresh handshake. Source: `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._stepNotEnrolled`,
  `SyncEnrollmentService._storedCredentialMatchesDevice`.
- At `credentialAcquired`, a stored E2E key must decode and have the required
  length. A malformed or wrong-length stored key fails without deletion or
  replacement. The service writes a resolved key only when the secret is
  absent. Source: `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._stepCredentialAcquired`.
- `_requireSuccess` converts every remote `SyncFailure` into
  `SyncEnrollmentException` with its step, code, message, and retry delay.
  The affected step does not advance the durable phase or write gate after that
  failure. Source: `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._requireSuccess`,
  `SyncEnrollmentService._stepNotEnrolled`,
  `SyncEnrollmentService._stepSnapshotInProgress`.
- The terminal step calls `SyncMetadataStore.setWriteEnabled(true)` while the
  durable phase is `reconciliationComplete`, then records `gateEnabled`. The
  metadata store retains ownership of refusing an early gate enable. Source:
  `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._stepReconciliationComplete`;
  `app/lib/sync/sync_metadata_store.dart` - `SyncMetadataStore.setWriteEnabled`.
- A `CompleteReconcile` outcome of `SnapshotHashMismatch` that names a
  collection (`mismatchedCollection`) re-pages and re-hashes only that
  collection under the same `ReconciliationContext`, then retries
  `CompleteReconcile` exactly once with the replaced digest. A mismatch that
  names no collection, or a second mismatch after the retry, fails the step
  without advancing the phase. Source:
  `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._stepSnapshotInProgress`;
  `packages/sync/lib/src/protocol/outcome.dart` -
  `SnapshotHashMismatch.mismatchedCollection`.

## Entry points and flows

- `SyncEnrollmentService.enroll()` continues until `gateEnabled`. Re-entry
  after a failure or crash resumes from the recorded phase. Source:
  `app/lib/sync/sync_enrollment_service.dart` - `SyncEnrollmentService.enroll`.
- The initial reconciliation obtains a restored credential, sends
  `BeginReconcile`, decodes its `ReconciliationContext` via
  `ReconcileResponse.reconciliationContext`, hashes all 5 collections through
  `ReconciliationSnapshotHasher.hashAll`, then sends
  `CompleteReconcile(collectionHashes: ...)`, retrying once on a
  collection-named `snapshot_hash_mismatch`. It records
  `reconciliationComplete` only after `CompleteReconcile` finally succeeds.
  Source: `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._stepSnapshotInProgress`.

## Gotchas

- Do not call `enroll()` concurrently on one service instance. The service has
  no operation lock, scheduler, or caller in the shipped composition root.
  Source: `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService.enroll`; `app/lib/sync/sync_coordinator.dart` -
  `SyncCoordinator.create`.
- `ReconciliationSnapshotHasher` never stages, acknowledges, or applies the
  envelopes it pulls. Each `hashCollection` call accumulates pulled envelopes
  in an operation-local in-memory list only, purely to compute a digest; it
  never writes them through any durable staging store and never touches
  `LedgerState`. A crash mid-snapshot discards that list entirely - retry
  starts a fresh fixed-watermark reconciliation from scratch, not a resumed
  one. Do not assume "snapshot paging" implies durable staging anywhere in
  this path. Source: `app/lib/sync/reconciliation_snapshot_hasher.dart` -
  `ReconciliationSnapshotHasher.hashCollection`.
- `ReconciliationContext`'s wire shape (`reconciliation_id`,
  `snapshot_watermark`, `expires_at`, nested `cursor`) is client-defined ahead
  of any real backend. No shipped backend (Supabase or custom) yet serves
  reconciliation-mode pulls or returns this context from `BeginReconcile`; a
  future backend implementation must match this client-defined contract, not
  the other way around. Source: `packages/sync/lib/src/protocol/requests.dart`
  - `ReconciliationContext`, `PullRequest.reconciliation`.
