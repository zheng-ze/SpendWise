# Sync: enrollment

Last reconciled: e9f1db4

## Overview

`SyncEnrollmentService` owns the app-layer enrollment phase machine. It ensures
the E2E key before device-binding authorization, verifies one binding OTP,
uses the returned bearer and authorization for Begin, stores the device secret,
and completes reconciliation with bound credentials. It enables writes only
after reconciliation is durably complete. `composeSyncEnrollment` is the
hosted-enrollment factory: it creates the Supabase binding authorizer,
authenticator, service, coordinator, and publisher from ready boot providers
and persisted Supabase selection. `SyncEnrollmentFlow`
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

Each `enroll()` invocation reads a fresh `SyncMetadataStore.snapshot()` and
validates its binding, phase, write-gate, and reauth-resume tuple. The service
advances only legal combinations through `notEnrolled` or legacy
`credentialAcquired`, `bindingAuthorizationRequired`, `snapshotInProgress`,
and `reconciliationComplete` to `gateEnabled`. A bound
`sessionReauthRequired` row restores its recorded resume phase after ordinary
OTP authentication. Source:
`app/lib/sync/sync_enrollment_service.dart` - `SyncEnrollmentService.enroll`,
`SyncEnrollmentService._advance`; `app/lib/sync/sync_metadata_store.dart` -
`SyncMetadataStore.validateHostedOperationState`,
`SyncMetadataStore.restoreFromSessionReauth`.

The service reads bound credentials through `CredentialProvider` after storing
the device secret. It calls `SyncBackend.reconcile` directly for Begin and
Complete. The authorization-bearing Begin uses the verified session bearer;
subsequent Begin, snapshot Pull, and Complete use `BoundDeviceCredential`.
This path does not wait for steady-state pull/apply machinery. Source:
`app/lib/sync/sync_enrollment_service.dart` -
`SyncEnrollmentService._stepBindingAuthorizationRequired`,
`SyncEnrollmentService._stepSnapshotInProgress`,
`SyncEnrollmentService._completeSnapshot`;
`app/lib/sync/reconciliation_snapshot_hasher.dart` -
`ReconciliationSnapshotHasher.hashCollection`.

Between `BeginReconcile` and `CompleteReconcile`, the service builds a
`ReconciliationSnapshotHasher` through its injected `buildSnapshotHasher`
factory and calls `hashAll` with the `ReconciliationContext` decoded from
`BeginReconcile`'s response. The hasher belongs to `app/lib/sync/`, not
`packages/sync`: it calls `SyncBackend.pull` directly with
`PullRequest.reconciliation`, so its snapshot-paging loop lives at the same
layer as the rest of enrollment orchestration. Source:
`app/lib/sync/reconciliation_snapshot_hasher.dart` -
`ReconciliationSnapshotHasher`; `app/lib/sync/sync_enrollment_service.dart` -
`SyncEnrollmentService._completeSnapshot`.

`SyncE2EKeyProvider.accessor` validates the stored E2E key before binding
authorization. It uses the shared unpadded-base64url decoder and 32-byte
validator, which report malformed and wrong-length values through
`SyncE2EKeyUnavailableException`. Source:
`app/lib/sync/sync_e2e_key_provider.dart` -
`decodeAndValidateSyncE2EKey`, `SyncE2EKeyProvider._readKey`;
`app/lib/sync/sync_enrollment_service.dart` -
`SyncEnrollmentService._ensureE2EKey`,
`SyncEnrollmentService._stepBindingAuthorizationRequired`.

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
binding authorizer, authenticator, enrollment service, coordinator, and
publisher with one shared `SecretStore`. It passes the submitted identifier
and OTP resolver to both the binding path and the ordinary reauth path. Source:
`app/lib/sync/sync_enrollment_composition.dart` -
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

- Fresh enrollment creates a missing E2E key before entering
  `bindingAuthorizationRequired`. A stored malformed or wrong-length key
  fails without deletion or replacement. Once the binding phase is durable,
  an absent key fails rather than generating a replacement. Source:
  `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._ensureE2EKey`,
  `SyncEnrollmentService._stepPrepareFreshEnrollment`,
  `SyncEnrollmentService._stepBindingAuthorizationRequired`.
- At `bindingAuthorizationRequired`, `startBinding` supplies the challenge for
  one OTP, and `verifyBinding` returns a session bearer and Begin authorization.
  The service persists the bearer, sends authorization-bearing Begin, validates
  and stores its `device_secret`, then enters `snapshotInProgress` before any
  reconciliation Pull. A valid but unconfirmed stored secret at the binding
  phase resumes with a bound Begin without another OTP. A response with code
  `device_authorization_required` clears the secret and returns to binding
  authorization. A malformed stored secret is deleted before a new binding
  attempt. Source: `app/lib/sync/sync_enrollment_service.dart`
  - `SyncEnrollmentService._stepBindingAuthorizationRequired`,
  `SyncEnrollmentService._stepSnapshotInProgress`.
- `SyncMetadataStore.enter*` transitions update related binding, phase, write
  gate, and reauth-resume fields together in transactions.
  `enterGateEnabled` requires bound `reconciliationComplete` and atomically
  enables writes while entering `gateEnabled`. Source:
  `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.enterBindingAuthorizationRequired`,
  `SyncMetadataStore.enterSnapshotInProgress`,
  `SyncMetadataStore.enterReconciliationComplete`,
  `SyncMetadataStore.enterGateEnabled`.
- Missing or malformed bound credentials and `credential_expired` or
  `device_authorization_required` reconciliation failures route to session
  reauthentication or binding authorization as appropriate. Session
  reauthentication uses ordinary OTP, replaces only the bearer, and restores
  the recorded phase; an absent or malformed device secret routes back to
  binding authorization. Source: `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._routeCredentialUnavailable`,
  `SyncEnrollmentService._routeBoundFailure`,
  `SyncEnrollmentService._stepSessionReauthRequired`.
- A `CompleteReconcile` outcome of `SnapshotHashMismatch` that names a
  collection (`mismatchedCollection`) re-pages and re-hashes only that
  collection under the same `ReconciliationContext`, then retries
  `CompleteReconcile` exactly once with the replaced digest. A mismatch that
  names no collection, or a second mismatch after the retry, fails the step
  without advancing the phase. Source:
  `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._completeSnapshot`;
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
- The initial binding attempt sends authorization-bearing Begin with the
  verified bearer. A resumed snapshot sends bound Begin. Both decode
  `ReconciliationContext` via `ReconcileResponse.reconciliationContext`, hash
  all 5 collections through `ReconciliationSnapshotHasher.hashAll`, then send
  `CompleteReconcile(collectionHashes: ...)`, retrying once on a
  collection-named `snapshot_hash_mismatch`. It records
  `reconciliationComplete` only after `CompleteReconcile` finally succeeds.
  Source: `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._stepBindingAuthorizationRequired`,
  `SyncEnrollmentService._stepSnapshotInProgress`,
  `SyncEnrollmentService._completeSnapshot`.
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
