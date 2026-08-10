# Complete the domain ledger core

## Why

The Flutter port has enums (commit 1.1) and model value types (commit 1.2), but no `LedgerState`: no
change type, no error type, no mutators, no queries, no invariants. Nothing above the domain layer can
be built until the ledger's behavior exists and is pinned by the ported test suite, so this blocks
Phase 2 accounting, Phase 3 runtime, Phase 4 persistence, and every UI phase after them.

## What Changes

- Add `LedgerError` — sealed, `implements Exception`, 10 cases with value equality. Payload-carrying
  cases hold the offending id.
- Add `LedgerChange` — sealed, 7 cases, value equality, a total `targetID` getter, and the
  `LedgerChange.upsertSource(MoneySource)` convenience factory.
- Add the `LedgerState` container (three maps: `moneySources`, `entries`, `categories`) and its 9
  read-only queries.
- Add every mutator under the `validate → mutate → return List<LedgerChange>` contract: accounts and
  pockets, entries plus the 9-step `validated` check, categories, archive, restore, purge, and the
  private dereference sweep.
- Fix the known Swift reference-counting defect rather than porting it: an account counts as
  referenced while any pocket in its `subPocketIDs` survives, `purgeAccount` purges pockets before the
  account, a tombstoning pocket re-checks its former parent, and the sweep never tombstones an account
  with surviving pockets.
- Add Recurring Plans: `RecurringPlan` / `EntryTemplate` / `RecurrenceFrequency`, `OccurrenceID`, the
  `plans` map, the plan mutators, `resolvePlans`, and the plan cascade in `deleteAccount`. This lands
  ahead of the invariants so their plan clauses are written once against real plan data.
- Add `assertInvariants` — 11 clauses, debug-only, callable on demand from tests.
- Port the Swift `LedgerStateTests` suite (68 tests) plus `RecurringPlanTests`, 3 defect regression
  tests, and the test support files (`fixtures.dart`, `apply.dart`, `matchers.dart`).
- Add the package export barrel.

With plans in scope, `LedgerChange` ships all 9 cases and `LedgerError` all 12.

Not **BREAKING**: `packages/domain` has no consumers yet beyond its own tests.

## Capabilities

### New Capabilities

- `ledger-state`: the in-memory ledger container, its read-only queries, and the change/error types
  every mutator communicates through.
- `ledger-mutations`: the mutator surface — add/update for accounts, pockets, entries and categories,
  entry validation, opening balances, and entry deletion.
- `ledger-lifecycle`: archive, restore, purge, the dereference sweep, and the reference-counting rules
  that decide whether a purged row becomes `referenceOnly` or is tombstoned.
- `ledger-invariants`: the 11 structural properties that must hold of any reachable ledger state.
- `ledger-plans`: recurring plans — the recurrence schedule, deterministic occurrence ids, the plan
  mutators, and the sweep that resolves due occurrences into stored entries.

### Modified Capabilities

None. `openspec/specs/` is empty; this is the first change in the project.

## Impact

- New code in `packages/domain/lib/src/`: `ledger_error.dart`, `ledger_change.dart`,
  `ledger_state.dart` and its `part of` files for queries and invariants.
- New tests in `packages/domain/test/`, including `test/support/`.
- New export barrel at `packages/domain/lib/domain.dart`.
- New plan sources in `packages/domain/lib/src/`: `recurring_plan.dart`, `entry_template.dart`,
  `plan_scheduling.dart`, `occurrence_id.dart`.
- No change to `app/` or to any existing model or enum file.
- No new dependencies. The UUIDv5 occurrence ids come from `uuid`, which is already present, as are
  `decimal` and `meta`; `equatable` stays out deliberately.
