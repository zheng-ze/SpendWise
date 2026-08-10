# Add the ledger runtime

## Why

The domain is a pure library: it computes, but nothing drives it. There is no object that owns a
`LedgerState`, no way for one part of the app to learn that another mutated it, and no path from a
mutation to storage. `app/lib/` is still a bare `main.dart`.

This is Phase 3, and the master doc's sequencing rule makes it the gate for everything visual: **no
UI work before Phase 3 is green.** Every screen reads its data through this layer, so building
screens first would re-litigate every bug against an unverified runtime.

## What Changes

- Add `Ledger` — the sole mutation hub. `mutate` runs the domain method, checks invariants in debug,
  publishes the resulting changes to the bus, then notifies listeners, in that order.
- Add `EventBus` on a synchronous broadcast stream, preserving the Swift guarantees: ordered,
  atomic batches, fan-out to every subscriber, and empty batches suppressed.
- Add `AnalysisCache` — bus-driven, with the generation guard that claims a revision before
  computing and discards any result a newer refresh has overtaken.
- Add `LedgerStore` (abstract), `InMemoryLedgerStore` (the test double), and `PersistenceProcessor`,
  the single pipe from bus to store. The real Drift store is Phase 4.
- Add the boot phase machine (`loading` / `ready` / `failed`), the app lifecycle hooks, and the
  banner state for save and plan-resolution errors.
- Add the sample-data seed builder, which asserts in debug rather than swallowing failures.
- Add Riverpod providers wiring the above, and the first controller tests.
- Port `EventDrivenTests` plus the runtime's own test inventory.

Not **BREAKING**: `packages/domain` is untouched. This is the first real code in `app/lib/`.

## Capabilities

### New Capabilities

- `ledger-runtime`: the mutation hub, its public API, and the invariant/publish/notify ordering
  every mutation passes through.
- `event-bus`: the delivery guarantees subscribers depend on.
- `analysis-cache`: bus-driven caching of the analysis pass, including the staleness guard and the
  off-main-thread compute contract.
- `app-boot`: the boot phase machine, seeding, lifecycle hooks, and error banners.

### Modified Capabilities

None. Nothing in `openspec/specs/` changes behavior.

## Impact

- New code in `app/lib/ledger/`, `app/lib/persistence/` (contract plus in-memory double only), and
  `app/lib/boot/`.
- New tests in `app/test/`.
- New dependencies on `app/`: `flutter_riverpod`. No new dependency on `packages/domain`.
- `packages/domain/` unchanged — it stays pure Dart with no Flutter dependency.
- Two spots where a straight translation of the Swift would be wrong (`design.md`): the isolate
  snapshot, since Dart's `LedgerState` is a mutable class where Swift's was a value-copied struct,
  and the subscribe-time cut, since a Dart broadcast stream does not buffer for a not-yet-attached
  listener the way Swift's `AsyncStream` did.
