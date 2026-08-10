# SpendWise — Flutter port

Rewrite of the frozen SwiftUI app at `../SpendWise-SwiftUI`. That repo is the source of truth for
behavior; its own CLAUDE.md is stale — trust the Swift code, not its docs.

## Layout

- `packages/domain/` — pure Dart. Models, `LedgerState`, accounting. Has no Flutter dependency and
  must never gain one; that is what keeps the domain portable and testable.
- `app/` — the Flutter app. Depends on `domain` by path.
- `docs/` — behavior specs. `Flutter_Port_Tech_Doc.md` is the master plan; `docs/modules/*.md` are
  the per-phase specs; `docs/reviews/` are completed adversarial passes (all corrections already
  applied — do not re-litigate their findings).
- `openspec/` — the planned work. `project.md` holds the full technical rules (this file is its
  summary); `changes/<name>/` holds each change's proposal, specs, design and tasks.

## Where to look

Planning moved to OpenSpec. Start here, in this order:

1. `openspec/project.md` — the authoritative technical rules, mirrored into `openspec/config.yaml`
   `context:` so the OpenSpec CLI injects them. Keep the two in sync when either changes.
2. `openspec/changes/complete-domain-ledger-core/` — the current change: Phase 1 remainder,
   `LedgerError` and `LedgerChange` through the export barrel. `tasks.md` is the work queue,
   `specs/` are the behavior contracts, `design.md` the implementation decisions.
3. `docs/modules/domain_models.md` — the underlying behavior spec those specs were derived from.
   It is more detailed than the change's specs and stays the reference for anything ambiguous.
4. `docs/HANDOVER.md` — historical only. It records the decisions behind commits 1.1 and 1.2 and
   points at the files above. It is no longer the plan.

The OpenSpec CLI needs node 20 (`nvm use 20`); it crashes on node 18.

## Conventions

**Comments:** minimal. Comment only tricky nuance, deliberate spec deviations, or ordering
constraints a reader would otherwise break. Never restate what the code says.

**The port is a translation, not a redesign.** Type names match Swift (`LedgerState`, `Entry`,
`MoneySource`, `TransactionCategory`, `LedgerChange`, `LedgerError`). Mutators keep the
validate → mutate → return `List<LedgerChange>` contract. Deviations from Swift happen only where
a spec's "KNOWN DEFECT" or "PORT FIX" section sanctions one.

**Money is `Decimal`, never `double`.** `double` in `packages/domain/lib/` is a defect.

**IDs are lowercase uuid strings**, normalized at every construction boundary.

**Int-coded enums** carry an explicit `code` field pinned to the Swift raw value, never
`enum.index` — persistence writes these codes.

**Window filters are half-open `[start, end)`** everywhere.

## Checks

`cd packages/domain && dart analyze && dart test`, and `cd app && flutter analyze`. Analyzer must
be at zero issues, not just zero errors.

## Scope

Recurring Plans are group 8 of `complete-domain-ledger-core`, ahead of the invariants so that
clauses 7 and 8 are written once against real plan data. They were deferred until accounts and
entries existed, not dropped, since purge and the dereference sweep are what the plan cascade hooks
into. `openspec/project.md` holds the details, including the two spots where a straight translation
of the Swift would be wrong (month-end clamping, and the UUIDv5 occurrence ids).
