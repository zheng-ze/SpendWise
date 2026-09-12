# packages/sync implementation brief

Handoff document for building `packages/sync` and its Supabase adapter per issue #101 and
`docs/sync-protocol.md`. This is not itself a design document — `docs/sync-protocol.md` remains
the authoritative wire-protocol source. This brief exists to hand a drafting agent (or a human) one
place that states the scope, the repo's existing integration points, the one architecture decision
already settled beyond the design doc, and the concrete questions still open before or during
implementation.

## 1. Scope

Ticket: [Implement packages/sync per docs/sync-protocol.md (#101)](https://github.com/zheng-ze/SpendWise/issues/101).
Unblocked — its blocker #6 closed via merged PR #102.

In scope:

- New `packages/sync/` package: pure Dart, no Flutter dependency at all (stricter than
  `packages/ocr`, which does depend on Flutter), depending only on `domain` by path.
- Relocate `VersionVector` / `VersionVectorDecodeError` from
  `app/lib/persistence/version_vector.dart` into `packages/sync`. `deviceID` / `_claimDeviceID`
  stay Drift-bound in `app/lib/persistence/` — they are not protocol.
- `SyncBackend` / `SyncAuthenticator` Dart interfaces, sealed `BeginReconcile` /
  `CompleteReconcile` variants, DTO opacity, the sealed `SyncOutcome` type with all named failures.
- Sibling-set envelope handling, canonical JSON, sibling-ID and per-collection snapshot-hash
  algorithms, verified against the design doc's golden vectors.
- A Supabase-backed `SyncBackend` implementation: five-table storage, OTP auth, device-scoped
  credentials, retirement/reactivation, tombstone GC.
- A custom-endpoint `SyncBackend` implementation against the four fixed HTTP paths
  (`/v1/sync/push`, `/v1/sync/pull`, `/v1/sync/reconcile`, `/v1/sync/acknowledge`) — both adapters
  are required, not just Supabase (`docs/sync-protocol.md` lines 1–12, 49–53, 74–75).
- The deferred test specification from `docs/sync-protocol.md` §7: pure-Dart, adapter-contract,
  server, analyzer, causality, cursor, authentication, reconciliation, lifecycle, proof, and
  mismatch test cases.

Explicitly out of scope (per issue #101):

- The sync coordinator — encryption/decryption, staging, same-row sibling grouping, application of
  conflict-free state into `LedgerState`, and lifecycle-triggered/on-demand orchestration wiring
  into `LedgerStore`/`PersistenceProcessor`. A follow-on ticket builds the coordinator against this
  ticket's `SyncBackend` contract.
- Conflict-resolution UX wiring (#83's design).
- Device pairing UI and key-exchange UI (#84's design).
- The self-hosted server alternative (#99).
- `docs/knowledge/sync.md` — created later by knowledge-keeper once real implementation ships.

## 2. Existing repo integration points

- **Package precedent.** `packages/domain` and `packages/ocr` are the two existing sibling
  packages, both referenced from `app/pubspec.yaml` via `path:` (`app/pubspec.yaml:13,15`), each
  with its own `pubspec.yaml`/`analysis_options.yaml`, `publish_to: none`.
  `packages/domain/pubspec.yaml` depends on `decimal`, `uuid`, `meta`, `collection`; dev-depends on
  `test`, `lints`. `packages/ocr/pubspec.yaml` additionally depends on `flutter` and `web` —
  `packages/sync` must depend on neither.
- **`normalizedID`.** Lives in `packages/domain` (e.g. `packages/domain/lib/src/entries/entry.dart`,
  `category_resolution.dart`, `occurrence_id.dart`). `packages/sync` imports it from `domain` by
  path — its one permitted intra-repo dependency.
- **Current `VersionVector`.** `app/lib/persistence/version_vector.dart` — imports
  `package:domain/domain.dart` for `normalizedID` and `package:spendwise/persistence/ledger_database.dart`
  (only for a doc comment reference at present). Holds `Map<String, int>` device→counter,
  `bump`, `dominates`, `isConcurrent`, `encode`/`decode`. No `merge` — deliberately absent, meant
  for the sync engine to add later (still out of scope for #101; only the coordinator ticket adds
  merge semantics).
- **Persistence layer this must not touch.** `app/lib/persistence/drift_ledger_store.dart` already
  ships `PermanentSaveError` classification for undecodable stored version vectors
  (`docs/knowledge/persistence.md` "Terminal save failures"), landed by #6/PR #102. `packages/sync`
  does not change persistence write-pipeline behavior — it only relocates the `VersionVector` type
  itself.
- **Checks.** Project-wide check command
  (`cd packages/domain && dart format . && dart analyze && dart test`, then
  `cd app && flutter analyze`, analyzer zero-issues) needs its `packages/sync` equivalent added
  alongside the existing two.

## 3. Settled architecture (from `docs/sync-protocol.md`)

Full detail lives in the design doc; summarized here for a drafting agent's orientation.

- **Package boundary** (§1): `packages/sync` pure Dart, compile-enforced no-Flutter, one
  intra-repo dependency (`domain`, for `normalizedID` only). Public export surface through
  `package:sync/sync.dart`.
- **Interfaces** (§2): `SyncBackend` exposes exactly `push`, `pull`, `reconcile`, `acknowledge`,
  each returning `Future<SyncOutcome<T>>`, each taking an opaque `SyncCredential`. `SyncBackend`
  never encrypts/decrypts/inspects plaintext. `SyncAuthenticator` exposes `beginEnrollment`,
  `completeEnrollment`, `refreshCredential`, each returning `SyncOutcome<...>`, owning the
  backend-specific credential lifecycle. Reconcile takes a sealed `BeginReconcile` /
  `CompleteReconcile` request. `SyncOutcome` failures: `credential_expired`, `rate_limited`,
  `device_retired`, `reconciliation_required`, `stale_or_invalid_proof`, `snapshot_hash_mismatch`,
  `protocol_unsupported`, `invalid_request`, plus `network_unavailable`/`backend_unavailable` per
  the operation matrices.
- **Envelope schema and AAD** (§3): one envelope shape for live and tombstone siblings; visible
  fields are `protocol_version`, `user_id`, `collection`, `row_id`, `sibling_id`,
  `version_vector`, `lifecycle` (closed vocabulary: `live`/`tombstone`); `ciphertext` opaque.
  XChaCha20-Poly1305 AAD covers every visible field except ciphertext. Five canonical collections:
  `money_sources`, `entries`, `categories`, `plans`, `budgets`.
- **Operations** (§4): push (atomic per logical row, not per batch; `write_proof` required on the
  first post-reconciliation push), pull (one collection per call, server-assigned cursor, 500-item
  default max page), reconcile (`begin_reconcile` returns a device-bound fixed watermark;
  `complete_reconcile` submits all five `collection_hashes` and receives a single-use write-proof
  only when all five match), acknowledge (one durable per-collection checkpoint, feeds scheduled
  tombstone GC).
- **Algorithms** (§5): canonical JSON (RFC 8785, sorted keys, string version-vector counters —
  distinct from and unrelated to `VersionVector.encode`/`decode`'s existing integer-counter Drift
  codec). Sibling ID: unpadded base64url SHA-256 of canonical JSON over `user_id`, `collection`,
  `row_id`, `version_vector`. Snapshot hash: same digest scheme over a collection's full envelope
  array sorted by ascending `sibling_id` bytewise; empty collection hashes canonical `[]`. Golden
  vectors for both are given verbatim in the doc — implementation must match them exactly.
- **HTTP mapping** (§6): four fixed `POST` paths under `/v1/sync/...`; snake_case wire fields;
  `Authorization: Bearer` credential; full status/failure-code table (400/401/403/409/426/429/503).
  **The custom endpoint speaks these four paths directly; the Supabase adapter maps the same
  abstract operations to Postgres/PostgREST behavior instead of exposing the same wire surface**
  (doc's own words, §6 "Endpoints") — the two adapters are not wire-identical by design.
- **Deferred test spec** (§7): full list of required test categories; see the doc for the complete
  enumeration (schema-coverage matrix, golden vectors, adapter-contract cases, causal-frontier
  cases, push-proof cases, pull/ack boundary cases, reconciliation state-table cases, HTTP mapping
  cases, failure-body coverage).

## 4. One architecture decision already settled beyond the design doc

**Question:** what actually enforces server-side invariants (atomic per-row push, ordered
five-collection-hash comparison plus single-use proof minting, retirement/reactivation gating) on
the Supabase side, given the design doc says the Supabase adapter "maps the same abstract
operations to managed Postgres and PostgREST behavior" without specifying the mechanism?

**Settled via a two-model pressure-test pass, reinforced by a direct re-read of §6:** the design
doc already rules out an Edge-Functions-fronted, wire-identical-to-custom-endpoint shape (there is
no requirement for the Supabase adapter to expose the same four HTTP paths — its own text
distinguishes the two adapters). A thin client operating directly on PostgREST table resources
(client-side orchestration) was rejected by both models as unable to enforce atomicity, ordered
proof issuance, or retirement gating safely.

**Recommendation:** server-side procedural logic lives in Postgres RPC functions (PL/pgSQL,
`SECURITY DEFINER`), exposed through PostgREST's `rpc/` endpoint. `SupabaseSyncBackend` calls those
RPCs directly; `CustomEndpointSyncBackend` calls the four fixed HTTP paths independently — two
distinct Dart classes implementing one `SyncBackend` interface. Interchangeability is enforced at
the Dart interface/`SyncOutcome` level via a shared adapter-contract test suite exercising both
classes for identical outcome semantics, not by forcing a wire-identical HTTP surface on Supabase.

This is a recommendation, not yet a locked decision — flag it for review alongside the open
questions below.

## 5. Open questions needing clarification before or during implementation

1. **Credential type hierarchy.** `SyncBackend` operations take a `SyncCredential`;
   `SyncAuthenticator.completeEnrollment`/`refreshCredential` return `DeviceCredential`. The design
   doc names both but does not state their relationship. Options raised so far:
   - Subtype: `DeviceCredential` is an opaque subtype of `SyncCredential`; each authenticator
     returns a private, backend-specific implementation its matching backend can inspect. Preserves
     both spec-named types; prevents caller construction.
   - Collapse to `DeviceCredential` only, used everywhere `SyncCredential` appears in the design
     doc's signatures — simpler hierarchy but departs from the doc's literal Dart-to-wire matrix
     naming.
   - Keep them unrelated types with an explicit conversion/token-presentation step — adds a public
     operation and a lifecycle rule the design doc does not specify.
2. **PL/pgSQL RPC surface.** Given the recommendation in §4, what are the actual RPC function
   names/signatures for push / pull / begin_reconcile / complete_reconcile / acknowledge? Who owns
   the Postgres schema/migration files, and where do they live in the repo (a new
   `supabase/` or `server/` directory, or outside this repo entirely)?
3. **Supabase Dart SDK vs. raw HTTP.** Does `SupabaseSyncBackend` use the official
   `supabase_flutter`/`supabase` Dart package's PostgREST RPC client, or does it speak raw HTTPS
   directly (relevant given `packages/sync` itself must stay Flutter-free — the Supabase client
   package would need to live in `app/` instead, with `packages/sync` only defining the interface)?
4. **HTTP client for the custom-endpoint adapter.** Which package (`http`, `dio`, `package:http`
   pinned version) implements `CustomEndpointSyncBackend`'s raw calls to the four fixed paths, and
   does that dependency live in `packages/sync` or only in `app`?
5. **Test-only in-memory `SyncBackend`.** Does `packages/sync` ship a fake/in-memory
   `SyncBackend` implementation for the app's own future coordinator tests (mirroring
   `packages/domain`'s pattern of shipping both a Drift-backed and in-memory `LedgerStore`), or is
   that left entirely to a later ticket?
6. **`protocol_version` constant.** Where does the single supported protocol-major integer live,
   and how does a version bump get coordinated between `packages/sync` and a live server
   deployment (out of scope for #101's server side, but the client constant needs a home)?
7. **Golden-vector fixture format.** Should the sibling-ID and snapshot-hash golden vectors from
   `docs/sync-protocol.md` §5 be embedded as literal Dart test constants, or loaded from JSON
   fixture files (matching `packages/ocr`'s `test/fixtures/` convention)?

## 6. Source

`docs/sync-protocol.md` (authoritative wire-protocol design), `docs/ARCHITECTURE.md` roadmap item
1, issue #80 (settled architecture), issue #85 (produced the design doc), issue #101 (this
ticket's own scope and out-of-scope list).
