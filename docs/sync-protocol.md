# Data sync contract and wire protocol

This document specifies the engine-agnostic, pure-Dart data-sync contract for SpendWise. It defines
the `SyncBackend` and `SyncAuthenticator` interfaces, one uniform encrypted sibling envelope, the
push/pull/reconcile/acknowledge operations, the canonical sibling-ID and snapshot-hash algorithms,
the HTTP mapping and error bodies, and the test contract a future implementation must satisfy.

This is a design contract only. It produces no executable code, no `packages/sync` package, no
backend adapter, no server endpoint, and no database change. Those belong to follow-on
implementation work. The contract makes a Supabase adapter and a custom-endpoint adapter
behaviorally interchangeable while leaving plaintext handling, encryption, conflict resolution, and
application-state integration outside the backend boundary.

Supported targets remain desktop and mobile. Web is not restored. Users who never opt into sync see
unchanged behavior. Device-local settings are never synced.

## 1. Package boundary and dependencies

This section records, for follow-on implementation work, exactly which package owns what and which
dependencies are permitted. The settled destinations are documented here even though no move happens
in ticket #85; the ticket records the contract only.

The new package `packages/sync` is pure Dart with no Flutter dependency. A `pubspec.yaml` that
refuses a `flutter` import, like the domain package, enforces this boundary at compile time rather
than by convention. `packages/sync` declares exactly one intra-repository dependency: `domain`,
referenced by path, and uses it only for `normalizedID`. It never imports `app/lib` or any app-layer
code, and it never imports Flutter. The following matrices make these boundaries checkable.

**Package-boundary matrix.**

| Concern | Settled assignment | Notes |
|---|---|---|
| `VersionVector` and `VersionVectorDecodeError` | Relocate unchanged to `packages/sync/lib/src/version_vector.dart` | Move is follow-on work, not performed by this ticket |
| `VersionVector` members relocated | `bump`, `dominates`, `isConcurrent`, `encode`, `decode`, `equality`, `hashCode`, `unchanged` | `merge` is not added and not relocated |
| `deviceID` / `_claimDeviceID` | Remain in `app/lib/persistence/` | Drift-bound device-identity claiming, not protocol |
| `normalizedID` | Imported from `domain` by path | Only intra-repository dependency |
| Public export surface | `VersionVector` and the sync interfaces re-exported through `package:sync/sync.dart` | App imports via `package:sync/sync.dart` |
| Flutter dependency | Excluded | Compile-enforced, no `flutter` import |
| `app/lib` dependency | Excluded | No app-layer import |
| All relocations | Deferred to follow-on implementation | Ticket #85 records this only |

**Why `VersionVector` moves but `deviceID` does not.** `VersionVector` carries causal-frontier
semantics (`dominates`, `isConcurrent`) that the sync contract consumes at its seam, so it belongs
with the protocol. `deviceID` and `_claimDeviceID` are Drift-bound device-identity claiming, not
protocol, so they stay in the app persistence layer. No `merge` method is added by this ticket;
`merge` stays scoped to a separately-owned client-side resolution-write step, which remains out of
scope here.

The design also records, for follow-on work, the two required adapter implementations and a possible
third. A Supabase adapter maps the abstract operations to managed Postgres and PostgREST behavior.
A custom-endpoint adapter implements the same operation contract against explicit endpoints. A
future self-hosted server is a plausible third implementation behind the same interface, consuming
the same `SyncBackend` data contract without being designed here.

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

**Adapter variation.** A Supabase adapter and a custom-endpoint adapter are both required, and a
possible future self-hosted server is a plausible third implementation behind the same interface.
`SyncAuthenticator` exposes a real confirmed variation: Supabase's OTP flow versus a custom
endpoint's own auth mechanism (API key, none, or something else).

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
challenge; a custom backend may represent an API-key exchange or no challenge at all without
altering `SyncBackend`.

**Naming rules.** Dart members and parameters use lowerCamelCase. Dart types use UpperCamelCase.
snake_case is confined to the wire format. This convention is enforced across the API and the wire
boundary, and future analyzer checks verify it (see the deferred test specification).

**Sealed reconcile request.** `SyncBackend.reconcile` takes a sealed request type represented by the
`BeginReconcile` and `CompleteReconcile` variants, or an equivalent sealed representation, while
retaining one public `reconcile` method.

**SyncOutcome.** `SyncOutcome` is sealed and separates success from failure. Failures split into
retryable transport and rate-limit failures, credential failures, and protocol/conformance
failures. The settled failure names are `credential_expired`, `rate_limited`, `device_retired`,
`reconciliation_required`, `stale_or_invalid_proof`, `snapshot_hash_mismatch`, `protocol_unsupported`,
and `invalid_request`. Machine-readable wire codes use snake_case and match these names.

**Dart-to-wire mapping matrix.**

| Dart member / parameter | Wire operation / field | Notes |
|---|---|---|
| `SyncBackend.push(...)` | `POST /v1/sync/push` | Body carries sibling envelopes plus optional top-level `write_proof` |
| `SyncBackend.pull(...)` | `POST /v1/sync/pull` | One collection, one cursor or reconciliation context per call |
| `SyncBackend.reconcile(...)` | `POST /v1/sync/reconcile` | Sealed `BeginReconcile` / `CompleteReconcile` |
| `SyncBackend.acknowledge(...)` | `POST /v1/sync/acknowledge` | One collection checkpoint per call |
| `beginEnrollment(identifier)` | enrollment wire step (backend-defined) | Returns opaque `AuthChallenge` |
| `completeEnrollment(challenge, response)` | enrollment wire step (backend-defined) | Returns opaque `DeviceCredential` |
| `refreshCredential(credential)` | refresh wire step (backend-defined) | Returns opaque `DeviceCredential` |
| opaque `SyncCredential` | HTTPS `Authorization: Bearer` header only | Never sent as body field; never replaced by `write_proof` |
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
| `protocol_version` | present | not stored | present | not hashed | object field | present | n/a |
| `user_id` | present | not stored | present | input | object field | present | n/a |
| `collection` | present | not stored | present | input | object field | present | n/a |
| `row_id` | present | not stored | present | input | object field | present | n/a |
| `sibling_id` | present | not stored | present | the digest | object field | response input | n/a |
| `version_vector` | present | not stored | present | input | object field | present | n/a |
| `lifecycle` | present | not stored | present | not hashed | object field | present | `live`, `tombstone` |
| `ciphertext` | present | opaque | present | not hashed | object field | present | n/a |
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
not prune the frontier after pull, and conflicting siblings never enter `LedgerState`. Pull carries
one cursor or reconciliation context and one optional lower page limit.

**Reconcile.** `reconcile` is represented by the sealed `BeginReconcile` and `CompleteReconcile`
variants through one public method. `begin_reconcile` is device-scoped and returns a device-bound
reconciliation ID, a fixed snapshot watermark, an expiry, and context for ordinary per-collection
`pull` calls to page the full snapshot without normal cursors. After paging every collection,
`complete_reconcile` submits `collection_hashes` — an object containing exactly `money_sources`,
`entries`, `categories`, `plans`, and `budgets`, each mapped to its individual unpadded base64url
SHA-256 digest — and receives a single-use write-proof token only when all five match. The operation
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
| Dart request type | `Future<SyncOutcome<PushResult>> push(SyncCredential, List<Envelope>, {write_proof?})` |
| Wire fields | sibling envelope array; optional top-level `write_proof` string |
| Success fields | per-row `applied` / `already_present` / `rejected`, and resulting causal frontier per row |
| Applicable typed failures | `stale_or_invalid_proof`, `invalid_request` |
| Recovery action | supply `write_proof` on the first post-reconciliation push; retry only rejected rows |
| Authorization transport | HTTPS `Authorization: Bearer` header |
| Call granularity | batch of siblings; atomicity per logical row |
| Atomicity boundary | one logical row per submitted row |

**Operation-contract matrix: pull.**

| Aspect | Contract |
|---|---|
| Dart request type | `Future<SyncOutcome<PullResult>> pull(SyncCredential, collection, {cursor, pageLimit?})` |
| Wire fields | one collection, one cursor or reconciliation context, one optional lower page limit |
| Success fields | page of envelopes, one server-assigned cursor advance, optional end-of-snapshot marker |
| Applicable typed failures | `reconciliation_required`, `credential_expired`, `rate_limited`, `network_unavailable`, `backend_unavailable`, `invalid_request` |
| Recovery action | advance the opaque cursor on retry; stage without pruning frontier |
| Authorization transport | HTTPS `Authorization: Bearer` header |
| Call granularity | exactly one named collection per call |
| Atomicity boundary | none per call; page boundary only; default maximum 500 envelopes |

**Operation-contract matrix: begin_reconcile.**

| Aspect | Contract |
|---|---|
| Dart request type | `BeginReconcile` variant through `reconcile(SyncCredential, BeginReconcile)` |
| Wire fields | device-scoped reconciliation request |
| Success fields | device-bound reconciliation ID, fixed snapshot watermark, expiry, context |
| Applicable typed failures | `credential_expired`, `device_retired`, `rate_limited`, `network_unavailable`, `backend_unavailable` |
| Recovery action | page every collection under the context; retry on transport/backend failures |
| Authorization transport | HTTPS `Authorization: Bearer` header |
| Call granularity | device-scoped, before per-collection pulls |
| Atomicity boundary | none; establishes device-bound context |

**Operation-contract matrix: complete_reconcile.**

| Aspect | Contract |
|---|---|
| Dart request type | `CompleteReconcile` variant through `reconcile(SyncCredential, CompleteReconcile)` |
| Wire fields | `collection_hashes` with exactly five digests, no combined digest |
| Success fields | single-use write-proof token (only when all five match) |
| Applicable typed failures | `snapshot_hash_mismatch`, `stale_or_invalid_proof`, `credential_expired`, `device_retired`, `rate_limited`, `network_unavailable`, `backend_unavailable` |
| Recovery action | on mismatch, re-page the named collection, recompute its digest, retry; supply `write_proof` on first post-reconcile push |
| Authorization transport | HTTPS `Authorization: Bearer` header |
| Call granularity | after all five collection snapshots paged |
| Atomicity boundary | none; gates single-use proof consumption |

**Operation-contract matrix: acknowledge.**

| Aspect | Contract |
|---|---|
| Dart request type | `Future<SyncOutcome<AckResult>> acknowledge(SyncCredential, collection, checkpoint)` |
| Wire fields | one collection, one durable checkpoint |
| Success fields | durable checkpoint record |
| Applicable typed failures | `credential_expired`, `device_retired`, `rate_limited`, `network_unavailable`, `backend_unavailable`, `invalid_request` |
| Recovery action | re-stage through the checkpoint, then re-acknowledge |
| Authorization transport | HTTPS `Authorization: Bearer` header |
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
- Canonical array input (RFC 8785, compact, keys sorted): `[{"collection":"entries","ciphertext":"Y2lwaGVydHh4MT0=","lifecycle":"live","protocol_version":1,"row_id":"11111111-1111-1111-1111-111111111111","sibling_id":"XppaREBfNCVu4mlApnRPSkmvgYQrSnkb1HVcGW4QXj8","user_id":"22222222-2222-2222-2222-222222222222","version_vector":{"deviceA":"3"}},{"collection":"entries","ciphertext":"Y2lwaGVydHh4MjA=","lifecycle":"tombstone","protocol_version":1,"row_id":"11111111-1111-1111-1111-111111111111","sibling_id":"jp7-ibI8If_KrX5yYK5t6evYCrcXXRQonT-fNICdYzo","user_id":"22222222-2222-2222-2222-222222222222","version_vector":{"deviceA":"2"}}]`
- SHA-256 digest, unpadded base64url: `6H-4u1cu24BArfI200LO-tAi5hC59q_wRnTy_h1OpXw`

**Empty-collection golden vector (all-empty first-sync reconciliation).**

- Canonical JSON input: `[]`
- SHA-256 digest, unpadded base64url: `T1PNoYwrqgwDVLtfmj7L5e0Sq02OEbqHPC8RFhICuUU`

**collection_hashes shape.** `complete_reconcile` submits `collection_hashes`, an object containing
exactly `money_sources`, `entries`, `categories`, `plans`, and `budgets`, each mapped to its
individual unpadded base64url SHA-256 digest. No combined digest is calculated. The per-collection
golden vectors (including the empty-collection vector that covers a new device's all-empty first
sync) are enumerated as part of the deferred test specification, and all five follow this identical
algorithm in ascending fixed order.

## 6. HTTP mapping and error bodies

This section specifies the four fixed endpoint paths, protocol-major behavior, wire naming, Bearer
authorization, the exact success and failure status mapping, the generic error-body fields, lifecycle
rejection, and the separation of `write_proof` from credentials.

**Endpoints.** The custom endpoint exposes exactly four paths, all `POST`: `/v1/sync/push`,
`/v1/sync/pull`, `/v1/sync/reconcile`, and `/v1/sync/acknowledge`. These operations define behavior
directly rather than exposing PostgREST table resources. The Supabase adapter maps the same abstract
operations to managed Postgres and PostgREST behavior behind the same interface.

**Protocol major.** Every request declares exactly one protocol major. An unsupported major returns
HTTP 426 with the typed `protocol_unsupported` failure naming the supported majors. There is no
range negotiation, no downgrade, and no reinterpretation.

**Wire naming.** Wire documents use snake_case field names, base64url ciphertext, RFC 3339 UTC
timestamps, string version-vector counters, and exactly one declared protocol major version.

**Authorization.** Every data call sends the credential only as an HTTPS `Authorization: Bearer`
header. Enrollment and refresh never occur inside `SyncBackend`. The optional top-level `write_proof`
string is a reconciliation proof, separate from the opaque credential, and never replaces the
`Bearer` header.

**Lifecycle rejection.** Any lifecycle value other than `live` or `tombstone` produces
`invalid_request`.

**Success mapping.** Every completed `push`, `pull`, `reconcile`, and `acknowledge` call returns
HTTP 200.

**Failure status mapping.**

| Code | Failure | Recovery |
|---|---|---|
| 400 | `invalid_request` | fix the malformed document or lifecycle value |
| 401 | `credential_expired` | call `SyncAuthenticator.refreshCredential`, then retry |
| 403 | `device_retired` or `reconciliation_required` | retire/reactivate flow, or begin reconciliation first |
| 409 | `stale_or_invalid_proof` or `snapshot_hash_mismatch` | supply/reuse proof correctly, or re-page the named collection |
| 426 | `protocol_unsupported` | upgrade to a supported major; no negotiation |
| 429 | `rate_limited` | honor `retry_after_seconds` |
| 503 | `network_unavailable` or `backend_unavailable` | retain local writes, retry on lifecycle or on demand |

**Error-body fields.** Every error body contains `code` and `message`, plus `retry_after_seconds`,
`credential_action`, or `mismatched_collection` where applicable. `credential_expired` directs
`SyncAuthenticator.refreshCredential`. `rate_limited` carries `retry_after_seconds`.
`snapshot_hash_mismatch` includes `mismatched_collection`, selected as the first differing
collection in fixed order `money_sources`, `entries`, `categories`, `plans`, `budgets`.
`network_unavailable` and `backend_unavailable` are retryable and leave unsynced local writes
intact.

**Reconciliation mismatch recovery.** The server compares `collection_hashes` in fixed order
`money_sources`, `entries`, `categories`, `plans`, `budgets`. The first difference returns HTTP 409
`snapshot_hash_mismatch` with `mismatched_collection` naming that collection; no combined snapshot
digest exists. The client then re-pages the named mismatched collection under the same
reconciliation context, recomputes its digest, and retries `CompleteReconcile`.

## 7. Deferred test specification

This section names the pure-Dart, adapter-contract, server, analyzer, canonicalization, causality,
cursor, authentication, reconciliation, lifecycle, proof, snapshot-mismatch, and failure cases
follow-on implementation must cover. It makes no claim of runtime coverage for ticket #85;
completion is checked against this committed design document, the architecture cross-reference, the
contract matrices, state tables, mappings, and golden vectors. Runtime tests are deferred because
this ticket produces no executable implementation.

**Document-level verification.** Review each of the seven required sections for completeness and
cross-section consistency. Verify that `docs/ARCHITECTURE.md` carries one layer or roadmap
cross-reference to `docs/sync-protocol.md`, that the design is reachable through
`docs/NAVIGATION.md`'s required reading order, and that no `docs/knowledge` entry is added.

**Operation-contract matrices.** Verify that push, pull, begin_reconcile, complete_reconcile, and
acknowledge each enumerate Dart request types, wire fields, success fields, applicable typed
failures, recovery action, authorization transport, call granularity, and atomicity boundary.

**Authentication-contract matrix.** Verify that beginEnrollment, completeEnrollment, and
refreshCredential each expose DTO opacity, ownership, success types, challenge failures, rate
limiting, backend unavailability, and separation from `SyncBackend`.

**Package-boundary matrix.** Verify that the design assigns only `VersionVector` and
`VersionVectorDecodeError` to future relocation, keeps `deviceID` and `_claimDeviceID` with Drift,
specifies only the `domain` path dependency for `normalizedID`, exposes `VersionVector` through
`package:sync/sync.dart`, excludes Flutter and `app/lib` imports, and defers all moves to
follow-on implementation.

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
exact protocol-major handling, `live` and `tombstone` lifecycle acceptance, and rejection of
malformed documents or any other lifecycle value.

**Dart API and analyzer checks.** Verify the settled member, parameter, and type naming
conventions, sealed reconcile variants, public export through `package:sync/sync.dart`, absence of
Flutter or `app` imports, and compatibility with the repository's zero-issue analyzer requirement.

**Dart-to-wire mapping tests.** Map each Dart API element to its wire operation and field so naming
conventions do not leak across the interface boundary.

**Adapter contract cases.** At the highest shared behavioral seam, identical requests must produce
equivalent typed outcomes, per-row frontiers, per-collection cursor progression, checkpoint
acknowledgement, reconciliation gates, and authentication boundaries for the Supabase and
custom-endpoint implementations.

**Causal-frontier cases.** Non-dominated insertion, dominated retry, domination-based deletion,
concurrent retention, stable retry identity, `applied`, `already_present`, `rejected`, partial batch
rejection, and independent-row progress.

**Push-proof cases.** Omission on ordinary pushes, required presence on the first post-reconciliation
push, success and consumption, absence, expiry, reuse, device mismatch, intervening-write
invalidation, and continued independent Bearer authorization.

**Pull and acknowledgement boundary cases.** One collection per call, empty pages, fewer-than-limit
pages, the 500-envelope default maximum, lower requested limits, independent collection cursors,
repeated pages, staging-before-acknowledgement, and server-only cursor assignment.

**Reconciliation state-table cases.** BeginReconcile, snapshot context, all five per-collection
snapshot pulls, fixed watermark behavior, collection_hashes completion, single-use proof consumption,
a new device before and after reconciliation, retirement after 90 or more days, reactivation, the
24-hour expiry, invalidation by an intervening write, snapshot_hash_mismatch recovery, preservation
of unsynced local writes, and prevention of garbage-collected-row resurrection.

**HTTP mapping cases.** HTTP 200 for completed calls, 400 `invalid_request`, 401 `credential_expired`
with refresh action, 403 `device_retired` and `reconciliation_required`, 409 `stale_or_invalid_proof`
and `snapshot_hash_mismatch` with `mismatched_collection`, 426 `protocol_unsupported` with supported
majors, 429 `rate_limited` with `retry_after_seconds`, and retryable 503 `network_unavailable` or
`backend_unavailable`.

**Failure-body coverage.** Require `code` and `message` in every error plus `retry_after_seconds`,
`credential_action`, or `mismatched_collection` only where applicable. Every method must document
which failures apply and the caller's required recovery action.