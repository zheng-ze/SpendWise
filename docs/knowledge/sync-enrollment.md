# Sync: enrollment

Last reconciled: b2b08c1

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
- `app/test/sync/sync_enrollment_service_test.dart` - phase-machine recovery,
  key, reconciliation, and failure contracts.

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

## Entry points and flows

- `SyncEnrollmentService.enroll()` continues until `gateEnabled`. Re-entry
  after a failure or crash resumes from the recorded phase. Source:
  `app/lib/sync/sync_enrollment_service.dart` - `SyncEnrollmentService.enroll`.
- The initial reconciliation obtains a restored credential, sends
  `BeginReconcile`, resolves hashes, then sends
  `CompleteReconcile(collectionHashes: ...)`. It records
  `reconciliationComplete` only after both calls succeed. Source:
  `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._stepSnapshotInProgress`.

## Gotchas

- Do not call `enroll()` concurrently on one service instance. The service has
  no operation lock, scheduler, or caller in the shipped composition root.
  Source: `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService.enroll`; `app/lib/sync/sync_coordinator.dart` -
  `SyncCoordinator.create`.
