<title>SpendWise domain context</title>

# SpendWise domain context

A glossary of this codebase's vocabulary, plus an index pointing at where decisions and behavior
contracts live. This file stays lean on purpose: it defines terms once, precisely, and points
elsewhere for the "why" (`docs/adr/`) and the "what" (`docs/specs/`). It does not inline either.

## Glossary

**Ledger / `LedgerState`** — the whole in-memory ledger: money sources, entries, categories and
plans, held in id-keyed tables. The single source of truth the app mutates and persists.

**Money source** — an account or a pocket; the two share one id space and one table
(`moneySources`) because most rules (lifecycle, reference counting) apply identically to both.

**Account** — a money source with a type (cash, checking, savings, card, prepaid, investment,
insurance, loan, overdraft, other) and its own list of pocket ids.

**Pocket** (`SubPocket`) — a money source owned by exactly one account, linked from the parent's
side (`Account.subPocketIDs`), never the child's. See ADR-0002 for why the link points that way.

**Entry** — a single recorded transaction: an amount, a kind (income, expense or transfer), a
source and (for transfers) a destination money source, an optional category, a date, and an
analysis-inclusion flag.

**Transaction category** (`TransactionCategory`) — a label for spending or income, with a kind
(income or expense) and an optional parent category. Nesting is capped at two levels.

**Category resolution** (`CategoryResolution`) — the sealed result of asking what category an
entry belongs to for analysis purposes: excluded from analysis entirely, included but
Uncategorized, or included under a specific category. See ADR-0007.

**Recurring plan** (`RecurringPlan`) — a template entry plus a recurrence rule, which
`resolvePlans` expands into real entries as their due dates arrive. Distinct from a budget: a plan
produces facts (entries); a budget is pure configuration.

**Occurrence** — one due date of a recurring plan, identified by a deterministic
`OccurrenceID` (UUIDv5 over the plan id and the due date). See ADR-0004.

**Budget** — a monthly spending cap on one category (or on every category, if its `categoryID` is
null), configured as an append-only timeline of `LimitEvent`s rather than a single mutable field.
See ADR-0038.

**LimitEvent** — one entry in a budget's timeline: either a `default` (changes the ongoing limit
from a month forward) or an `override` (pins exactly one month). See ADR-0038.

**Lifecycle state** (`LifecycleState`) — where a row sits in its life: `active`, `archived`
(user-hidden but still referenced), `referenceOnly` (unreferenced and pending purge), or
`tombstoned` (gone, kept only as a deletion marker for sync). See `docs/adr/` for the archival-vs-
deletion split on plans (ADR-0006) and the rule that only delete/restore/purge may move a row
between these states (ADR-0049).

**LedgerChange** — the sealed vocabulary of what a mutation changed: an upsert of an account, a
pocket, a category or an entry, or a deletion of a money source, a category or an entry. See
ADR-0001.

**LedgerError** — the sealed vocabulary of why a mutation was rejected (id collision, unknown
row, zero amount, category kind mismatch, inactive reference, and so on). See ADR-0001.

**Analysis item** (`AnalysisItem`) — one entry's contribution to income/expense analysis, after
resolving its category and applying transfer/treat-as-expense reclassification. Computed by
`Accounting.analysisItems`, never stored.

**Treat-as-expense** — a per-account flag marking the account as money leaving the user's control
(a loan, an overdraft), so a transfer into it counts as spending rather than an internal move. See
ADR-0033.

**Version vector** — a per-row counter-per-device used to order and compare writes for a future
sync engine. Lives only in the persistence layer, never in `packages/domain`. See ADR-0018.

**Invariant** — a rule `LedgerState` checks after every mutation in debug builds
(`assertInvariants`), backstopping illegal states that closed maps and dedicated removers are
meant to make unreachable in the first place. See `docs/specs/ledger-invariants.md`.

## Domain rules with no real alternative (not ADR material)

These are flat conventions applied throughout `packages/domain/`, not decisions with a rejected
alternative — so they live here, not in `docs/adr/`.

- **Money is `Decimal`, never `double`.** A `double` anywhere in `packages/domain/lib/` is a
  defect.
- **IDs are lowercase uuid strings**, normalized at every construction boundary.
- **Int-coded enums carry an explicit `code` field**, never `enum.index` — persistence writes
  these codes, and `enum.index` shifts silently if a variant is ever reordered.
- **Mutators validate, mutate, then return `List<LedgerChange>`.** Every mutation on `LedgerState`
  keeps this contract.

## Index

- **`docs/adr/`** — architecture decisions: a decision, the alternative that was rejected, and the
  consequence. Read the ones touching the area you're about to work in before changing it.
- **`docs/specs/`** — behavior contracts (Given/When/Then requirements) for every capability, one
  file per capability. This is where "what must the code do" lives; ADRs hold "why it's built this
  way," not the contract itself.
  - Domain core: `ledger-state.md`, `ledger-mutations.md`, `ledger-lifecycle.md`,
    `ledger-plans.md`, `ledger-invariants.md`, `ledger-accounting.md`, `ledger-analysis.md`,
    `budgets.md`, `data-persistence.md`.
  - Runtime: `ledger-runtime.md`, `event-bus.md`, `analysis-cache.md`, `app-boot.md`.
  - UI: `ui-foundation.md`, `app-shell.md`, `transactions-screen.md`, `entry-form.md`,
    `ocr-receipt-entry.md`, `accounts-screen.md`, `holder-forms.md`, `stats-screen.md`,
    `category-detail.md`, `category-management.md`, `plan-management.md`, `recycle-bin.md`,
    `budgets-ui.md`, `treat-as-expense-buckets.md`, `transfer-scope-display.md`,
    `accessibility-and-localization.md`.
- **`docs/agents/domain.md`** — how an agent should consume this file and `docs/adr/` before
  exploring the codebase.
- **`docs/agents/issue-tracker.md`** — how work items and open questions are tracked (GitHub
  issues via `gh`).
