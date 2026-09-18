# Sync: composition root

Last reconciled: 001954c

## Overview

`SyncCoordinator.create` is the app-side composition root for already-constructed ledger and
persistence collaborators. It opens the durable staging store, resolves the selected backend from
persisted metadata and caller-provided configuration, and creates a `SyncEngine` with a scoped
E2E-key accessor. It also owns single-page pull processing and pending-acknowledgement recovery.
It has no production run, scheduling, trigger, or lifecycle wiring, and it never starts the
persistence processor. See
[sync-durable-stores.md](sync-durable-stores.md), [sync-package-engine.md](sync-package-engine.md),
and [persistence.md](persistence.md) for the assembled layers. Source:
`app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.create`, `SyncCoordinator.status`.

## Key locations

- `app/lib/sync/sync_coordinator.dart` - composition root, pull-page processing, acknowledgement
  recovery, collaborators, and wiring validation.
- `app/lib/sync/sync_status.dart` - the current idle-only coordinator status.
- `app/lib/sync/cached_collection_version_source.dart` - async collection reads exposed through
  the synchronous package version-source contract.
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
device credential. It retains `CredentialProvider` privately for pull and acknowledgement backend
calls. Source: `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.create`,
`SyncCoordinator.processPullPage`, `SyncCoordinator.recoverPendingAcknowledgements`.

`SyncBackendResolver` maps the persisted selected backend to `CustomEndpointSyncBackend` or
`SupabaseSyncBackend`, or returns null when no backend was selected. Custom endpoints and Supabase
project URLs must be absolute HTTPS URIs with hosts. `SyncCoordinator.create` accepts an optional
`SupabaseConfig`; this slice does not call `SupabaseConfig.fromEnvironment`. Supabase configuration
is never persisted in `SyncMetadataSnapshot`. Source:
`app/lib/sync/sync_backend_resolver.dart` - `SyncBackendResolver.resolve`, `SupabaseConfig`;
`app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.create`;
`app/lib/sync/sync_metadata_store.dart` - `SyncMetadataSnapshot`.

`CachedCollectionVersionSource` bridges bulk asynchronous reads to the synchronous
`SyncVersionSource` used by the engine. A refresh reads every `SyncCollection`, publishes its new
cache only after all reads succeed, and joins overlapping refresh calls. Source:
`app/lib/sync/cached_collection_version_source.dart` -
`CachedCollectionVersionSource.refresh`, `CachedCollectionVersionSource.readRowVersion`;
`packages/sync/lib/src/engine/version_source.dart` - `SyncVersionSource`.

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
- `SyncCoordinator.processPullPage(collection)` pulls at that collection's current watermark and
  reconciles the response through `SyncEngine.reconcile`. It refreshes a
  `CachedCollectionVersionSource` before classifying conflict-free stamps. If every row is locally
  equal or dominated, it calls `SyncMetadataStore.recordPulledPage` with an empty vectors map and
  the response cursor as watermark and checkpoint, publishing nothing to `Ledger` and enqueueing
  nothing to `PersistenceProcessor`. A page with a new row or staged conflict commits no page
  metadata, although reconciliation's unconditional, idempotent conflict staging remains. Pull
  failures throw `StateError`. Source: `app/lib/sync/sync_coordinator.dart` -
  `SyncCoordinator.processPullPage`, `SyncCoordinator._isDuplicateOrDominated`;
  `app/test/sync/sync_coordinator_test.dart` - groups
  `processPullPage: duplicate/dominated pages (TS1)` and
  `processPullPage: new and conflicting pages (TS2, TS3)`.
- `SyncCoordinator.recoverPendingAcknowledgements()` replays every durable collection checkpoint
  from `SyncMetadataStore.pendingAcknowledgements()` through `SyncBackend.acknowledge`. A
  `SyncSuccess` clears only that collection's record. A `SyncFailure` remains durable, and does
  not block acknowledgement attempts for other collections. Source:
  `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.recoverPendingAcknowledgements`;
  `app/test/sync/sync_coordinator_test.dart` - group `recoverPendingAcknowledgements (TS5)`.
- `SyncCoordinator.status` is `SyncIdle` after creation. No state transition exists in this slice.
  Source: `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.status`;
  `app/lib/sync/sync_status.dart` - `SyncIdle`.
- `CachedCollectionVersionSource.refresh()` loads all collections and rethrows an unsuccessful
  read without replacing the last published cache. Source:
  `app/lib/sync/cached_collection_version_source.dart` -
  `CachedCollectionVersionSource.refresh`, `_load`.

## Gotchas

- The version cache starts empty, so synchronous reads return null until a pull-page call refreshes
  it. `processPullPage` refreshes only `CachedCollectionVersionSource`; a future
  `SyncVersionSource` implementation that also needs refreshing requires explicit handling. A
  failed refresh preserves the prior cache. Source:
  `app/lib/sync/cached_collection_version_source.dart` -
  `CachedCollectionVersionSource.refresh`, `CachedCollectionVersionSource.readRowVersion`;
  `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.processPullPage`.
- `processPullPage` and `recoverPendingAcknowledgements` are coordinator capabilities only.
  Neither has a production caller, so startup/lifecycle wiring remains explicit future scope.
  Source: `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.processPullPage`,
  `SyncCoordinator.recoverPendingAcknowledgements`; `app/test/sync/sync_coordinator_test.dart` -
  groups `processPullPage: duplicate/dominated pages (TS1)` and
  `recoverPendingAcknowledgements (TS5)`.
- `SyncIdle` is deliberately the only current status. It remains so because this slice has no
  run, scheduling, trigger, lifecycle, or persistence-start wiring. Source:
  `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.status`;
  `app/lib/sync/sync_status.dart` - `SyncStatus`, `SyncIdle`.
