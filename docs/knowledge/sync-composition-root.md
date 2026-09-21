# Sync: composition root

Last reconciled: a9ef4ac

## Overview

`SyncCoordinator.create` is the app-side composition root for already-constructed ledger and
persistence collaborators. It opens the durable staging store, resolves the selected backend from
persisted metadata and caller-provided configuration, and creates a `SyncEngine` with a scoped
E2E-key accessor. It owns sync-pass scheduling, single-page pull processing, pending-
acknowledgement recovery, and per-collection push-candidate submission. It does not yet have an
`AppBoot` or other lifecycle caller, and it never starts the persistence processor. See
[sync-durable-stores.md](sync-durable-stores.md), [sync-package-engine.md](sync-package-engine.md),
and [persistence.md](persistence.md) for the assembled layers. Source:
`app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.create`, `SyncCoordinator.status`.

## Key locations

- `app/lib/sync/sync_coordinator.dart` - composition root, pull-page processing, acknowledgement
  recovery, push-candidate selection and acknowledgement, collaborators, and wiring validation.
- `app/lib/sync/sync_status.dart` - coordinator idle and running status variants.
- `app/lib/sync/cached_collection_version_source.dart` - async collection reads exposed through
  the package version-source contract.
- `app/lib/sync/collection_version_reader.dart` - bulk per-collection version reads for durable
  readback and push-candidate selection.
- `app/lib/sync/collection_lock.dart` - non-reentrant per-collection serialization shared by pull,
  acknowledgement recovery, and push.
- `app/lib/sync/sync_e2e_key_provider.dart` - scoped E2E-key accessor and unavailable-key errors.
- `app/lib/sync/sync_backend_resolver.dart` - backend selection and Supabase configuration
  validation.

## Interactions

`SyncCoordinator.create` requires a `LedgerDatabase`, a `Ledger`, and a
`PersistenceProcessor`. It rejects different event-bus instances before I/O, then derives the
device user ID, opens `DriftSyncStagingStore`, snapshots `SyncMetadataStore`, resolves a backend,
and creates the version source and `PostFlushReadbackVerifier` over one
`DriftCollectionVersionReader`. It retains the supplied ledger and processor without constructing
or starting either. Source: `app/lib/sync/sync_coordinator.dart` -
`SyncCoordinator.create`, `SyncCoordinatorWiringException`.

The coordinator gives `SyncEngine` only `SyncE2EKeyProvider.accessor`, not a `SecretStore` or a
device credential. It retains `CredentialProvider` privately for pull, acknowledgement, and push
backend calls. Source: `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.create`,
`SyncCoordinator.processPullPage`, `SyncCoordinator.recoverPendingAcknowledgements`,
`SyncCoordinator.pushCollection`.

`SyncBackendResolver` maps the persisted selected backend to `CustomEndpointSyncBackend` or
`SupabaseSyncBackend`, or returns null when no backend was selected. Custom endpoints and Supabase
project URLs must be absolute HTTPS URIs with hosts. `SyncCoordinator.create` accepts an optional
`SupabaseConfig`; this slice does not call `SupabaseConfig.fromEnvironment`. Supabase configuration
is never persisted in `SyncMetadataSnapshot`. Source:
`app/lib/sync/sync_backend_resolver.dart` - `SyncBackendResolver.resolve`, `SupabaseConfig`;
`app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.create`;
`app/lib/sync/sync_metadata_store.dart` - `SyncMetadataSnapshot`.

`SupabaseSyncAuthenticator` is a separate package adapter for Supabase-hosted email enrollment.
It uses GoTrue Auth (`/auth/v1/otp` and `/auth/v1/verify`), while `SupabaseSyncBackend` uses the
PostgREST RPC surface. Its project URL must use HTTPS. Custom endpoint enrollment authentication
is out of scope. Source: `packages/sync/lib/src/backends/supabase_authenticator.dart` -
`SupabaseSyncAuthenticator.beginEnrollment`, `SupabaseSyncAuthenticator.completeEnrollment`;
`packages/sync/lib/src/backends/supabase_backend.dart` - `SupabaseSyncBackend._rpc`.

The authenticator uses its private `_gotrueFailureFromHttp` mapper rather than the shared RPC
mapper: GoTrue HTTP 400 and 422 produce `InvalidRequest`, 429 produces `RateLimited`, and every
other status produces `BackendUnavailable`. The shared mapper assigns custom RPC meanings such as
HTTP 403 to `DeviceRetired`, which does not apply to the GoTrue exchange. Source:
`packages/sync/lib/src/backends/supabase_authenticator.dart` - `_gotrueFailureFromHttp`;
`packages/sync/lib/src/backends/http_support.dart` - `_failureFromHttp`.

`CachedCollectionVersionSource` bridges bulk asynchronous reads to the `SyncVersionSource` used
by the engine. A refresh reads every `SyncCollection`, publishes its new cache only after all
reads succeed, and joins overlapping refresh calls. Source:
`app/lib/sync/cached_collection_version_source.dart` -
`CachedCollectionVersionSource.refresh`, `CachedCollectionVersionSource.readRowVersion`;
`packages/sync/lib/src/engine/version_source.dart` - `SyncVersionSource`.

## Scheduler integration

`requestSync()` delegates a fire-and-forget request to the coordinator's internal
`SyncRunScheduler`. `syncNow()` delegates a joining request whose future resolves when the
scheduler-selected pass completes. The scheduler's single-flight and trailing-pass behavior is
documented in [sync-run-scheduler.md](sync-run-scheduler.md). Source:
`app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.requestSync`,
`SyncCoordinator.syncNow`, `SyncCoordinator._scheduler`;
`app/lib/sync/sync_run_scheduler.dart` - `SyncRunScheduler.requestRun`,
`SyncRunScheduler.runNow`.

One coordinator pass first calls `recoverPendingAcknowledgements()` once. It then starts flows for
all five `SyncCollection` values concurrently; each collection's flow awaits `processPullPage`
before `pushCollection`. Source: `app/lib/sync/sync_coordinator.dart` -
`SyncCoordinator._runOnePass`, `SyncCoordinator._pullThenPush`;
`app/test/sync/sync_coordinator_test.dart` - group `scheduling integration: run composition
(TS3)`.

`_runOnePass` catches only `StateError` and delivers it to the nullable `onPassFailure` callback.
It leaves every other exception for `SyncRunScheduler`, whose failure behavior is documented in
[sync-run-scheduler.md](sync-run-scheduler.md). Source:
`app/lib/sync/sync_coordinator.dart` - `PassFailureHandler`,
`SyncCoordinator.onPassFailure`, `SyncCoordinator._runOnePass`;
`app/test/sync/sync_coordinator_test.dart` - group `scheduling integration: failure handling
(TS4)`.

## Contracts and invariants

- Every invocation of `SyncE2EKeyProvider.accessor` lazily reads only
  `syncE2EKeySecretKey`; it neither reads `syncCredentialSecretKey` nor caches or eagerly reads
  the E2E key. The stored base64url value must decode to exactly 32 bytes. Absent, malformed,
  storage, and wrong-length failures become typed `SyncE2EKeyUnavailableException` reasons, whose
  messages omit the raw key and stored value. Source:
  `app/lib/sync/sync_e2e_key_provider.dart` - `SyncE2EKeyProvider.accessor`, `_readKey`,
  `SyncE2EKeyUnavailableException`; `app/test/sync/sync_e2e_key_provider_test.dart` - tests
  `accessing the closure reads lazily on each invocation` and `failure messages never expose key
  bytes or stored values`.
- The ledger and persistence processor must share the identical event bus. This is checked before
  any I/O; the caller remains responsible for backing the processor store with the supplied
  database. Source: `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.create`,
  `SyncCoordinatorWiringException`.
- An unselected backend is valid and yields null. A selected backend with missing or invalid
  configuration throws `SyncBackendConfigurationException` before adapter construction or network
  I/O. Source: `app/lib/sync/sync_backend_resolver.dart` - `SyncBackendResolver.resolve`,
  `_resolveCustom`, `_resolveSupabase`.
- `SyncCoordinator.pushCollection` requires `SyncMetadataStore.writeEnabled` before version or
  candidate reads and before any backend call. It selects a row only when its current
  `CollectionVersionReader` vector is not
  dominated by that row's acknowledged vector; a row without an acknowledgement is eligible.
  Source: `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.pushCollection`,
  `_pushCollectionLocked`; `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataSnapshot.writeEnabled`, `SyncMetadataStore.acknowledgedVectors`.
- Push acknowledgement commits only an `applied` or `already_present` response whose `siblingID`
  exactly matches the submitted sibling. The committed vector is captured from that envelope at
  encode time, never re-read from the version cache after the response or taken from the response
  frontier. Source: `app/lib/sync/sync_coordinator.dart` - `_pushCollectionLocked`,
  `_SubmittedPush`; `app/test/sync/sync_coordinator_test.dart` - group
  `pushCollection: response classification (TS3)`.
- `SyncCoordinator.pushCollection` returns `Future<PushCollectionResult>`. `PushNoop` means no
  eligible candidates existed. `PushDeferred` means inline pending-acknowledgement recovery
  remained uncleared, so no outbound push occurred. `PushFullyAcknowledged` means every submitted
  row was `applied` or `already_present` with a matching sibling ID and its captured submitted
  vector was acknowledged. `PushUnresolvedRows` identifies submitted rows with rejected, missing,
  mismatched, or malformed outcomes; they remain eligible for a later push. Source:
  `app/lib/sync/sync_coordinator.dart` - `PushCollectionResult`, `PushNoop`, `PushDeferred`,
  `PushFullyAcknowledged`, `PushUnresolvedRows`, `SyncCoordinator.pushCollection`,
  `_pushCollectionLocked`; `app/test/sync/sync_coordinator_test.dart` - group
  `pushCollection: structured result` and group `pushCollection: response classification (TS3)`.

## Entry points and flows

- `SyncCoordinator.create(...)` asynchronously assembles the coordinator. Optional injected
  `http.Client` and `SecretStore` support controlled composition; absent values use backend defaults
  and `SecureSecretStore`. Source: `app/lib/sync/sync_coordinator.dart` -
  `SyncCoordinator.create`.
- `SyncCoordinator.forTesting(...)` synchronously mirrors the private constructor's collaborator
  list so tests can inject a `SyncBackend` and any `SyncVersionSource`. The production `create`
  path remains unchanged; its version-source field is interface-typed to support this test seam.
  Source: `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.forTesting`,
  `SyncCoordinator.create`; `app/test/sync/sync_coordinator_test.dart` - group
  `processPullPage: duplicate/dominated pages (TS1)`.
- `SyncCoordinator.processPullPage(collection)` serializes work per collection, pulls at that
  collection's current watermark, and reconciles the page. It applies eligible remote changes
  through `Ledger.applySyncBatch`; after persistence and durable readback verification, it records
  their vectors, watermark, and acknowledgement checkpoint. Staged conflicts are durable before
  page metadata advances. A local mutation race, persistence-barrier failure, or failed readback
  leaves the page metadata unchanged. Pull failures throw `StateError`. Source:
  `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.processPullPage`,
  `_processPullPageLocked`, `_finalizeAndMaybeAcknowledge`; `app/lib/sync/collection_lock.dart` -
  `CollectionLock`; `app/lib/sync/mutation_fence.dart` - `MutationFence`; `app/lib/ledger/ledger.dart`
  - `Ledger.applySyncBatch`.
- `SyncCoordinator.recoverPendingAcknowledgements()` dispatches each durable collection checkpoint
  under that collection's lock. It skips acknowledgement while that collection has an unresolved
  staged conflict; otherwise `SyncSuccess` clears only the matching collection/checkpoint record
  and `SyncFailure` leaves it durable. A blocked or failed collection does not prevent attempts
  for other collections. Source: `app/lib/sync/sync_coordinator.dart` -
  `SyncCoordinator.recoverPendingAcknowledgements`, `_recoverOneAcknowledgement`;
  `app/lib/sync/collection_lock.dart` - `CollectionLock`.
- `SyncCoordinator.pushCollection(collection, {writeProof})` holds the collection lock, repairs a
  pending acknowledgement inline, refreshes the encode cache, derives eligible candidates from
  `versionReader` and `acknowledgedVectors`, then encodes and submits them. The inline
  `_recoverOneAcknowledgementLocked` helper avoids re-entering `CollectionLock`, whose documented
  same-collection re-entry self-deadlocks. An uncleared recovery defers the push without an
  outbound query. Source: `app/lib/sync/sync_coordinator.dart` -
  `SyncCoordinator.pushCollection`, `_pushCollectionLocked`,
  `_recoverOneAcknowledgementLocked`; `app/lib/sync/collection_lock.dart` - `CollectionLock`;
  `app/test/sync/sync_coordinator_test.dart` - groups
  `pushCollection: candidate derivation (TS1)`,
  `pushCollection: recovery-before-push ordering (TS2)`, and
  `pushCollection: recovery-not-cleared deferral (TS8)`.
- `SyncCoordinator.status` is `SyncIdle` after creation and becomes `SyncRunning` while the
  scheduler has an active pass, including a chained trailing pass. The scheduler's idle callback
  restores `SyncIdle`. Source: `app/lib/sync/sync_coordinator.dart` -
  `SyncCoordinator.status`, `SyncCoordinator._handleSchedulerStatus`;
  `app/lib/sync/sync_status.dart` - `SyncIdle`, `SyncRunning`.
- `CachedCollectionVersionSource.refresh()` loads all collections and rethrows an unsuccessful
  read without replacing the last published cache. Source:
  `app/lib/sync/cached_collection_version_source.dart` -
  `CachedCollectionVersionSource.refresh`, `_load`.

## Gotchas

- The version cache starts empty, so synchronous reads return null until a pull-page call refreshes
  it. `SyncVersionSource.refresh()` makes this refresh part of the source contract; the in-memory
  test source implements it as a no-op. A failed cache refresh preserves the prior cache. Source:
  `app/lib/sync/cached_collection_version_source.dart` -
  `CachedCollectionVersionSource.refresh`, `CachedCollectionVersionSource.readRowVersion`;
  `packages/sync/lib/src/engine/version_source.dart` - `SyncVersionSource.refresh`,
  `InMemorySyncVersionSource.refresh`; `app/lib/sync/sync_coordinator.dart` -
  `SyncCoordinator.processPullPage`.
- `SyncCoordinator._runOnePass` is the production caller of `processPullPage`,
  `recoverPendingAcknowledgements`, and `pushCollection`. `AppBoot` and other lifecycle wiring
  still do not call `requestSync`, `syncNow`, or `dispose`, and the coordinator does not start the
  persistence processor. `pushCollection` does not derive pushes from conflicts. Source:
  `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator._runOnePass`,
  `SyncCoordinator.requestSync`, `SyncCoordinator.syncNow`, `SyncCoordinator.dispose`;
  `app/lib/boot/app_boot.dart` - `AppBoot`.
- `SyncRunning` mirrors `SyncIdle` while the scheduler has an active pass. A pass can settle after
  `SyncCoordinator.dispose()`, so `_handleSchedulerStatus` must not update status or call
  `notifyListeners()` once disposal has begun. Source:
  `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.dispose`,
  `SyncCoordinator._handleSchedulerStatus`; `app/lib/sync/sync_status.dart` - `SyncRunning`;
  `app/test/sync/sync_coordinator_test.dart` - group `scheduling integration: dispose`.
