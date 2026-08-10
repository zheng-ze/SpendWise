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
2. `openspec/changes/add-domain-accounting/` — the change to work next. Every remaining phase is
   also written up as a change; they are listed in dependency order under Scope below. In each,
   `tasks.md` is the work queue, `specs/` the behavior contracts, `design.md` the decisions —
   including every spot where a straight translation of the Swift would be wrong.
3. `openspec/specs/` — the promoted contracts Phase 1 already delivered: `ledger-state`,
   `ledger-mutations`, `ledger-lifecycle`, `ledger-plans`, `ledger-invariants`. The archived change
   itself is at `openspec/changes/archive/2026-08-10-complete-domain-ledger-core/`.
4. `docs/modules/*.md` — the underlying behavior specs the contracts were derived from, and more
   detailed than any change spec: `domain_models.md` for Phase 1, `plans_and_accounting.md` for
   plans and accounting, `ledger_runtime.md`, `persistence.md`, `ui_screens.md`. They stay the
   reference for anything ambiguous, and each change names the sections it was drawn from.
5. `docs/Flutter_Port_Tech_Doc.md` — the master plan. §6 defines the phases, §1 lists the V1 defects
   the port fixes, §8 is the definition of done.
6. `docs/HANDOVER.md` — historical only. It records the decisions behind commits 1.1 and 1.2 and
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

Phase 1 is done and archived: the ledger container, every mutator, the lifecycle rules, Recurring
Plans and the invariants. `openspec/project.md` holds the details, including the two spots where a
straight translation of the Swift would have been wrong (month-end clamping, and the UUIDv5
occurrence ids).

Every remaining phase is written up as a change. Work them in this order — each depends on the ones
above it:

| Change | Phase | What it adds |
|---|---|---|
| `add-domain-accounting` | 2 | Balances, net worth, analysis classification, roll-up |
| `add-ledger-runtime` | 3 | `Ledger`, `EventBus`, `AnalysisCache`, store contract, boot, seeding |
| `add-drift-store` | 4 | Schema, mappers, write pipeline, replay, version vectors |
| `add-app-shell-and-boot` | 5 | Adaptive shell, boot chrome, banners, formatting, shared widgets |
| `add-transactions-ui` | 5 | Day sections, month breakdown, entry form |
| `add-accounts-ui` | 5 | Grouped accounts, card statement math, holder forms |
| `add-stats-ui` | 5 | Donut, slices, category drill-down, trend |
| `add-settings-ui` | 5 | Categories, plans, recycle bin |
| `add-parity-gaps-and-platform-pass` | 6 | Treat-as-expense buckets, scope-aware transfers, a11y, l10n |
| `add-release-targets` | 7 | Per-platform bring-up, smoke tests, README |

Phases 1–5 are a translation. **Phase 6 is the first change that alters behavior on purpose** — that
separation is what keeps a port bug distinguishable from a deliberate difference, so do not pull its
work earlier. Two things it owns are deferred by name in earlier changes: the transactions-versus-
stats totals ruling, and bucketing treat-as-expense transfers by account type.

The sequencing rule from the master doc: **no UI work before Phase 3 is green.**
