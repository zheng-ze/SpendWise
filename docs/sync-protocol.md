# Data sync contract and wire protocol

This document specifies the engine-agnostic, pure-Dart data-sync contract for SpendWise. It defines
the `SyncBackend` and `SyncAuthenticator` interfaces, one uniform encrypted sibling envelope, the
push/pull/reconcile/acknowledge operations, the canonical sibling-ID and snapshot-hash algorithms,
the HTTP mapping and error bodies, and the verification contract for those behaviors.

The pure-Dart `packages/sync` package and its Supabase RPC adapter implement the operation-major-2
transport described here. Device binding for protocol v2 is Supabase-only. The custom-endpoint
adapter retains a legacy bearer-only prototype transport and has no v2 binding support, so custom
endpoints are unsupported for v2 sync. Plaintext handling, encryption, conflict resolution, and
application-state integration remain outside the backend boundary.

Supported targets remain desktop and mobile. Web is not restored. Users who never opt into sync see
unchanged behavior. Device-local settings are never synced.

## 1. Package boundary and dependencies

This section records which package owns the sync protocol and which dependencies are permitted.

The `packages/sync` package is pure Dart with no Flutter dependency. A `pubspec.yaml` that
refuses a `flutter` import, like the domain package, enforces this boundary at compile time rather
than by convention. `packages/sync` declares exactly one intra-repository dependency: `domain`,
referenced by path, and uses it only for `normalizedID`. It never imports `app/lib` or any app-layer
code, and it never imports Flutter. The following matrices make these boundaries checkable.

**Package-boundary matrix.**

| Concern | Settled assignment | Notes |
|---|---|---|
| `VersionVector` and `VersionVectorDecodeError` | `packages/sync/lib/src/protocol/version_vector.dart` | Pure-Dart protocol ownership |
| `VersionVector` members relocated | `bump`, `dominates`, `isConcurrent`, `encode`, `decode`, `equality`, `hashCode`, `unchanged` | `merge` is not added and not relocated |
| `deviceID` / `_claimDeviceID` | Remain in `app/lib/persistence/` | Drift-bound device-identity claiming, not protocol |
| `normalizedID` | Imported from `domain` by path | Only intra-repository dependency |
| Public export surface | `VersionVector` and the sync interfaces re-exported through `package:sync/sync.dart` | App imports via `package:sync/sync.dart` |
| Flutter dependency | Excluded | Compile-enforced, no `flutter` import |
| `app/lib` dependency | Excluded | No app-layer import |
| Package boundary | Implemented in `packages/sync` | The current source and package boundary tests define the executable boundary |

**Why `VersionVector` moves but `deviceID` does not.** `VersionVector` carries causal-frontier
semantics (`dominates`, `isConcurrent`) that the sync contract consumes at its seam, so it belongs
with the protocol. `deviceID` and `_claimDeviceID` are Drift-bound device-identity claiming, not
protocol, so they stay in the app persistence layer. No `merge` method is added by this ticket;
`merge` stays scoped to a separately-owned client-side resolution-write step, which remains out of
scope here.

The Supabase adapter maps abstract operations to PostgREST RPCs. The custom-endpoint adapter
implements prototype calls against explicit endpoints, but has no v2 device-binding transport. A
future self-hosted server could implement the same `SyncBackend` interface after defining its own
binding contract.

## 2. SyncBackend and SyncAuthenticator Dart interfaces

This section defines the two Dart interfaces, the settled naming rules, the sealed reconcile
request variants, DTO and credential opacity, the typed `SyncOutcome` outcome type, and the
separation of coordinator and backend responsibilities. Every Dart API member is mapped to its wire
operation and wire field.

**Responsibility seam.** The sync coordinator owns encryption, decryption, staging, same-row
grouping, application of conflict-free state, lifecycle-triggered and on-demand orchestration, and
the end-to-end key, which comes from a separately-settled security protocol. `SyncBackend` owns
transport, wire codecs, cursors, retries, and typed backend outcomes. `SyncBackend` never encrypts
or decrypts and never inspects plaintext: it transports ciphertext plus AAD-bound visible metadata
only.

**Deletion test.** Removing `SyncBackend` would force each adapter to duplicate wire-protocol,
cursor, and retry logic separately, so it is load-bearing, not a pass-through. Folding
`SyncAuthenticator` into `SyncBackend` would leak Supabase OTP mechanics into the engine-agnostic
data contract, so the two are deliberately separate interfaces.

**Adapter variation.** `SyncBackend` permits multiple adapters, but only the Supabase RPC adapter
has a v2 binding transport. The custom-endpoint adapter remains a bearer-only prototype.
`SyncAuthenticator` separates Supabase's OTP flow from any future custom authentication mechanism.

**SyncBackend members.** `SyncBackend` exposes exactly four operations: `push`, `pull`,
`reconcile`, and `acknowledge`. Each returns a `Future<SyncOutcome<T>>` and each takes an opaque,
already-valid `SyncCredential` per call. Authentication never happens inside `SyncBackend`;
`SyncBackend` only ever presents a credential, and enrollment and refresh live exclusively in
`SyncAuthenticator`.

**SyncAuthenticator members.** `SyncAuthenticator` owns the backend-specific credential lifecycle
and exposes three provider-neutral Dart methods: `beginEnrollment(identifier)` returns
`SyncOutcome<AuthChallenge>`; `completeEnrollment(AuthChallenge, response)` returns
`SyncOutcome<DeviceCredential>`; `refreshCredential(DeviceCredential)` returns
`SyncOutcome<DeviceCredential>`. `AuthChallenge` and `response` are backend-defined opaque
payloads. `DeviceCredential` is opaque to `SyncBackend` callers and may be constructed or inspected
only by `SyncAuthenticator` implementations. Supabase represents an email OTP through its opaque
challenge. Its `refreshCredential` method currently returns `backend_unavailable`; routine bearer
reauthentication uses the ordinary begin and complete OTP methods. A future custom backend may
represent another authentication mechanism without altering `SyncBackend`.

**Naming rules.** Dart members and parameters use lowerCamelCase. Dart types use UpperCamelCase.
snake_case is confined to the wire format. This convention is enforced across the API and the wire
boundary, and analyzer checks verify it (see the verification specification).

**Sealed reconcile request.** `SyncBackend.reconcile` takes a sealed request type represented by the
`BeginReconcile` and `CompleteReconcile` variants, or an equivalent sealed representation, while
retaining one public `reconcile` method.

**SyncOutcome.** `SyncOutcome` is sealed and separates success from failure. Failures split into
retryable transport and rate-limit failures, credential failures, and protocol/conformance
failures. The settled failure names are `credential_expired`, `rate_limited`, `device_retired`,
`reconciliation_required`, `stale_or_invalid_proof`, `snapshot_hash_mismatch`, `protocol_unsupported`,
`device_authorization_required`, `incompatible_server`, `invalid_request`, `network_unavailable`,
and `backend_unavailable`. Machine-readable wire codes use snake_case and match these names.
`incompatible_server` is terminal when the client cannot parse a v2 response or receives that named
code; HTTP 426 maps to `protocol_unsupported`.

**Dart-to-wire mapping matrix.**

| Dart member / parameter | Wire operation / field | Notes |
|---|---|---|
| `SyncBackend.push(...)` | Supabase RPC `sync_push` (legacy custom prototype: `POST /v1/sync/push`) | Body carries sibling envelopes plus optional top-level `write_proof` |
| `SyncBackend.pull(...)` | Supabase RPC `sync_pull` (legacy custom prototype: `POST /v1/sync/pull`) | One collection, one cursor or reconciliation context per call |
| `SyncBackend.reconcile(...)` | Supabase RPCs `sync_begin_reconcile` / `sync_complete_reconcile` (legacy custom prototype: `POST /v1/sync/reconcile`) | Sealed `BeginReconcile` / `CompleteReconcile` |
| `SyncBackend.acknowledge(...)` | Supabase RPC `sync_acknowledge` (legacy custom prototype: `POST /v1/sync/acknowledge`) | One collection checkpoint per call |
| `beginEnrollment(identifier)` | enrollment wire step (backend-defined) | Returns opaque `AuthChallenge` |
| `completeEnrollment(challenge, response)` | enrollment wire step (backend-defined) | Returns opaque `DeviceCredential` |
| `refreshCredential(credential)` | refresh wire step (backend-defined) | Returns opaque `DeviceCredential` |
| `DeviceCredential` or `BoundDeviceCredential` | HTTPS `Authorization: Bearer` plus one binding header for Supabase v2 | Authorization-bearing Begin uses `X-SpendWise-Binding-Authorization`; bound operations use `X-SpendWise-Device-Secret` |
| `protocol_major` / `device_id` | Top-level RPC body fields | Supabase v2 sends numeric `protocol_major: 2` and the device ID on every RPC |
| `write_proof` (top-level, optional) | push body top-level string | Reconciliation proof, separate from the credential |
| `BeginReconcile` / `CompleteReconcile` | begin_reconcile / complete_reconcile messages | Sealed Dart variants of one `reconcile` method |
| `collection_hashes` | complete_reconcile field | Five digests, no combined digest |

**Coordination constraints.** `SyncBackend` assigns no plaintext, performs no encryption or
decryption, and owns no enrollment work. Enrollment, challenge handling, credential refresh, and the
end-to-end key all belong to `SyncAuthenticator` or the sync coordinator.

## 3. Envelope schema and AAD binding

This section defines one uniform sibling envelope, traces every field through wire JSON, storage
visibility, authenticated associated data, sibling identity, collection hashes, and server-assigned
cursor behavior, and fixes the closed lifecycle vocabulary.

**One envelope per sibling.** Every live and every tombstone sibling uses the same envelope shape.
Visible fields on the wire are protocol version, user ID, collection, row ID, sibling ID, version
vector, and lifecycle. The envelope also carries a base64url-encoded ciphertext and, on responses, a
server-assigned change position or timestamp. The encrypted plaintext owns the row content and the
display-only wall-clock timestamp; a tombstone sibling's plaintext contains a tombstone marker in
addition to that timestamp.

**Canonical collection identifiers.** The five canonical wire collection discriminators are
`money_sources`, `entries`, `categories`, `plans`, and `budgets`. They are used consistently across
cursors, sibling-ID input, authenticated associated data, reconciliation ordering, `collection_hashes`,
and the five corresponding backend tables. `money_sources` retains the shared `Account` and `Pocket`
ID space with no entity-kind discriminator. The backend never discriminates entity kind and never
reads plaintext; it treats envelopes as opaque ciphertext and resolves device identity only from the
credential.

**Lifecycle vocabulary.** Lifecycle is a closed two-value wire and storage vocabulary: the lowercase
ASCII strings `live` and `tombstone`. The identical value participates in authenticated associated
data. Any other value is `invalid_request`.

**Authenticated associated data.** XChaCha20-Poly1305 ciphertext authenticates protocol version,
user ID, collection, logical row ID, sibling ID, canonical version vector, and lifecycle as
associated data. A visible metadata mutation therefore causes client decryption failure, which
protects the integrity of the fields that identify and classify a sibling without encrypting them.

**Sibling identity.** Sibling ID is an unpadded base64url-encoded SHA-256 digest of RFC 8785
canonical UTF-8 JSON containing `user_id`, `collection`, `row_id`, and `version_vector`. A repeated
push of the same immutable sibling resolves to the same stable sibling ID, which makes retries and
concurrent siblings identifiable and dedupable.

**Server-assigned cursor behavior.** On responses the server assigns a monotonic, opaque, stable
change position (or timestamp) per envelope. The client may never use its own clock to influence
ordering, and the server alone assigns cursor positions.

**Schema-coverage matrix.** Every settled envelope field must appear consistently across storage
visibility, JSON, AAD, sibling identity, collection hashes, operation inputs, and operation
responses, and lifecycle must permit only `live` and `tombstone`.

| Field | Wire JSON | Storage visibility | AAD | Sibling ID | Collection hash | Operation I/O | Lifecycle values |
|---|---|---|---|---|---|---|---|
| `protocol_version` | present | stored, server-visible metadata | present | not hashed | object field | present | n/a |
| `user_id` | present | stored, server-visible metadata | present | input | object field | present | n/a |
| `collection` | present | stored, server-visible metadata | present | input | object field | present | n/a |
| `row_id` | present | stored, server-visible metadata | present | input | object field | present | n/a |
| `sibling_id` | present | stored, server-visible metadata | present | the digest | object field | response input | n/a |
| `version_vector` | present | stored, server-visible metadata | present | input | object field | present | n/a |
| `lifecycle` | present | stored, server-visible metadata | present | not hashed | object field | present | `live`, `tombstone` |
| `ciphertext` | present | opaque | n/a - authenticated by AEAD tag integrity, not AAD | not hashed | object field | present | n/a |
| server change position/timestamp | response only | server-assigned | n/a | n/a | n/a | response only | n/a |

**Collection hash field set.** Each collection-digest object contains only the AAD-bound metadata
fields plus ciphertext: `protocol_version`, `user_id`, `collection`, `row_id`, `sibling_id`,
`version_vector`, `lifecycle`, and `ciphertext`. No other field enters any collection digest, and
no combined snapshot digest is calculated.

## 4. Operation contracts

This section specifies push, per-collection pull, sealed begin and complete reconciliation, and
per-collection acknowledge as request/response/failure contracts. Each operation is a matrix that
enumerates the Dart request type, wire fields, success fields, applicable typed failures, recovery
action, authorization transport, call granularity, and atomicity boundary.

**Push.** `push` accepts batches of sibling envelopes and applies the non-dominated frontier update
atomically per logical row. It lets independent rows progress, and returns `applied`, `already_present`,
or `rejected` plus the resulting causal frontier for every submitted row. Callers therefore retry
only rejected or retryable rows. The push body carries an optional top-level `write_proof` string,
which is required for the first push after reconciliation and never replaces the `Bearer` credential.
A first post-reconciliation push that omits `write_proof`, or presents one that is expired, already
consumed, or bound to another device, returns `stale_or_invalid_proof`. A repeated push of the same
immutable sibling resolves to the same stable sibling ID; an already-dominated retry is ignored,
dominated stored siblings are removed, and concurrent siblings remain. The atomicity boundary is one
logical row, not the whole batch.

**Pull.** `pull` operates on exactly one named collection per call, advances through one opaque,
stable, server-assigned cursor, returns at most the requested page size up to the default maximum of
500 envelopes, and never permits a client clock to influence ordering. Clients may request a page
below the 500 default, and servers may return fewer entries. Pulled envelopes with the same
collection and logical row ID are grouped into staged sibling sets by the client; the client does
not prune the frontier after pull, and conflicting siblings never enter `LedgerState`. The returned
cursor only becomes durable once its page is staged and acknowledged, so a page received but not
yet staged and acknowledged must be retried from the last acknowledged durable checkpoint
(Acknowledge, per above), never from the received-but-unstaged page. Pull carries one cursor or
reconciliation context and one optional lower page limit.

**Reconcile.** `reconcile` is represented by the sealed `BeginReconcile` and `CompleteReconcile`
variants through one public method. `begin_reconcile` is device-scoped and returns a device-bound
reconciliation ID, a fixed snapshot watermark, an expiry, and context for ordinary per-collection
`pull` calls to page the full snapshot without normal cursors. After paging every collection,
`complete_reconcile` submits `collection_hashes` - an object containing exactly `money_sources`,
`entries`, `categories`, `plans`, and `budgets`, each mapped to its individual unpadded base64url
SHA-256 digest - and receives a single-use write-proof token only when all five match. The operation
supports the full-snapshot pull path, fixed watermark behavior, and the reconciliation gate shared
by a new device's first write and a retired device's reactivation.

**Acknowledge.** `acknowledge` records exactly one durable collection checkpoint per call after every
envelope through that checkpoint has been staged, so the server can derive tombstone observation
without per-sibling acknowledgement IDs. It persists a collection's pull-cursor checkpoint only
after complete staging through that checkpoint. Scheduled tombstone collection uses checkpoints from
every non-retired device to determine eligibility for hard deletion. Acknowledge carries one durable
checkpoint per call.

**Sync round.** A sync round iterates `money_sources`, `entries`, `categories`, `plans`, and
`budgets`, calling `pull` and `acknowledge` separately for each collection. Each collection keeps an
independent cursor.

**Operation-contract matrix: push.**

| Aspect | Contract |
|---|---|
| Dart request type | `Future<SyncOutcome<PushResult>> push(SyncCredential, List<Envelope>, {writeProof?})` |
| Wire fields | sibling envelope array; optional top-level `write_proof` string |
| Success fields | per-row `applied` / `already_present` / `rejected`, and resulting causal frontier per row |
| Applicable typed failures | `credential_expired`, `device_authorization_required`, `protocol_unsupported`, `incompatible_server`, `device_retired`, `reconciliation_required`, `stale_or_invalid_proof`, `rate_limited`, `network_unavailable`, `backend_unavailable`, `invalid_request` |
| Recovery action | supply `write_proof` on the first post-reconciliation push; retry only rejected rows |
| Authorization transport | Supabase v2: HTTPS `Authorization: Bearer` and `X-SpendWise-Device-Secret` headers |
| Call granularity | batch of siblings; atomicity per logical row |
| Atomicity boundary | one logical row per submitted row |

**Operation-contract matrix: pull.**

| Aspect | Contract |
|---|---|
| Dart request type | `Future<SyncOutcome<PullResult>> pull(SyncCredential, collection, {cursor, pageLimit?})` |
| Wire fields | one collection, one cursor or reconciliation context, one optional lower page limit |
| Success fields | page of envelopes, one server-assigned cursor advance, optional end-of-snapshot marker |
| Applicable typed failures | `credential_expired`, `device_authorization_required`, `protocol_unsupported`, `incompatible_server`, `device_retired`, `reconciliation_required`, `rate_limited`, `network_unavailable`, `backend_unavailable`, `invalid_request` |
| Recovery action | retry from the last acknowledged durable checkpoint, never a received-but-unstaged page; stage without pruning frontier; the returned cursor only becomes durable once staged and acknowledged |
| Authorization transport | Supabase v2: HTTPS `Authorization: Bearer` and `X-SpendWise-Device-Secret` headers |
| Call granularity | exactly one named collection per call |
| Atomicity boundary | none per call; page boundary only; default maximum 500 envelopes |

**Operation-contract matrix: begin_reconcile.**

| Aspect | Contract |
|---|---|
| Dart request type | `BeginReconcile` variant through `reconcile(SyncCredential, BeginReconcile)` |
| Wire fields | device-scoped reconciliation request |
| Success fields | device-bound reconciliation ID, fixed snapshot watermark, expiry, context |
| Applicable typed failures | `credential_expired`, `device_authorization_required`, `protocol_unsupported`, `incompatible_server`, `device_retired`, `rate_limited`, `network_unavailable`, `backend_unavailable`, `invalid_request` |
| Recovery action | page every collection under the context; retry on transport/backend failures |
| Authorization transport | Supabase v2: HTTPS `Authorization: Bearer` and either `X-SpendWise-Binding-Authorization` or `X-SpendWise-Device-Secret` |
| Call granularity | device-scoped, before per-collection pulls |
| Atomicity boundary | none; establishes device-bound context |

**Operation-contract matrix: complete_reconcile.**

| Aspect | Contract |
|---|---|
| Dart request type | `CompleteReconcile` variant through `reconcile(SyncCredential, CompleteReconcile)` |
| Wire fields | `collection_hashes` with exactly five digests, no combined digest |
| Success fields | single-use write-proof token (only when all five match) |
| Applicable typed failures | `credential_expired`, `device_authorization_required`, `protocol_unsupported`, `incompatible_server`, `device_retired`, `reconciliation_required`, `snapshot_hash_mismatch`, `stale_or_invalid_proof`, `rate_limited`, `network_unavailable`, `backend_unavailable`, `invalid_request` |
| Recovery action | on mismatch, re-page the named collection, recompute its digest, retry; supply `write_proof` on first post-reconcile push |
| Authorization transport | Supabase v2: HTTPS `Authorization: Bearer` and `X-SpendWise-Device-Secret` headers |
| Call granularity | after all five collection snapshots paged |
| Atomicity boundary | none; gates single-use proof consumption |

**Operation-contract matrix: acknowledge.**

| Aspect | Contract |
|---|---|
| Dart request type | `Future<SyncOutcome<AckResult>> acknowledge(SyncCredential, collection, checkpoint)` |
| Wire fields | one collection, one durable checkpoint |
| Success fields | durable checkpoint record |
| Applicable typed failures | `credential_expired`, `device_authorization_required`, `protocol_unsupported`, `incompatible_server`, `device_retired`, `reconciliation_required`, `rate_limited`, `network_unavailable`, `backend_unavailable`, `invalid_request` |
| Recovery action | re-stage through the checkpoint, then re-acknowledge |
| Authorization transport | Supabase v2: HTTPS `Authorization: Bearer` and `X-SpendWise-Device-Secret` headers |
| Call granularity | exactly one named collection per call |
| Atomicity boundary | none; durability boundary only |

**Reconciliation gate.** The reconciliation proof expires after 24 hours or any intervening account
write, whichever occurs first. This gate applies equally to a new device's first write and to a
retired device's reactivation. Local reconciliation never drops an unsynced local write and never
resurrects a garbage-collected row. Backend unavailability leaves unsynced local writes intact and
allows a later lifecycle-triggered or on-demand retry; sync introduces no persistent connection.

## 5. Canonical JSON, sibling-ID, and snapshot-hash algorithms

This section specifies canonical JSON, the sibling-ID algorithm with golden vectors, the
snapshot-hash algorithm with golden vectors, and the `collection_hashes` object shape. Canonical
JSON uses sorted object keys and no insignificant whitespace, so Dart, Supabase/Postgres, and custom
servers produce identical bytes and digests.

**Canonical JSON.** Object keys are sorted ascending by Unicode code point. No insignificant
whitespace appears between tokens. Numbers are not involved, because version-vector counters are
strings. The same rule applies to each collection-digest object, whose only fields are
`protocol_version`, `user_id`, `collection`, `row_id`, `sibling_id`, `version_vector`, `lifecycle`,
and `ciphertext`.

`VersionVector.encode`/`decode` are the unchanged local Drift-storage codec (integer counters) and
are unrelated to the wire protocol's own canonical JSON projection of a version vector, which uses
string counters per this section's canonical JSON rule. The wire projection is a new, separate
serialization that follow-on implementation adds; it is not a change to `VersionVector.encode`
itself.

**Sibling-ID algorithm.** Sibling ID is the unpadded base64url SHA-256 digest of the RFC 8785
canonical UTF-8 JSON containing `user_id`, `collection`, `row_id`, and `version_vector`. Keys are
sorted ascending (`collection`, `row_id`, `user_id`, `version_vector`). A change to any of
`user_id`, `collection`, `row_id`, or `version_vector` changes the digest, which makes each sibling
stable under repetition and sensitive to causal change.

**Sibling-ID golden vector 1.**

- Canonical JSON input (RFC 8785): `{"collection":"entries","row_id":"11111111-1111-1111-1111-111111111111","user_id":"22222222-2222-2222-2222-222222222222","version_vector":{"deviceA":"3"}}`
- SHA-256 digest, unpadded base64url: `XppaREBfNCVu4mlApnRPSkmvgYQrSnkb1HVcGW4QXj8`

**Sibling-ID golden vector 2 (a version-vector change changes the ID).**

- Canonical JSON input: `{"collection":"entries","row_id":"11111111-1111-1111-1111-111111111111","user_id":"22222222-2222-2222-2222-222222222222","version_vector":{"deviceA":"2"}}`
- SHA-256 digest, unpadded base64url: `jp7-ibI8If_KrX5yYK5t6evYCrcXXRQonT-fNICdYzo`

**Snapshot-hash algorithm.** Each collection digest is the unpadded base64url SHA-256 digest of the
RFC 8785 canonical UTF-8 JSON representing an array of that collection's envelope objects, sorted by
ascending `sibling_id` using bytewise ordering over the base64url string. Each object contains only
the AAD-bound metadata fields plus ciphertext. A collection with no envelopes hashes the canonical
empty array `[]`, and its key is still present in `collection_hashes`, never omitted.

**Collection-hash golden vector (entries, two siblings, sorted by sibling_id bytewise).**

- Envelope A: sibling_id `XppaREBfNCVu4mlApnRPSkmvgYQrSnkb1HVcGW4QXj8`, lifecycle `live`, ciphertext `Y2lwaGVydHh4MT0=`, version_vector `{"deviceA":"3"}`
- Envelope B: sibling_id `jp7-ibI8If_KrX5yYK5t6evYCrcXXRQonT-fNICdYzo`, lifecycle `tombstone`, ciphertext `Y2lwaGVydHh4MjA=`, version_vector `{"deviceA":"2"}`
- Bytewise order over base64url: A before B
- Canonical array input (RFC 8785, compact, keys sorted ascending by code point): `[{"ciphertext":"Y2lwaGVydHh4MT0=","collection":"entries","lifecycle":"live","protocol_version":1,"row_id":"11111111-1111-1111-1111-111111111111","sibling_id":"XppaREBfNCVu4mlApnRPSkmvgYQrSnkb1HVcGW4QXj8","user_id":"22222222-2222-2222-2222-222222222222","version_vector":{"deviceA":"3"}},{"ciphertext":"Y2lwaGVydHh4MjA=","collection":"entries","lifecycle":"tombstone","protocol_version":1,"row_id":"11111111-1111-1111-1111-111111111111","sibling_id":"jp7-ibI8If_KrX5yYK5t6evYCrcXXRQonT-fNICdYzo","user_id":"22222222-2222-2222-2222-222222222222","version_vector":{"deviceA":"2"}}]`
- SHA-256 digest, unpadded base64url: `YHj5efH6cb6_AqustEQ5q4O2Wy5uQjnyxMv0ANqbQIU`

**Empty-collection golden vector (all-empty first-sync reconciliation).**

- Canonical JSON input: `[]`
- SHA-256 digest, unpadded base64url: `T1PNoYwrqgwDVLtfmj7L5e0Sq02OEbqHPC8RFhICuUU`

**Collection-hash golden vectors (four single-collection empty cases).** Each of the four
collections not otherwise enumerated hashes the same empty canonical array, since an all-empty
first-sync reconciliation carries no envelopes for any single collection. The canonical JSON input
is `[]` and the digest is `T1PNoYwrqgwDVLtfmj7L5e0Sq02OEbqHPC8RFhICuUU` for every one.

- **money_sources empty collection.** Canonical JSON input: `[]`. SHA-256 digest, unpadded base64url: `T1PNoYwrqgwDVLtfmj7L5e0Sq02OEbqHPC8RFhICuUU`.
- **categories empty collection.** Canonical JSON input: `[]`. SHA-256 digest, unpadded base64url: `T1PNoYwrqgwDVLtfmj7L5e0Sq02OEbqHPC8RFhICuUU`.
- **plans empty collection.** Canonical JSON input: `[]`. SHA-256 digest, unpadded base64url: `T1PNoYwrqgwDVLtfmj7L5e0Sq02OEbqHPC8RFhICuUU`.
- **budgets empty collection.** Canonical JSON input: `[]`. SHA-256 digest, unpadded base64url: `T1PNoYwrqgwDVLtfmj7L5e0Sq02OEbqHPC8RFhICuUU`.

**collection_hashes shape**. `complete_reconcile` submits `collection_hashes`, an object containing
exactly `money_sources`, `entries`, `categories`, `plans`, and `budgets`, each mapped to its
individual unpadded base64url SHA-256 digest. No combined digest is calculated. The per-collection
golden vectors (including the empty-collection vector that covers a new device's all-empty first
sync) are enumerated as part of the verification specification, and all five follow this identical
algorithm in ascending fixed order.

## 6. HTTP mapping and error bodies

This section specifies the Supabase v2 RPC transport, the legacy custom-endpoint paths,
protocol-major behavior, wire naming, authorization, status mapping, error bodies, lifecycle
rejection, and the separation of `write_proof` from credentials.

**Endpoints.** The custom-endpoint prototype exposes four `POST` paths: `/v1/sync/push`,
`/v1/sync/pull`, `/v1/sync/reconcile`, and `/v1/sync/acknowledge`. These operations define behavior
directly rather than exposing PostgREST table resources. The Supabase v2 adapter calls
`sync_push`, `sync_pull`, `sync_begin_reconcile`, `sync_complete_reconcile`, and `sync_acknowledge`
through `/rest/v1/rpc/`. The custom-endpoint prototype has no v2 binding contract; custom
endpoint v2 sync is unsupported.

**Protocol major.** Every Supabase RPC request body carries numeric `protocol_major: 2` and
`device_id`. Binding start and verify request and response bodies also carry numeric
`protocol_major: 2`; their response decoders reject missing or other values. The Supabase v2 RPC
success contract includes `protocol_major: 2`, but the current generic RPC response wrappers do not
validate that field. The operation major is separate from the encrypted envelope's AAD-bound
`protocol_version: 1`. A missing or unsupported operation major receives HTTP 426
`protocol_unsupported`. Clients do not negotiate, downgrade, omit binding proof, or retry with v1
fields. HTTP 426 remains `protocol_unsupported`; an unparseable v2 response or an explicit
`incompatible_server` code maps to terminal `incompatible_server`.

**Wire naming.** Wire documents use snake_case field names, base64url ciphertext, RFC 3339 UTC
timestamps, string version-vector counters, and exactly one declared protocol major version.

**Authorization.** Every Supabase v2 RPC sends `Authorization: Bearer <jwt>` and exactly one
binding header. Authorization-bearing `sync_begin_reconcile` sends
`X-SpendWise-Binding-Authorization` with a `DeviceCredential`; bound Begin and all other RPCs send
`X-SpendWise-Device-Secret` with a `BoundDeviceCredential`. The adapter rejects mismatched
credential and operation modes before HTTP dispatch. `SupabaseDeviceBindingAuthorizer` uses the
anonymous gateway bearer and `apikey` for its start and verify calls, before a user bearer or
device secret exists. Enrollment and refresh stay outside `SyncBackend`. The optional top-level
`write_proof` is a separate reconciliation proof and never replaces either credential header.

**Lifecycle rejection.** Any lifecycle value other than `live` or `tombstone` produces
`invalid_request`.

**Success mapping.** Every completed `push`, `pull`, `reconcile`, and `acknowledge` call returns
HTTP 200.

**Failure status mapping.**

| Code | Failure | Recovery |
|---|---|---|
| 400 | `invalid_request` | fix the malformed document or lifecycle value |
| 401 | `credential_expired` | obtain a new bearer through routine session reauthentication; retain the device secret |
| 403 | `device_retired` or `reconciliation_required` | retire/reactivate flow, or begin reconciliation first |
| 409 | `stale_or_invalid_proof` or `snapshot_hash_mismatch` | supply/reuse proof correctly, or re-page the named collection |
| 426 | `protocol_unsupported` | upgrade to major 2; never retry with v1 fields or without binding proof |
| 428 | `device_authorization_required` | obtain a new binding authorization, then use authorization-bearing Begin and full reconciliation |
| 429 | `rate_limited` | honor the HTTP `Retry-After` header |
| 503 | `backend_unavailable` | retain local writes, retry on lifecycle or on demand |

`incompatible_server` is a terminal client outcome for an unparseable v2 success response or an
explicit named error code. It has no dedicated HTTP status row. `network_unavailable` is a client
transport outcome from a caught request exception, not the HTTP 503 mapping.

**Error-body fields.** The client reads `failure_code` first and falls back to `code`; it also reads
`message` where present. The public RPC failure contract uses a machine-readable failure code and
message. The client parses rate-limit delay from the HTTP `Retry-After` header.
`snapshot_hash_mismatch` includes `mismatched_collection`, selected as the first differing
collection in fixed order `money_sources`, `entries`, `categories`, `plans`, `budgets`.
`network_unavailable` and `backend_unavailable` are retryable and leave unsynced local writes
intact.

**Retired-device reactivation.** A retired device cannot resume ordinary bound operations.
Authorization-bearing Begin with a fresh binding authorization can reactivate it and issue a new
device secret. The device must complete full reconciliation before writes resume. The in-memory
binding emulator rejects ordinary bound Begin on a retired device and clears retirement only in
authorization-bearing Begin.

**Reconciliation mismatch recovery.** The server compares `collection_hashes` in fixed order
`money_sources`, `entries`, `categories`, `plans`, `budgets`. The first difference returns HTTP 409
`snapshot_hash_mismatch` with `mismatched_collection` naming that collection; no combined snapshot
digest exists. The client then re-pages the named mismatched collection under the same
reconciliation context, recomputes its digest, and retries `CompleteReconcile`.

## 7. Verification specification

This section names the pure-Dart, adapter-contract, server, analyzer, canonicalization, causality,
cursor, authentication, reconciliation, lifecycle, proof, snapshot-mismatch, and failure cases
the implementation must cover. This protocol v2 documentation update is reviewed against the
shipped package and adapter code; it does not run runtime tests.

**Document-level verification.** Review each of the seven required sections for completeness and
cross-section consistency. Verify that `docs/ARCHITECTURE.md` carries one layer or roadmap
cross-reference to `docs/sync-protocol.md`, that the design is reachable through
`docs/NAVIGATION.md`'s required reading order, and that no `docs/knowledge` entry is added.

**Operation-contract matrices.** Verify that push, pull, begin_reconcile, complete_reconcile, and
acknowledge each enumerate Dart request types, wire fields, success fields, applicable typed
failures, recovery action, authorization transport, call granularity, and atomicity boundary.
Check that every Supabase v2 operation sends the bearer, numeric `protocol_major: 2`, `device_id`,
and exactly one binding header appropriate to its mode.

**Authentication-contract matrix.** Verify that beginEnrollment, completeEnrollment, and
refreshCredential each expose DTO opacity, ownership, success types, challenge failures, rate
limiting, backend unavailability, and separation from `SyncBackend`.

**Package-boundary matrix.** Verify that `VersionVector` and `VersionVectorDecodeError` live in
`packages/sync/lib/src/protocol/version_vector.dart`, that `deviceID` and `_claimDeviceID` stay with
Drift, that the only `domain` path dependency is `normalizedID`, that `VersionVector` is exposed
through `package:sync/sync.dart`, and that `packages/sync` imports neither Flutter nor `app/lib`.

**Schema-coverage matrix.** Prove that every settled envelope field appears consistently in storage,
JSON, AAD, sibling identity, collection hashes, operation inputs, and operation responses, and that
lifecycle permits only `live` and `tombstone`.

**Sibling-ID golden vectors.** The future `packages/sync` pure-Dart test layer and matching server
contract suites must agree that identical RFC 8785 input yields the same unpadded base64url SHA-256
value, while a change to `user_id`, `collection`, `row_id`, or `version_vector` changes the ID.
Document at least one concrete worked example (actual JSON input, actual digest output).

**Reconciliation-hash golden vectors.** Specify one golden vector per canonical collection, each
including the input envelope array, ascending bytewise sibling_id order, exact AAD-bound metadata
plus ciphertext field set, RFC 8785 canonical bytes, and expected unpadded base64url SHA-256
digest. Include one empty-collection golden vector giving the RFC 8785 bytes of `[]` and its
expected unpadded base64url SHA-256 digest, covering a new device's all-empty first-sync
reconciliation. Document concrete worked examples, not just descriptions.

**complete_reconcile golden case.** The `collection_hashes` object contains all five canonical keys
and no combined digest. Add mismatch cases for every collection proving fixed-order comparison, HTTP
409, `snapshot_hash_mismatch`, machine-readable `mismatched_collection`, re-paging of that
collection, and successful retry.

**Wire-codec golden cases.** At the pure-Dart package test layer, verify wire naming, base64url
ciphertext and digests, RFC 3339 UTC timestamps, string counters, the five exact collection strings,
numeric operation `protocol_major: 2` in request and binding response bodies, envelope
`protocol_version: 1`, `live` and `tombstone` lifecycle acceptance, and rejection of malformed
documents or any other lifecycle value. Check that an unparseable Supabase RPC success becomes
terminal `incompatible_server`; the current generic RPC wrappers do not inspect the returned
`protocol_major` field.

**Dart API and analyzer checks.** Verify the settled member, parameter, and type naming
conventions, sealed reconcile variants, public export through `package:sync/sync.dart`, absence of
Flutter or `app` imports, and compatibility with the repository's zero-issue analyzer requirement.

**Dart-to-wire mapping tests.** Map each Dart API element to its wire operation and field so naming
conventions do not leak across the interface boundary.

**Adapter contract cases.** Verify Supabase v2 binding mode selection, per-row frontiers,
per-collection cursor progression, checkpoint acknowledgement, reconciliation gates, and
authentication boundaries. Custom endpoint v2 remains unsupported until it has a binding
contract; do not assert v2 parity with the bearer-only prototype.

**Causal-frontier cases.** Non-dominated insertion, dominated retry, domination-based deletion,
concurrent retention, stable retry identity, `applied`, `already_present`, `rejected`, partial batch
rejection, and independent-row progress.

**Push-proof cases.** Omission on ordinary pushes, required presence on the first post-reconciliation
push, success and consumption, absence, expiry, reuse, device mismatch, intervening-write
invalidation, and continued independent bearer and device-secret authorization.

**Pull and acknowledgement boundary cases.** One collection per call, empty pages, fewer-than-limit
pages, the 500-envelope default maximum, lower requested limits, independent collection cursors,
repeated pages, staging-before-acknowledgement, and server-only cursor assignment.

**Reconciliation state-table cases.** BeginReconcile, snapshot context, all five per-collection
snapshot pulls, fixed watermark behavior, collection_hashes completion, single-use proof consumption,
a new device before and after reconciliation, retirement after 90 or more days, reactivation through
authorization-bearing Begin and full reconciliation, the 24-hour expiry, invalidation by an
intervening write, snapshot_hash_mismatch recovery, preservation of unsynced local writes, and
prevention of garbage-collected-row resurrection.

**HTTP mapping cases.** HTTP 200 for completed calls, 400 `invalid_request`, 401
`credential_expired` with bearer-only reauthentication, 403 `device_retired` and
`reconciliation_required`, 409 `stale_or_invalid_proof` and `snapshot_hash_mismatch` with
`mismatched_collection`, 426 `protocol_unsupported` without downgrade, 428
`device_authorization_required` with binding repair, 429 `rate_limited` with `Retry-After`, and
retryable 503 `backend_unavailable`. Check transport-exception `network_unavailable` and terminal
`incompatible_server` separately because neither has a dedicated HTTP status.

**Failure-body coverage.** Verify `failure_code` or `code` and `message` on server errors,
`mismatched_collection` on snapshot mismatch, and `Retry-After` on rate limiting. Every method must
document which failures apply and the caller's required recovery action.
