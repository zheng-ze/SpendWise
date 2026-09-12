# Proposed Supabase RPC contract (prototype)

This is **not deployable SQL**. It records the client-side RPC names used by the prototype so the database migration and Dart adapter can be finalized together.

| Abstract operation | Proposed RPC | Required server invariant |
|---|---|---|
| `push` | `sync_push` | Authenticate device; enforce retirement/reactivation state; validate proof when required; apply sibling-set changes atomically per logical row. |
| `pull` | `sync_pull` | Authenticate device; one collection per call; stable server cursor/watermark semantics; bounded page. |
| begin reconcile | `sync_begin_reconcile` | Create/fetch a device-bound fixed watermark for the reconciliation attempt. |
| complete reconcile | `sync_complete_reconcile` | Compare all five collection hashes in canonical collection order and mint a single-use write proof only on a full match. |
| `acknowledge` | `sync_acknowledge` | Store one durable per-device/per-collection checkpoint for tombstone-GC eligibility. |

## Recommended placement

Keep schema + RPC migrations under `supabase/migrations/` in the SpendWise repository so server invariants and Dart adapter changes are reviewed in the same PR. Use `SECURITY DEFINER` only with an explicit `search_path`, schema-qualified object names, minimal grants, and tests proving users/devices cannot cross tenant boundaries.

## Still required from the authoritative design doc

- Exact request/response DTO fields and RPC argument names.
- Exact error code/status mapping.
- Device enrollment, retirement/reactivation and OTP flow.
- Cursor/watermark representation.
- Tombstone-GC timing and proof-consumption transaction details.
