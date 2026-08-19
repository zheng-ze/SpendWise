## Why

A full adversarial review (`docs/ADVERSARIAL-REVIEW-2026-08-19.md`) found 17 issues across the
domain, persistence, UI and boot layers. One (finding 9, the treat-as-expense transfer's
source-leg income item) is confirmed a false positive: it only affects internal categorization used
for stats styling, with no user-visible difference, so it needs no fix. Findings 16 and 17 are a
documented trap and a non-urgent perf note, not defects to fix now. The remaining 13 findings are
real gaps ranging from a boot sequence that can brick the app on a retry to two spec sections that
describe behavior the code doesn't have (or has behavior the spec doesn't describe). This change
fixes all 13 in one pass so the codebase and its specs agree again before the next feature phase
starts.

## What Changes

- Boot: rebuild the store/database connection on retry instead of reusing a poisoned
  `LazyDatabase`, so a fixed disk/permission problem actually recovers (finding 1). Add error
  handlers to the two unguarded `unawaited()` calls in `AppBoot` (finding 10). Replace the raw
  `toString()` of a boot failure with a friendly message (finding 11).
- Domain: stop `resolvePlans` from permanently skipping a recurring-plan occurrence that failed
  validation — the cursor must not advance past a date that only produced a `PlanFailure` (finding
  2). Close the `referenceOnly` lifecycle escape: `updateAccount`/`updateCategory`/`updatePocket`
  must throw a real, release-reachable error instead of relying on a debug-only assert (finding 4).
  Make `LedgerStateReplay.apply` validate the loaded state and surface a real error on a corrupt or
  incomplete change stream instead of silently loading a broken state (finding 5).
- Persistence: fix `_accountType` in the row mapper so `loan` and `overdraft` round-trip correctly
  instead of silently decoding as `other` (finding 3, same root cause and fix shape as finding 5 —
  both are the mapper/replay boundary trusting data it should validate).
- UI: add the missing `mounted` guard before `setState` in the six picker flows across the entry,
  account, category and plan forms (finding 6). Replace the raw `LedgerError.toString()` shown on a
  failed save with a friendly per-case message (finding 8). Route the Stats screen's month
  selection through the existing shared `selectedMonthProvider` instead of local `State`, so it
  stays in sync with Transactions (finding 7).
- Specs: document the `SystemEntryLocked` guard on system-kind entries, which is real, shipped
  behavior with no requirement describing it (finding 12). Correct the
  `accessibility-and-localization` spec so it no longer claims localization scaffolding is
  delivered — it is deliberately deferred (finding 13). Correct the stale `ledger-analysis`
  roll-up wording so it matches the already-correct, already-tested code (finding 14).

## Capabilities

### New Capabilities
- `data-persistence`: round-trip correctness for the Drift row mappers (every persisted enum code
  must decode back to the value it was encoded from, or fail loudly) and validation of a loaded
  change stream before it becomes live state. No existing capability spec owns storage-layer
  correctness — `app-boot` covers boot sequencing, not what happens to data once it's on disk.

### Modified Capabilities
- `app-boot`: retry after a failed store/database open must actually retry the open, not replay a
  cached failure; unhandled async errors during teardown/pause must not go silent; a boot failure
  shown to the user must not be a raw exception dump.
- `ledger-plans`: `resolvePlans` must not advance a plan's cursor past an occurrence that failed
  validation.
- `ledger-lifecycle`: setting the `referenceOnly` lifecycle on an unreferenced holder or category
  through a plain update must throw in release builds, not only under a debug assert.
- `ledger-mutations`: document the existing `SystemEntryLocked` rejection on system-kind entry
  updates.
- `ledger-analysis`: correct the roll-up requirement's stale wording to match the shipped,
  tested behavior for items whose category is absent.
- `accessibility-and-localization`: correct the localization-scaffolding requirement to reflect
  that it is deferred, not delivered.
- `entry-form`: the six affected pickers must guard `setState` with a liveness check; a failed
  save must show a friendly message instead of a raw domain error string.
- `holder-forms`: same two requirement changes as `entry-form`, for the account/category/plan
  forms this capability covers.
- `stats-screen`: the screen's month selection must come from the shared month provider, not its
  own local state.

## Impact

- `app/lib/boot/providers.dart`, `app/lib/boot/app_boot.dart`, `app/lib/ui/shell/boot_chrome.dart`
- `packages/domain/lib/src/ledger_state_plans.dart`
- `packages/domain/lib/src/ledger_state.dart`, `ledger_state_holders.dart`,
  `ledger_state_categories.dart`, `ledger_state_invariants.dart`
- `packages/domain/lib/src/ledger_state_replay.dart`
- `app/lib/persistence/mappers.dart`
- `app/lib/ui/transactions/entry_form.dart`, `app/lib/ui/accounts/account_form.dart`,
  `app/lib/ui/settings/category_form.dart`, `app/lib/ui/settings/plan_form.dart`
- `app/lib/ui/common/error_section.dart` (or a new `LedgerError` message mapper it calls)
- `app/lib/ui/stats/stats_screen.dart`, `app/lib/ui/shell/shell_providers.dart`
- `openspec/specs/ledger-mutations/spec.md`, `ledger-analysis/spec.md`,
  `accessibility-and-localization/spec.md`
- No breaking changes to persisted data format; finding 3's fix only affects how already-stored
  codes 8/9 are read going forward (existing corrupted rows on a user's device stay `other` unless
  a follow-up migration is written — out of scope here, flagged in design.md).
