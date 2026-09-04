# Recurring Plans & Accounting

Last reconciled: 2026-09-02

_(Reconciled against `ledger_state_plans.dart`, `occurrence_id.dart`, `plan_resolution.dart` on the
date below; see Known gaps item 1.)_

The pure-domain plan and accounting logic in `packages/domain/lib/src/plans/` and
`packages/domain/lib/src/accounting.dart`, plus the plan mutators on `LedgerState`. Plans expand
into real entries as their due dates arrive; accounting derives balances, net worth, and analysis
classification from the entry log as pure static functions.

## Key files

- `packages/domain/lib/src/plans/recurring_plan.dart`, `entry_template.dart`,
  `plan_scheduling.dart`, `occurrence_id.dart`, `plan_resolution.dart`, `plan_failure.dart` — plan
  types, occurrence math, deterministic IDs, and resolution.
- `packages/domain/lib/src/accounting.dart` — `balance`, `accountTotal`, `netWorth`, `analysisItems`,
  `classify`, `rollUp`, and the filtering helpers.
- `packages/domain/lib/src/analysis/analysis_item.dart`, `net_worth.dart`, `synthetic_buckets.dart`
  — analysis value types.
- `packages/domain/lib/src/ledger_state/ledger_state_plans.dart` — the plan mutators on `LedgerState`.
- `packages/domain/lib/src/time/calendar_day.dart`, `date_range.dart`, `year_month.dart` — date
  helpers, including the month-clamp function.

## Module interactions

`Ledger.resolvePlans(now)` runs `state.resolvePlans(now)` inside `mutate` and reports failures
through `onPlanError` (`ledger_runtime.md` §1.4). `AnalysisCache` caches `Accounting.analysisItems`
so the Stats surface avoids a full-ledger scan per frame. Accounting is pure and reads
`LedgerState`; it never mutates it.

## RecurringPlan

A `RecurringPlan` is an `EntryTemplate` plus a `RecurrenceFrequency`, an `anchor`, an optional
`endDate`, and a forward-only `lastResolvedDate` cursor (`plans/recurring_plan.dart`).

**Occurrence generation** computes the k-th occurrence from the anchor, never by stepping from the
previous one (`anchor + step(k)`), so the day recovers after a short month. `occurrences(after:upTo:)`
is strictly-after on `from` and inclusive on `to` and `endDate`; `nextOccurrence(onOrAfter:)` is
on-or-after and used by the UI, not resolution.

**Month-end clamping** — Dart's `DateTime` silently rolls Feb 31 over to March, so stepped dates
use `addMonthsClamped` (also used for card `statementCut` math). The full matrix
(Jan 31 → Feb 28/29, 30-day months, year rollover, leap-day yearly) is required.

**OccurrenceID** — `OccurrenceID.make(planID, occurrenceDay)` in `occurrence_id.dart` computes a
deterministic UUIDv5 over the plan id and the occurrence's UTC calendar day, so two devices
resolving the same (plan, day) mint the same entry id and a future sync merge converges on one
entry. Namespace `8b9e0c42-5f3a-4d71-9c2e-1a6b7f0d3e85`, plan id rendered **lowercase** via
`normalizedID(planID)` in the name — the project-wide rule is lowercase. Seconds since
2001-01-01T00:00:00Z (Apple reference date). No calendar parameter: UTC is baked in via
`startOfDayUtc`. An occurrence instant's day-boundary normalization, not its time, determines the
id. A pinned test fixes the id for a given plan id and UTC day and pins the case-insensitive
plan-id match and the time-of-day collapse (local vs UTC, any time of day) to the same id.

**`resolvePlans(now)`** (`ledger_state_plans.dart`) iterates plans in sorted-id order. For each
plan it computes `occurrences(after: lastResolvedDate, upTo: now)`, builds each entry via
`makeEntry`, skips silently if an entry with that id already exists, runs full entry validation
(`_validated`), stores on success, and appends a `PlanFailure` on error while continuing. The cursor
**stops at the first failure**: it advances to the last successfully-materialized or already-present
occurrence before that failure, then still attempts later dates. A failed occurrence is recorded in
`failures` and retried on a later sweep. The plan is retired (removed + `DeletePlan`) if exhausted, else
upserted if due, else left alone. A `PlanResolution` carries both `changes` and `failures`.

The resolve cursor stops at the first failure because a later cursor would skip the failed
occurrence's retry; replaying a stale window yields the same result.

**Plan validation** (`addPlan`/`updatePlan` → `_validatePlan` in `ledger_state_plans.dart`)
**hoists** the category-kind check to write time: `CategoryKindMismatch` when the template implies a
kind the category does not have, or a transfer names any category. It also throws `UnknownHolder` /
`InactiveReference` for holders, `UnknownCategory` / `InactiveReference` for the category, and
`ExhaustedPlan` when `endDate` is before the anchor or the cursor (`lastResolvedDate`) has reached
the `endDate`. Zero amount and self-transfer are **not** checked here — those surface later as
`PlanFailure`s at resolve time.

`updatePlan` additionally throws `StaleResolutionCursor` when the anchor or frequency changes and
anything has already resolved (`stored.lastResolvedDate.isAfter(stored.anchor)`), because shifting
the schedule would re-mint entries with no cursor that avoids it.

**Cascade** — `deleteAccount` hard-removes every plan touching the account or its pockets via
`removePlansReferencing`. `deletePocket` and `deleteCategory` do not remove referencing plans; the
plan survives and its next resolution emits `PlanFailure(inactiveReference)` per due occurrence.

## Accounting

All pure static functions; money is `Decimal`; balances are derived from the entry log, never
stored.

- **`applies(entry, sourceIDs)`** — a transfer counts only when both endpoints are in the existence
  set (every `moneySources` key, including archived/referenceOnly). A tombstoned holder un-applies
  a transfer to its survivor.
- **`balance`**, **`accountTotal`** (own balance plus active-pocket balances), **`netWorth`**
  (splits asset/liability by sign, not type; pockets roll into the parent; archived and
  `includeInNetWorth == false` accounts are skipped).
- **`analysisItems`** — one gated pass classifying each entry; consumers filter cheaply.
- **`classify`** — transfers emit zero, one, or two items depending on each endpoint's
  `incomingTransfersAsExpenses` flag (symmetric); income/expense resolve to a sealed
  `CategoryResolution` (`Excluded` / `Uncategorized` / `InCategory`), keep the absolute amount, and
  tag kind by the stored signed amount.

**Category resolution** order: null category → Uncategorized; category absent from the map →
Uncategorized; category or parent `includeInAnalysis == false` → Excluded; otherwise InCategory. An
archived category still buckets under its id.

**Roll-up** folds child spend into the parent main bucket; Uncategorized forms its own `null`
bucket. Filtering and totals use half-open `[start, end)` windows — a sanctioned deviation from
Swift's inclusive interval, which could double-count an entry on a month boundary.

**Treat-as-expense gap** — a transfer into a flagged holder classifies as an expense item with
`bucketID: null` (the Uncategorized bucket). Bucketing by destination account type is a recorded
Phase 6 decision, never slipped into the port.

## Gotchas and invariants

- `lastResolvedDate` is seeded to the anchor so the anchor occurrence itself is never emitted
  (strictly-after); seed the cursor before the anchor to emit the anchor.
- A resolve with nothing due returns `changes == []` and does not re-persist the plan.
- Self-transfers on a flagged holder emit an expense and income of equal amount, netting to zero,
  with no explicit self-transfer branch — it falls out of the symmetry.
- The `[start, end)` window is the ruled convention for ALL window filters in the port.

## Requirements

- Occurrences compute from the anchor; month steps use `addMonthsClamped`. (`plan_scheduling.dart`)
- OccurrenceID is UUIDv5 over the **lowercase** normalized plan id and UTC day; all plan date math
  is UTC. (`occurrence_id.dart`)
- `resolvePlans(now)` dedupes by deterministic id, **stops the cursor at the first failure** and
  retries later dates, and retires an exhausted plan. (`ledger_state_plans.dart`)
- `updatePlan` throws `StaleResolutionCursor` when the anchor/frequency changes after resolution;
  `_validatePlan` hoists the category-kind check and rejects `endDate < anchor` as `ExhaustedPlan`.
  (`ledger_state_plans.dart`)
- Net worth splits by sign; pockets roll into the parent; archived and non-net-worth accounts are
  skipped. (`accounting.dart` §4.4)
- Analysis uses half-open windows and a sealed `CategoryResolution`. (`accounting.dart` §5.4)
