# Where to look

Planning lives in OpenSpec. Read in this order.

1. `openspec/project.md` — the authoritative technical rules, mirrored into `openspec/config.yaml`
   `context:` so the OpenSpec CLI injects them. Keep the two in sync when either changes.
2. `openspec/changes/<name>/` — the change being worked. `tasks.md` is the work queue, `specs/` the
   behavior contracts, `design.md` the decisions, including every spot where a straight translation
   of the Swift would be wrong.
3. `openspec/specs/` — the promoted contracts Phase 1 delivered: `ledger-state`, `ledger-mutations`,
   `ledger-lifecycle`, `ledger-plans`, `ledger-invariants`. The archived change itself is at
   `openspec/changes/archive/2026-08-10-complete-domain-ledger-core/`.
4. `docs/modules/*.md` — the underlying behavior specs the contracts were derived from, and more
   detailed than any change spec: `domain_models.md` for Phase 1, `plans_and_accounting.md` for
   plans and accounting, `ledger_runtime.md`, `persistence.md`, `ui_screens.md`. They stay the
   reference for anything ambiguous, and each change names the sections it drew from.
5. `docs/Flutter_Port_Tech_Doc.md` — the master plan. §6 defines the phases, §1 lists the V1 defects
   the port fixes, §8 is the definition of done.
6. `docs/reviews/` — completed adversarial passes. All corrections are already applied. Do not
   re-litigate their findings.
7. `docs/HANDOVER.md` — historical only. It records the decisions behind commits 1.1 and 1.2 and
   points at the files above. It is no longer the plan.

The frozen SwiftUI app at `../SpendWise-SwiftUI` is the source of truth for behavior. Its own
CLAUDE.md is stale, so trust the Swift code and not its docs.

The OpenSpec CLI needs node 20 (`nvm use 20`); it crashes on node 18.

## Phase order

Each change depends on the ones above it.

| Change | Phase | What it adds |
|---|---|---|
| `add-domain-accounting` | 2 | Balances, net worth, analysis classification, roll-up |
| `add-ledger-runtime` | 3 | `Ledger`, `EventBus`, `AnalysisCache`, store contract, boot, seeding |
| `add-drift-store` | 4 | Schema, mappers, write pipeline, replay, version vectors |
| `add-app-shell-and-boot` | 5 | Adaptive shell, boot chrome, banners, formatting, shared widgets |
| `fix-boot-and-plan-defects` | 5 | Fixes from the phase 2-5 adversarial review: plan-edit duplicate entries, unregistered lifecycle observer, boot teardown leaks |
| `add-transactions-ui` | 5 | Day sections, month breakdown, entry form |
| `add-accounts-ui` | 5 | Grouped accounts, card statement math, holder forms |
| `add-stats-ui` | 5 | Donut, slices, category drill-down, trend |
| `add-settings-ui` | 5 | Categories, plans, recycle bin |
| `add-parity-gaps-and-platform-pass` | 6 | Treat-as-expense buckets, scope-aware transfers, a11y, l10n |
| `add-release-targets` | 7 | Per-platform bring-up, smoke tests, README |

Phase 1 is done and archived: the ledger container, every mutator, the lifecycle rules, Recurring
Plans and the invariants. `openspec/project.md` holds the details, including the two spots where a
straight translation of the Swift would have been wrong (month-end clamping, and the UUIDv5
occurrence ids).

Phases 1 to 5 are a translation. Phase 6 is the first change that alters behavior on purpose, and
that separation is what keeps a port bug distinguishable from a deliberate difference, so its work
is never pulled earlier. Two things it owns are deferred by name in earlier changes: the
transactions-versus-stats totals ruling, and bucketing treat-as-expense transfers by account type.
