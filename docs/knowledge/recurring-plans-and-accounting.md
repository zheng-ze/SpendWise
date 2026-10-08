# Recurring Plans & Accounting

Last reconciled: 9fc9e82

The pure-domain plan and accounting logic in `packages/domain/lib/src/plans/` and
`packages/domain/lib/src/accounting.dart`, plus the plan mutators on `LedgerState`. Plans expand
into real entries as their due dates arrive; accounting derives balances, net worth, and analysis
classification from the entry log as pure static functions.

## Key files

- `packages/domain/lib/src/plans/recurring_plan.dart`,
  `packages/domain/lib/src/entries/entry_template.dart`,
  `plan_scheduling.dart`, `occurrence_id.dart`, `plan_resolution.dart`, `plan_failure.dart` - plan
  types, occurrence math, deterministic IDs, and resolution.
- `packages/domain/lib/src/accounting.dart` - `balance`, `accountTotal`, `netWorth`, `analysisItems`,
  `classify`, `rollUp`, and the filtering helpers.
- `packages/domain/lib/src/analysis/analysis_item.dart`, `net_worth.dart`, `synthetic_buckets.dart`,
  `card_statement.dart` - domain analysis value types and the pure card-statement query.
- `packages/domain/lib/src/ledger_state/ledger_state_plans.dart` - the plan mutators on `LedgerState`.
- `packages/domain/lib/src/time/calendar_day.dart`, `date_range.dart`, `year_month.dart` - date
  helpers, including the month-clamp function.

## Module interactions

`Ledger.resolvePlans(now)` runs `state.resolvePlans(now)` inside `mutate` and reports failures
through `onPlanError` (`app/lib/ledger/ledger.dart`; [ledger-runtime.md](ledger-runtime.md)).
`AnalysisCache` caches `Accounting.analysisItems` so the Stats surface avoids a full-ledger scan
per frame. Accounting is pure and reads
`LedgerState`; it never mutates it.

## RecurringPlan

A `RecurringPlan` is an `EntryTemplate` plus a `RecurrenceFrequency`, an `anchor`, an optional
`endDate`, and a forward-only `lastResolvedDate` cursor (`plans/recurring_plan.dart`).

**Occurrence generation** computes the k-th occurrence from the anchor, never by stepping from the
previous one (`anchor + step(k)`), so the day recovers after a short month. `occurrences(after:upTo:)`
is strictly-after on `after` and inclusive on `upTo` and `endDate`; `nextOccurrence(onOrAfter:)` is
on-or-after and used by the UI, not resolution.

**Month-end clamping** - Dart's `DateTime` silently rolls Feb 31 over to March, so stepped dates
use `_addMonths` through `RecurrenceFrequency.stepFrom` (`plan_scheduling.dart`). Card cuts use
`shiftMonthThenClampDayUtc` (`time/calendar_day.dart`). The full matrix
(Jan 31 → Feb 28/29, 30-day months, year rollover, leap-day yearly) is required.

**OccurrenceID** - `OccurrenceID.make(planID, occurrenceDay)` in `occurrence_id.dart` computes a
deterministic UUIDv5 over the plan id and the occurrence's UTC calendar day, so two devices
resolving the same (plan, day) mint the same entry id and a future sync merge converges on one
entry. Namespace `8b9e0c42-5f3a-4d71-9c2e-1a6b7f0d3e85`, plan id rendered **lowercase** via
`normalizedID(planID)` in the name - the project-wide rule is lowercase. Seconds since
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
the `endDate`. Zero amount and self-transfer are **not** checked here - those surface later as
`PlanFailure`s at resolve time.

`updatePlan` additionally throws `StaleResolutionCursor` when the anchor or frequency changes and
anything has already resolved (`stored.lastResolvedDate.isAfter(stored.anchor)`), because shifting
the schedule would re-mint entries with no cursor that avoids it.

**Cascade** - `deleteAccount` hard-removes every plan touching the account or its pockets via
`removePlansReferencing`. `deletePocket` and `deleteCategory` do not remove referencing plans; the
plan survives and its next resolution emits `PlanFailure(inactiveReference)` per due occurrence.

## Accounting

All pure static functions; money is `Decimal`; balances are derived from the entry log, never
stored.

- **`applies(entry, sourceIDs)`** - a transfer counts only when both endpoints are in the existence
  set (every `moneySources` key, including archived/referenceOnly). A tombstoned holder un-applies
  a transfer to its survivor.
- **`balance`**, **`accountTotal`** (own balance plus active-pocket balances), **`netWorth`**
  (splits asset/liability by sign, not type; pockets roll into the parent; archived and
  `includeInNetWorth == false` accounts are skipped).
- **`analysisItems`** - one gated pass classifying each entry; consumers filter cheaply.
- **`classify`** - transfers emit zero, one, or two items depending on each endpoint's
  `incomingTransfersAsExpenses` flag (symmetric); income/expense resolve to a sealed
  `CategoryResolution` (`Excluded` / `Uncategorized` / `InCategory`), keep the absolute amount, and
  tag kind by the stored signed amount.

**Category resolution** order: null category → Uncategorized; category absent from the map →
Uncategorized; category or parent `includeInAnalysis == false` → Excluded; otherwise InCategory. An
archived category still buckets under its id.

**Roll-up** folds child spend into the parent main bucket; Uncategorized forms its own `null`
bucket. Filtering and totals use half-open `[start, end)` windows - a sanctioned deviation from
Swift's inclusive interval, which could double-count an entry on a month boundary.

**Treat-as-expense buckets** - a transfer into a flagged holder uses
`syntheticTransferExpenseBucketID` for the destination account type; a pocket uses its owning
account type. A flagged source emits an income item with `bucketID: null`
(`accounting.dart`: `classify`, `_destinationAccountType`; `analysis/synthetic_buckets.dart`).

## Read-only plan projection

The shared app-layer `AnalysisQueries` service owns upcoming and calendar reads. Its helpers and
result types stay under `app/lib/ledger/analysis/`. `CardStatement` and `cardStatement` are the
only domain addition to the shared analysis service
(`app/lib/ledger/analysis_queries.dart`, `packages/domain/lib/src/analysis/card_statement.dart`).

`upcomingPlanOccurrences` starts strictly after `lastResolvedDate`, bounded by today and the
requested `[start, end)` window. It delegates anchor-based generation and end-date clamping to
`RecurringPlan.occurrences`, so a cursor before the anchor can project the anchor and a cursor
ahead of today suppresses earlier dates. Any deterministic `OccurrenceID` already present in
`ledger.entries` suppresses the projection, regardless of entry lifecycle. It constructs temporary
entry records from templates without inserting entries, advancing cursors, or resolving plans.
Upcoming and calendar share this helper (`app/lib/ledger/analysis/upcoming.dart`,
`app/lib/ledger/analysis/calendar.dart`; `app/test/ledger/analysis_service_test.dart`:
`upcomingMergesKindsWithTieOrderAndCursorRules`, `calendarMarksRecordedAndPlannedDays`).

`registerDays` provides the shared app-layer seam for History day groups and calendar
selected-day totals.
Its `registerTotals` calls `Accounting.totals`, which applies entry-level analysis gates while
retaining excluded-category amounts. `Accounting.classify` excludes those categories, so register
and analysis totals intentionally differ (`app/lib/ledger/analysis/register.dart`,
`packages/domain/lib/src/accounting.dart`; `analysis_service_test.dart`:
`registerPreservesDaySectionsAccounting`).

## Card statements

`cardStatement(ledger:, accountID:, today:)` is a pure domain query exported with `CardStatement`
by `packages/domain/lib/domain.dart`. It reads `LedgerState` without mutation and returns
`accountID`, `currentCycle`, `nextCut`, `cycleAmount`, and `payable`
(`packages/domain/lib/src/analysis/card_statement.dart`).

- The query normalizes the account ID and the named calendar day with `normalizedID` and
  `startOfDayUtc`. It returns `null` for a missing account, an inactive account, a non-card account,
  or a missing `statementDay` (`cardStatement`).
- `currentCycle` is `[cycleStart, nextCut)`. Monthly cuts use `shiftMonthThenClampDayUtc`, including
  short months and year rollover; the cut day starts the new cycle (`cardStatement`,
  `packages/domain/lib/src/time/calendar_day.dart`).
- `cycleAmount` sums negated negative, active, direct-card entries excluding transfers in
  `[cycleStart, min(nextCut, today + 1 day))`. Repayments and pocket activity contribute zero;
  analysis exclusion flags do not filter charges (`cardStatement`).
- `payable` is `max(0, -Accounting.accountTotal)` over active entries strictly before `nextCut`,
  with all existing source IDs and active pockets. There is no lower date bound or today cutoff:
  older unpaid debt, opening balances, and future entries before the cut participate. Repayments
  reduce the total debt; entries on or after the cut are excluded (`cardStatement`,
  `packages/domain/lib/src/accounting.dart`: `accountTotal`, `balance`, `applies`).

The Accounts surface uses `app/lib/ui/accounts/account_sections.dart` and its app-side
`helpers/card_math.dart` functions. Its payable uses the full account total without the domain
query's cut cutoff; its outstanding uses direct-card negative non-transfer entries from
`statementCut` through the injected `now`, inclusively. These are separate calculation paths
(`accountSections`, `_row`, `statementCut`, `payable`, `outstanding`); see
[accounts-ui.md](accounts-ui.md). Contract examples live in
`packages/domain/test/analysis/card_statement_test.dart`.

## Gotchas and invariants

- `lastResolvedDate` is seeded to the anchor so the anchor occurrence itself is never emitted
  (strictly-after); seed the cursor before the anchor to emit the anchor.
- A resolve with nothing due returns `changes == []` and does not re-persist the plan.
- Self-transfers on a flagged holder emit an expense and income of equal amount, netting to zero,
  with no explicit self-transfer branch - it falls out of the symmetry.
- The `[start, end)` window is the ruled convention for ALL window filters in the port.

## Requirements

- Occurrences compute from the anchor; month steps use `_addMonths` through
  `RecurrenceFrequency.stepFrom`. (`plan_scheduling.dart`)
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
