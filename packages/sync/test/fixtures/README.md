# Golden protocol fixtures

The golden vectors below are populated from `docs/sync-protocol.md` §5 and consumed verbatim by
`test/protocol/golden_vectors_test.dart`.

- `sibling_id_vectors.json` — the two sibling-ID golden vectors, each with its canonical JSON input
  and expected unpadded base64url SHA-256 digest.
- `snapshot_hash_vectors.json` — the two-sibling `entries` collection-hash golden vector and the
  empty-collection golden vector, each with its envelope set and expected digest.

The vectors use the raw device key `deviceA` verbatim, as the design doc does. The test asserts
these against `canonicalJson(...)` + SHA-256 + base64url directly — the same primitive
`computeSiblingID`/`computeSnapshotHash` use internally — rather than against those functions
through a domain `VersionVector`, because `VersionVector` always lowercase-normalizes device IDs
(a separate, correct, repo-wide convention; see `CLAUDE.md`), so a mixed-case fixture routed
through it could never reproduce these bytes. A separate test in the same file exercises
`computeSiblingID` end-to-end with a normalized (lowercase) device id and asserts it agrees with
the same canonicalization primitive, closing the gap between "the algorithm matches the doc" and
"the production API uses that algorithm correctly."

Do not recompute or edit the vectors themselves: the test fails if the canonicalization mechanism
diverges from these values.
