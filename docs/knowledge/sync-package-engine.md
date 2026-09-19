# Sync: package engine

Last reconciled: f819017

## Layer overview

The `packages/sync` engine layer converts local `LedgerChange` values into encrypted sync
envelopes and converts pulled envelopes into conflict-free stamped changes or staged conflicts.
It owns authenticated encryption, the canonical versioned payload codec, composite row identity,
version-vector frontier reduction, and the conflict-staging contract. It returns changes for a
caller to apply and does not mutate `LedgerState` itself.

The package is Flutter-free. Its source and dependency manifest contain no Flutter, Drift,
Riverpod, app, or secure-storage dependency. The package boundary test also rejects Flutter,
`dart:ui`, Supabase Flutter, and app imports. Durable stores, secure key storage, scheduling,
Ledger integration, backend composition, and conflict-review UI belong outside this layer.
Source: `packages/sync/pubspec.yaml` - `dependencies`;
`packages/sync/test/package_boundary_test.dart` - test
`packages/sync has no Flutter, dart:ui, Supabase-Flutter, or app imports`.

## Key files

- `packages/sync/lib/sync.dart` - Public package library and export surface.
- `packages/sync/lib/src/engine/sync_engine.dart` - Main encode and reconcile entry point, result
  types, key-access seam, and total `LedgerChange` collection mapping.
- `packages/sync/lib/src/engine/sync_row_id.dart` - Normalized composite row identity.
- `packages/sync/lib/src/engine/version_source.dart` - Exact stored-version read contract and its
  in-memory test implementation.
- `packages/sync/lib/src/engine/staging_store.dart` - Validated conflict group and staging-store
  contract.
- `packages/sync/lib/src/crypto/sync_cipher.dart` - XChaCha20-Poly1305 encryption, framing, and
  decryption errors.
- `packages/sync/lib/src/codec/payload_codec.dart` - Versioned codec between plaintext bytes and
  domain upsert changes.
- `packages/sync/lib/src/credential/credential_codec.dart` - Opaque device-credential persistence
  codec.
- `packages/sync/lib/src/protocol/envelope.dart` - Envelope metadata, authenticated associated
  data, and sibling identity.
- `packages/sync/lib/src/protocol/requests.dart` - Request wire encoders and typed pull-page
  response accessors.
- `packages/sync/lib/src/protocol/version_vector.dart` - Causal ordering and persistence and wire
  codecs for version vectors.
- `packages/sync/pubspec.yaml` - Pure-Dart dependency boundary, including the pinned cryptography
  implementation.
- `packages/sync/test/engine/sync_engine_test.dart` - Engine reconciliation, identity, encoding,
  mapping, and key-access contract tests.

## Module interactions

For a push, a caller gives `SyncEngine.encode` local `LedgerChange` values and a
`SyncVersionSource`. The engine maps every change to a `SyncCollection`, normalizes its row ID,
reads that row's exact stored `RowVersion`, encodes live content with `PayloadCodec`, and encrypts
the payload with a key from `SyncE2EKeyAccessor`. Deletes produce authenticated tombstone
envelopes with empty plaintext. Missing stored versions throw `SyncUntrackedRowError`, so the
engine never invents an empty causal history. Source:
`packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine.encode`, `collectionFor`,
`SyncUntrackedRowError`; `packages/sync/test/engine/sync_engine_test.dart` - group `encode`.

For a pull, a caller gives `SyncEngine.reconcile` envelopes received from a `SyncBackend`. The
engine authenticates and decodes all envelopes, groups them by `SyncRowID`, and reduces each group
to its non-dominated version-vector frontier. A single frontier member becomes a returned change
and stamp. Multiple frontier members become a `StagedConflict`, which the engine writes through
`SyncStagingStore` and also returns in `ReconcileResult`. The engine neither calls the backend nor
applies the returned changes to a Ledger. Source:
`packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine.reconcile`,
`SyncEngine._nonDominatedFrontier`, `ReconcileResult`;
`packages/sync/test/engine/sync_engine_test.dart` - group `reconcile: same-row grouping`.

`SyncEngine` receives only `SyncE2EKeyAccessor`, a
`Future<Uint8List> Function()`. `CredentialCodec` separately serializes and restores
`DeviceCredential`; it does not provide keys to the engine. This separation keeps the general
secret store and opaque credential payload outside the engine boundary. Source:
`packages/sync/lib/src/engine/sync_engine.dart` - `SyncE2EKeyAccessor`, `SyncEngine`;
`packages/sync/lib/src/credential/credential_codec.dart` - `CredentialCodec`.

## Navigation

This package layer has no routes, screens, back-stack behavior, or deep links. App-layer
orchestration and conflict-review UI remain outside `packages/sync`. Source:
`packages/sync/test/package_boundary_test.dart` - test
`packages/sync has no Flutter, dart:ui, Supabase-Flutter, or app imports`.

## APIs

- `SyncEngine.reconcile(envelopes)` returns an immutable `ReconcileResult` containing
  conflict-free `changes`, their exact `stamps`, `stagedConflicts`, and `winningInputIndex`.
  `winningInputIndex` maps each conflict-free `SyncRowID` to its winning envelope's index in the
  original input iterable; staged rows have no entry. Authentication failures throw
  `SyncPayloadDecryptionError`. Authenticated payload-shape or identity mismatches throw
  `SyncPayloadIdentityError`. Authentic bytes that the payload codec cannot read throw
  `PayloadDecodeError`. Source: `packages/sync/lib/src/engine/sync_engine.dart` -
  `SyncEngine.reconcile`, `ReconcileResult`, `SyncPayloadIdentityError`;
  `packages/sync/lib/src/crypto/sync_cipher.dart` - `SyncPayloadDecryptionError`;
  `packages/sync/lib/src/codec/payload_codec.dart` - `PayloadDecodeError`.
- `SyncEngine.encode(changes, versionSource)` returns push-ready `SyncEnvelope` values stamped
  with stored version vectors. It derives lifecycle from the change and throws
  `SyncUntrackedRowError` when the source has no row version. Source:
  `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine.encode`.
- `PullResponse.envelopes`, `cursor`, and `endOfSnapshot` are typed views of a pull-page wire
  response. `envelopes` decodes each item through `SyncEnvelope.fromWireJson` and returns an
  unmodifiable list; `cursor` is required; `endOfSnapshot` defaults to false when absent. Missing
  or malformed fields throw `FormatException`. Source:
  `packages/sync/lib/src/protocol/requests.dart` - `PullResponse`;
  `packages/sync/test/protocol/pull_response_test.dart` - group `PullResponse`.
- `PayloadCodec.encodeChange` and `PayloadCodec.decodeChange` implement payload version 1 for
  every domain upsert variant. Deletes encode as empty payloads, while decoding an empty,
  malformed, or unsupported payload throws `PayloadDecodeError`. Source:
  `packages/sync/lib/src/codec/payload_codec.dart` - `PayloadCodec`;
  `packages/sync/test/codec/payload_codec_test.dart` - groups `entity round-trip`, `tombstones`,
  and `malformed and unsupported payloads`.
- `SyncCipher.encrypt` creates an authenticated frame, and `SyncCipher.decrypt` authenticates an
  envelope ciphertext string before returning plaintext. Both require a 32-byte key. Source:
  `packages/sync/lib/src/crypto/sync_cipher.dart` - `SyncCipher.encrypt`, `SyncCipher.decrypt`.
- `SyncRowID.of(collection, rowID)` is the only public constructor. It normalizes row IDs and
  keeps identical IDs in different collections distinct. Source:
  `packages/sync/lib/src/engine/sync_row_id.dart` - `SyncRowID.of`;
  `packages/sync/test/engine/sync_engine_test.dart` - group
  `identical UUIDs in different collections`.
- `SyncVersionSource.readRowVersion(rowID)` is the engine's synchronous, single-row seam for
  reading exact stored versions. `refresh()` asynchronously reloads the versions backing that
  read. `InMemorySyncVersionSource` is the package test implementation and its `refresh()` is a
  no-op. Source: `packages/sync/lib/src/engine/version_source.dart` - `SyncVersionSource`,
  `InMemorySyncVersionSource`.
- `SyncStagingStore.stage`, `pendingConflicts`, and `resolve` define conflict persistence behavior.
  Staging replaces the group for the same collection and row, pending groups retain oldest-first
  order, and resolving an absent group is an idempotent no-op. `pendingConflictList()` is the
  asynchronous durable read behind `pendingConflicts`; `flush()` settles writes enqueued through
  the synchronous engine-path overrides. Source:
  `packages/sync/lib/src/engine/staging_store.dart` - `SyncStagingStore`,
  `InMemorySyncStagingStore`; `packages/sync/test/engine/staging_store_test.dart` - groups `stage`,
  `pendingConflicts`, and `resolve`.
- `CredentialCodec.export` and `CredentialCodec.restore` round-trip a `DeviceCredential` through
  an opaque payload. Once constructed or restored, the private bearer token does not appear in
  the exported value, `DeviceCredential.toString()`, or malformed-input error text. Source:
  `packages/sync/lib/src/credential/credential_codec.dart` - `CredentialCodec`;
  `packages/sync/test/engine/credential_codec_test.dart` - groups `round-trip` and `bearer opacity`.
- `collectionFor` and `deleteFor` are total across the 5 sync collections and all 11
  `LedgerChange` variants. Source: `packages/sync/lib/src/engine/sync_engine.dart` -
  `collectionFor`, `deleteFor`; `packages/sync/test/engine/sync_engine_test.dart` - group
  `LedgerChange-to-SyncCollection mapping`.

## Gotchas and invariants

- Each encryption uses XChaCha20-Poly1305 with a 256-bit key and a fresh 24-byte nonce from
  `Random.secure()`. The wire ciphertext is unpadded base64url over nonce, ciphertext, and the
  appended 16-byte authentication tag. Source: `packages/sync/lib/src/crypto/sync_cipher.dart` -
  `SyncCipher`, `SyncCipher._randomNonce`; `packages/sync/lib/src/engine/sync_engine.dart` -
  `SyncEngine._framePayload`; `packages/sync/test/crypto/sync_cipher_test.dart` - test
  `ciphertext is unpadded base64url of nonce + ciphertext + tag`.
- Authenticated associated data covers protocol version, user ID, collection, row ID, sibling ID,
  version vector, and lifecycle. It excludes ciphertext because the authentication tag already
  authenticates ciphertext. Any malformed base64url, short frame, modified ciphertext, or
  associated-data mismatch throws `SyncPayloadDecryptionError`, not a backend `SyncFailure`.
  Source: `packages/sync/lib/src/protocol/envelope.dart` - `SyncEnvelope.aadFields`,
  `SyncEnvelope.aadBytes`; `packages/sync/lib/src/crypto/sync_cipher.dart` -
  `SyncCipher.decrypt`; `packages/sync/test/crypto/sync_cipher_test.dart` - group
  `authentication`.
- Reconciliation computes the maximal elements of the version-vector partial order. A dominant
  member removes obsolete siblings even when an older pair was concurrent. A conflict contains
  only non-dominated frontier members. Source:
  `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine._nonDominatedFrontier`;
  `packages/sync/test/engine/sync_engine_test.dart` - tests
  `a dominant sibling resolves a group even with a concurrent pair` and
  `a strictly dominated sibling never reaches a staged conflict`.
- Equal version vectors collapse only when their decoded `LedgerChange` values match. Divergent
  live content, or live and tombstone content, under the same vector throws
  `SyncPayloadIdentityError` for either input order. Source:
  `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine._nonDominatedFrontier`;
  `packages/sync/test/engine/sync_engine_test.dart` - tests
  `divergent live content under an identical version vector throws, first-argument order`,
  `divergent live content under an identical version vector throws, reversed order`, and
  `a live sibling and a tombstone sibling sharing a version vector throws`.
- A live payload must decode to the envelope's collection and normalized row ID. Tombstone
  ciphertext is authenticated before its deletion is trusted, and authenticated non-empty
  tombstone plaintext throws `SyncPayloadIdentityError`. Source:
  `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine._decodeRow`;
  `packages/sync/test/engine/sync_engine_test.dart` - tests
  `an authenticated envelope decoding to another entity identity`,
  `an authenticated envelope whose entity ID does not match the row ID`,
  `a tampered tombstone envelope throws, not a silent delete`, and
  `an authenticated tombstone with a non-empty payload throws`.
- `StagedConflict` requires at least 2 siblings. Every sibling must share the group's collection
  and normalized row ID, and every sibling pair must be mutually concurrent. Construction copies
  the sibling list. Source: `packages/sync/lib/src/engine/staging_store.dart` - `StagedConflict`;
  `packages/sync/test/engine/staging_store_test.dart` - groups `validation`,
  `rowID normalization`, and `sibling list is defensive`.
- `SyncEngine.reconcile` can stage an earlier row group before a later row's equal-vector content
  mismatch throws. A thrown reconciliation can therefore coexist with staging side effects.
  Source: `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine.reconcile`,
  `SyncEngine._nonDominatedFrontier`.
- `SyncStagingStore.resolve` identifies a group only by collection and row ID. A resolution based
  on a stale view can remove a newer replacement group for the same row. Source:
  `packages/sync/lib/src/engine/staging_store.dart` - `InMemorySyncStagingStore.resolve`,
  `InMemorySyncStagingStore.stage`.
- `SyncEngine` defaults to `InMemorySyncStagingStore`, which provides no restart durability. A
  production caller must inject a durable `SyncStagingStore`. Source:
  `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine` constructor;
  `packages/sync/lib/src/engine/staging_store.dart` - `InMemorySyncStagingStore`.
- The package's `SyncVersionSource` exposes synchronous single-row reads for `encode()` and an
  asynchronous `refresh()` for its backing versions. It is separate from app-layer
  `CollectionVersionReader`, which asynchronously reads one whole collection for durable readback
  and push-candidate selection. Neither type implements or replaces the other. Source:
  `packages/sync/lib/src/engine/version_source.dart` - `SyncVersionSource.readRowVersion`,
  `SyncVersionSource.refresh`; `app/lib/sync/collection_version_reader.dart` -
  `CollectionVersionReader.readRowVersions`.
- `PullResponse` is the first repository definition of the pull-page response schema, but it is
  provisional. No deployed backend or SQL migration fixes its keys or semantics yet; lock the
  backend RPC signature with its SQL migration before treating the schema as deployed. Source:
  `packages/sync/lib/src/protocol/requests.dart` - `PullResponse`;
  `packages/sync/lib/src/backends/supabase_backend.dart` - `SupabaseSyncBackend`.
- `docs/sync-protocol.md` predates this engine and still describes deferred engine behavior. For
  this layer, current code and tests establish empty authenticated tombstone plaintext and
  non-dominated frontier reduction. Source: `docs/sync-protocol.md` -
  `3. Envelope schema and AAD binding`, `4. Operation contracts`;
  `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine._decodeRow`,
  `SyncEngine._nonDominatedFrontier`;
  `packages/sync/test/engine/sync_engine_test.dart` - group `reconcile: same-row grouping`.

## Requirements

- Keep `packages/sync` pure Dart and free of Flutter, `dart:ui`, Drift, Riverpod, app, and secure
  storage dependencies. Keep `cryptography` pinned to `2.9.0` and do not add
  `cryptography_flutter`. Source: `packages/sync/pubspec.yaml` - `dependencies`;
  `packages/sync/test/package_boundary_test.dart` - test
  `packages/sync has no Flutter, dart:ui, Supabase-Flutter, or app imports`.
- Authenticate every envelope, including tombstones, before accepting its lifecycle or identity.
  Bind every visible envelope field except ciphertext as authenticated associated data. Source:
  `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine._decodeRow`;
  `packages/sync/lib/src/protocol/envelope.dart` - `SyncEnvelope.aadBytes`.
- Preserve payload version 1 and the canonical codec for every upsert `LedgerChange`. Preserve
  empty payloads for deletes and reject unsupported or malformed payloads with
  `PayloadDecodeError`. Source: `packages/sync/lib/src/codec/payload_codec.dart` - `PayloadCodec`.
- Reduce each row group to its non-dominated frontier. Return a lone frontier member with its
  exact version stamp, and stage multiple mutually concurrent frontier members. Source:
  `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine.reconcile`,
  `SyncEngine._nonDominatedFrontier`.
- Reject equal-vector content divergence, envelope-to-payload identity mismatches, and non-empty
  tombstone plaintext with `SyncPayloadIdentityError`. Source:
  `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine._decodeRow`,
  `SyncEngine._nonDominatedFrontier`.
- Encode a local change only with its exact stored version. Throw `SyncUntrackedRowError` when the
  version source has no matching `SyncRowID`; never substitute `VersionVector.empty`. Source:
  `packages/sync/lib/src/engine/sync_engine.dart` - `SyncEngine.encode`;
  `packages/sync/test/engine/sync_engine_test.dart` - test
  `throws for a change whose row the version source never tracked`.
- Keep key retrieval behind `SyncE2EKeyAccessor`. Do not pass a general secret store or credential
  payload into `SyncEngine`. Source: `packages/sync/lib/src/engine/sync_engine.dart` -
  `SyncE2EKeyAccessor`, `SyncEngine`; `packages/sync/test/engine/sync_engine_test.dart` - group
  `scoped E2E key accessor`.
- Keep credential persistence separate from engine key access. Do not expose bearer tokens through
  exported values, stringification, or error messages. Source:
  `packages/sync/lib/src/credential/credential_codec.dart` - `CredentialCodec`;
  `packages/sync/lib/src/protocol/credential.dart` - `DeviceCredential.toString`;
  `packages/sync/test/engine/credential_codec_test.dart` - group `bearer opacity`.
