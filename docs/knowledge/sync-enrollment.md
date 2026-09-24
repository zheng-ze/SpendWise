# Sync: enrollment

Last reconciled: eb968bbc7b012181c453c54afb1f74a7ef4e0b3c

## Overview

`SyncEnrollmentService` owns the app-layer enrollment phase machine. It acquires
or recovers a device credential, ensures an E2E key exists, completes the
initial reconciliation handshake, and enables writes only after reconciliation
is durably complete. `composeSyncEnrollment` is the hosted-enrollment factory:
it creates the Supabase authenticator, service, coordinator, and publisher from
ready boot providers and persisted Supabase selection. `SyncEnrollmentFlow`
opens that graph through `openSyncEnrollmentSession`, which exposes only
`enroll()` and `publishSnapshot()` to the UI. Source:
`app/lib/sync/sync_enrollment_composition.dart` - `composeSyncEnrollment`,
`SyncEnrollmentComposition`;
`app/lib/sync/sync_enrollment_session.dart` - `SyncEnrollmentSession`,
`openSyncEnrollmentSession`;
`app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
`SyncEnrollmentNotifier._opener`;
`app/lib/sync/sync_enrollment_service.dart` - `SyncEnrollmentService`;
`app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.create`;
`packages/sync/lib/src/backends/supabase_authenticator.dart` -
`SupabaseSyncAuthenticator`.

`EnrollmentSnapshotPublisher` is the next app-layer component after the phase
machine reaches `gateEnabled`: it drives one ordered push across all
collections and owns the enrollment write-proof lifecycle for that run. The
enrollment Flow invokes it through `SyncEnrollmentSession.publishSnapshot()`;
the publisher itself remains independent of lifecycle scheduling. Source:
`app/lib/sync/enrollment_snapshot_publisher.dart` -
`EnrollmentSnapshotPublisher`; `app/lib/sync/sync_enrollment_service.dart` -
`SyncEnrollmentService`; `app/lib/sync/sync_enrollment_session.dart` -
`SyncEnrollmentSession.publishSnapshot`.

## Key locations

- `app/lib/sync/sync_enrollment_service.dart` - enrollment orchestration,
  crash recovery, and remote-failure translation.
- `app/lib/sync/sync_enrollment_composition.dart` - hosted-enrollment factory,
  typed readiness/configuration outcomes, and production E2E-key source.
- `app/lib/sync/sync_e2e_key_provider.dart` - shared stored-key decoder and
  validator.
- `app/lib/sync/sync_metadata_store.dart` - durable enrollment phases and
  write-gate guard.
- `app/lib/sync/reconciliation_snapshot_hasher.dart` - pages one fixed-watermark
  snapshot per collection and hashes it, per collection, for `CompleteReconcile`.
- `app/lib/sync/enrollment_snapshot_publisher.dart` - ordered post-gate
  enrollment-snapshot push and write-proof consumption.
- `app/lib/sync/sync_enrollment_session.dart` - narrow UI session adapter over
  the ready hosted-enrollment composition.
- `docs/knowledge/sync-enrollment-flow.md` - hosted-enrollment UI flow,
  navigation, and retry ownership.
- `app/test/sync/sync_enrollment_service_test.dart` - phase-machine recovery,
  key, reconciliation, and failure contracts.
- `app/test/sync/reconciliation_snapshot_hasher_test.dart` - paging, hashing,
  and malformed-page contracts.
- `app/test/sync/enrollment_snapshot_publisher_test.dart` - ordered push,
  pending-result, write-proof, and failure-propagation contracts.

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

`EnrollmentSnapshotPublisher` depends on `SyncCoordinator.pushCollection`,
which preserves the coordinator's write-gate and push-result semantics. Its
required coordinator and optional `SecretStore` are constructor-injected; the
default store is `SecureSecretStore`. Source:
`app/lib/sync/enrollment_snapshot_publisher.dart` -
`EnrollmentSnapshotPublisher`, `EnrollmentSnapshotPublisher.publish`;
`app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.pushCollection`.

`composeSyncEnrollment` reads `ledgerProvider` and
`persistenceProcessorProvider` before opening the database or resolving
configuration. It returns `SyncEnrollmentNotReady` with both readiness flags
when either is absent. For a ready boot graph, it accepts only a persisted
Supabase selection, resolves it through `SyncBackendResolver`, then creates the
authenticator, enrollment service, coordinator, and publisher with one shared
`SecretStore`. Source: `app/lib/sync/sync_enrollment_composition.dart` -
`composeSyncEnrollment`, `SyncEnrollmentNotReady`,
`SyncEnrollmentConfigurationError`.

`SupabaseSyncAuthenticator.completeEnrollment` requires the caller's local `deviceId` in
`CompleteEnrollmentRequest.wire`. That value becomes `DeviceCredential.deviceID` and must be the
same identifier returned downstream by `deviceID(database)`. The adapter sends the email and OTP to
GoTrue `/auth/v1/verify` and maps a successful `access_token` to the opaque credential. Its
`refreshCredential` always returns `BackendUnavailable` because the credential has no refresh-token
field; re-enrollment is required. Source:
`packages/sync/lib/src/backends/supabase_authenticator.dart` -
`SupabaseSyncAuthenticator.completeEnrollment`, `SupabaseSyncAuthenticator.refreshCredential`,
`_credentialFromVerifyBody`, `_gotrueFailureFromHttp` (400/422 invalid request, 429 rate limited,
other statuses backend unavailable);
`packages/sync/lib/src/protocol/credential.dart` - `DeviceCredential`;
`app/lib/persistence/device_identity.dart` - `deviceID`.

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
- `EnrollmentSnapshotPublisher.publish()` reads
  `syncWriteProofSecretKey` once before iterating `SyncCollection.values` in
  enum order. It supplies that value only with the first non-`PushNoop` result;
  that proof slot is consumed even when the stored value is null, so later
  pushes in the same run always receive null. Source:
  `app/lib/sync/enrollment_snapshot_publisher.dart` -
  `EnrollmentSnapshotPublisher.publish`.
- On the proof-bearing push, `PushFullyAcknowledged` or
  `PushUnresolvedRows` immediately deletes a non-null stored proof.
  `PushDeferred` preserves it for a later invocation. Source:
  `app/lib/sync/enrollment_snapshot_publisher.dart` -
  `EnrollmentSnapshotPublisher.publish`.
- A run returns `EnrollmentSnapshotPending` at the first `PushDeferred` or
  `PushUnresolvedRows`, carrying that collection and result. It returns
  `EnrollmentSnapshotPublished` only when every collection is `PushNoop` or
  `PushFullyAcknowledged`. Source:
  `app/lib/sync/enrollment_snapshot_publisher.dart` -
  `EnrollmentSnapshotPublishResult`, `EnrollmentSnapshotPublisher.publish`.
- Hosted composition accepts no missing, custom, or invalid persisted Supabase
  configuration. Those conditions return `SyncEnrollmentConfigurationError`
  rather than falling back to another backend. Source:
  `app/lib/sync/sync_enrollment_composition.dart` -
  `composeSyncEnrollment`; `app/lib/sync/sync_backend_resolver.dart` -
  `SyncBackendResolver.resolve`, `SyncBackendConfigurationException`.
- The production E2E-key source uses `Random.secure()` to produce exactly
  `SyncCipher.keyByteCount` bytes. The complete-enrollment request sends the
  challenge's `wire['identifier']` verbatim, including a missing, empty, or
  malformed value; it never substitutes the submitted identifier. Source:
  `app/lib/sync/sync_enrollment_composition.dart` -
  `resolveProductionSyncE2EKey`, `composeSyncEnrollment`;
  `app/test/sync/sync_enrollment_composition_test.dart` -
  `malformed challenge identifier is carried verbatim, never replaced by the submitted identifier`.

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
- `EnrollmentSnapshotPublisher.publish()` is one pass only. A caller must
  reinvoke it after `EnrollmentSnapshotPending`; it has no internal retry or
  scheduling loop. Source: `app/lib/sync/enrollment_snapshot_publisher.dart` -
  `EnrollmentSnapshotPublisher.publish`.
- `composeSyncEnrollment(...)` is the hosted composition entry point. Callers
  provide the submitted identifier and OTP resolver. It returns a typed
  readiness or configuration outcome instead of attempting hosted enrollment
  before boot dependencies and persisted selection are valid. Source:
  `app/lib/sync/sync_enrollment_composition.dart` -
  `composeSyncEnrollment`, `SyncEnrollmentReady`, `SyncEnrollmentNotReady`,
  `SyncEnrollmentConfigurationError`.

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
- `SyncEnrollmentService` itself still has no operation lock. The UI Flow
  serializes its enroll-and-publish operation, but other callers must provide
  equivalent serialization. Source:
  `app/lib/sync/sync_enrollment_service.dart` - `SyncEnrollmentService.enroll`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
  `SyncEnrollmentNotifier.submitIdentifier`, `SyncEnrollmentNotifier.retry`.
