# Adversarial review — 2026-08-19

Full-codebase pass at commit `51aa086` (dev branch), post-port-complete. Five angles run in
parallel: domain core, UI screens, app infra (boot/shell/event-bus/analysis-cache), spec
conformance, and persistence (done directly, not delegated). Every finding below was spot-checked
against cited `file:line` after the reviewing pass reported it — none are unverified subagent
claims.

Ranked worst-first across the whole codebase, then grouped by area.

## Top severity

### 1. Boot retry after a DB-open failure can never succeed — permanent lockout
`app/lib/boot/providers.dart:26-32`, `app/lib/persistence/database_connection.dart:14-18`, Drift's
`LazyDatabase._awaitOpened` (`lazy_database.dart:54-68` in the drift-2.34.3 package).

`storeProvider` is a plain (non-autoDispose) Riverpod `Provider`, built once, cached for the app's
whole lifetime. It wraps one `LazyDatabase` whose `_awaitOpened()` caches the *first* open attempt's
`Completer` forever — on error it calls `completeError` but never clears `_openDelegate`, so every
later `ensureOpen()` call replays the same completed-with-error future. `AppBoot.retry()` calls
`start()` → `createStore()` → `ref.read(storeProvider)`, which returns the same poisoned instance.

Concrete failure: DB fails to open once (disk full, permission denied, corrupt file). User sees the
`Failed` screen and taps Retry. It fails identically forever, even after the user fixes the
underlying condition, until the process itself restarts.

Fix: `ref.invalidate(storeProvider)` before re-reading in `createStore`, or build a fresh
`LazyDatabase`/connection per `AppBoot.start()` call instead of reusing a cached provider value.

### 2. `resolvePlans` permanently drops occurrences that fail validation
`packages/domain/lib/src/ledger_state_plans.dart:73-113`, `recurring_plan.dart:28-35,57-71`.

`due = plan.occurrences(after: plan.lastResolvedDate, upTo: now)` is exclusive of `after`. The loop
tries each due date; on `LedgerError` it records a `PlanFailure` and continues — but
`plan.resolvedAt(now)` unconditionally advances `lastResolvedDate` to `now` whenever `due.isNotEmpty`,
with no distinction between occurrences that succeeded and ones that only produced a failure.

Concrete failure: a recurring rent plan's source account is archived on the day it's due.
`resolvePlans` throws `InactiveReference` for that occurrence, records a `PlanFailure`, but still
advances the cursor past it. The user restores the account and reruns `resolvePlans` — the missed
rent entry is gone forever, since `occurrences(after:)` will never regenerate a date the cursor has
already passed.

Fix: cap the new cursor at the earliest *failed* occurrence (exclusive), or keep failed dates in a
separate retry set instead of folding them into the monotonic cursor.

### 3. Account type silently corrupted on load for `loan` and `overdraft`
`app/lib/persistence/mappers.dart:13-22` (`_accountType`).

The switch maps codes 0-6 explicitly and defaults everything else to `AccountType.other`. But
`AccountType` has 10 values (`account_type.dart:1-11`): code 7 is `other` (correctly hit by the
default), 8 is `loan`, 9 is `overdraft` — both silently mapped to `other` instead. Both are
user-selectable in `app/lib/ui/accounts/account_type_picker.dart:13-14`.

Concrete failure: user creates a Loan or Overdraft account, saves it, app restarts (or reloads from
disk in a later session) — the account silently becomes "Other" on every subsequent load. Comment
at the top of the file (`mappers.dart:9-12`) states corrupt data should raise, not default — this
default path isn't even corrupt data, it's valid data mis-mapped.

Fix: add explicit cases for 8 and 9, or throw on truly unknown codes the way
`CategoryKind.fromCode`/`RecurrenceFrequency.fromCode` already do.

## High severity

### 4. `referenceOnly` lifecycle reachable via a plain update in release builds — orphaned zombie rows
`packages/domain/lib/src/ledger_state.dart:72-78,92-101`, `ledger_state_holders.dart:19-32`,
`ledger_state_categories.dart:12-43`, `ledger_state_invariants.dart:215-233`.

`_editableLifecycle` blocks reviving from a stored state and blocks direct `tombstoned`, but lets any
other transition through untouched — including `active → referenceOnly`. `referenceOnly` is meant to
be reachable only via `_purgeHolder`/`_purgeCategoryRow`, which check referencedness first. But
`updateAccount`/`updateCategory` take a caller-constructed row with a freely-settable `lifecycle`
field and grant `referenceOnly` with no referencedness check. The only guard,
`_assertReferenceOnlyImpliesReferenced`, runs inside `assert(() {...}())` — stripped in release
builds.

Concrete failure: any caller sets `lifecycle: LifecycleState.referenceOnly` on an unreferenced
account via `updateAccount`. Debug build throws immediately. Release build (what ships) silently
succeeds — the row is excluded from `activeAccounts` (invisible in UI) and never swept, since sweep
only runs from `_tombstoneDereferenced` after an entry mutation, not after a plain account update. A
permanent leaked row.

Fix: move the referencedness check into a real throw in `updateAccount`/`updateCategory`/
`updatePocket` (or centrally in `_editableLifecycle`), matching the existing hard block on
`tombstoned`.

### 5. `LedgerStateReplay.apply` performs zero validation on load
`packages/domain/lib/src/ledger_state_replay.dart:7-30`.

Bare loop over the persisted change stream, straight into the state maps — no `assertInvariants()`
call, no per-change validation, and nothing in `lib/` wraps the call with a check either. A
malformed or truncated change stream (partial write, corruption, cross-version schema drift) loads
into a state that can violate every invariant with no error, since asserts are stripped in release
too. Matches an existing standing note (replay must validate) — still unaddressed in the code.

Fix: call `assertInvariants()` (or a lighter structural check) after `apply()` and surface a real,
catchable error on failure.

### 6. `setState` after `await` with no `mounted` guard — six picker flows
`app/lib/ui/transactions/entry_form.dart:161-244` (`_pickSource`, `_pickDestination`,
`_pickCategory`, `_pickRecurrence`, `_pickDate`, `_pickEndDate`), plus the same shape in
`account_form.dart:82-95`, `category_form.dart:130-161`, `plan_form.dart:76-95`.

Every one of these awaits a picker sheet then calls `setState` with no `if (!mounted) return;` first
— confirmed absent at all six entry-form sites. The `_save()` methods in the same files do have the
guard, so the convention exists here, it's just missing on picker paths specifically.

Concrete failure: user opens a picker sheet, the form's route is popped or the app backgrounds while
the sheet's future is pending. On resolution, `setState` fires on an unmounted `State` — a debug
crash (`FlutterError: setState() called after dispose()`), a swallowed exception and lost input in
release.

Fix: mechanical — add `if (!mounted) return;` before each of the ~10 call sites.

## Medium severity

### 7. Stats screen owns its own month/kind/range state instead of shared state
`app/lib/ui/stats/stats_screen.dart:52-69` vs `app/lib/ui/shell/shell_providers.dart:16-19`
(`selectedMonthProvider`).

`_StatsScreenBodyState` holds `_kind`/`_range`/`_selectedDate` as raw `State` fields, independent of
`selectedMonthProvider` and of the `transactionsScreenProvider` family Transactions uses.
`CLAUDE.md` is explicit that a screen must never introduce its own month state — all four screen
changes build on `add-app-shell-and-boot` for exactly this reason. Confirmed:
`selectedMonthProvider` is genuinely dead in app code (only a test reads/writes it directly,
`app_shell_test.dart:135,147`) — it looks like the intended shared state that was defined but never
wired up when Stats was built.

Concrete consequence: the month cursor on Transactions and on Stats can never be kept in sync (e.g.
deep-linking into Stats for the month currently open in Transactions is structurally impossible
without a rewrite).

Fix: route Stats' selected date through `selectedMonthProvider` (or a Riverpod family analogous to
Transactions'), and either wire the existing provider in or remove it if superseded by a different
design.

### 8. Domain `LedgerError` shown to the user via raw `toString()`
`app/lib/ui/common/error_section.dart:20`, consumed from `entry_form.dart:294-296`,
`account_form.dart:123-125`, `source_edit_form.dart:153-155`, and category_form's save handler.

`LedgerError` subclasses format as enum-style internal names (`LedgerError.inactiveReference(a1b2c3...)`),
not user text. Any save that survives client-side gating but trips a domain invariant (stale picker
selection pointing at an archived account between form-open and save, category/kind mismatch) shows
that raw string directly in the UI.

Fix: a `friendlyMessage()` mapping (or a switch at the catch site) turning each `LedgerError` case
into plain text.

### 9. Undocumented source-leg income item on treat-as-expense transfers
`packages/domain/lib/src/accounting.dart:141-147`.

`classify()` emits a *second* analysis item — `bucketID: null`, kind `income` — whenever the
**source** holder of a transfer has `incomingTransfersAsExpenses == true`, in addition to the
destination-side expense item the spec documents. No spec (`ledger-analysis`,
`treat-as-expense-buckets`, `stats-screen`) mentions this; the Swift reference has no equivalent
branch at all. It's deliberate and tested
(`packages/domain/test/accounting_analysis_test.dart:69-97`, "a transfer out of a treat-as-expense
holder produces income") but undocumented, and it puts an Uncategorized income item into the stats
income view as a side effect.

Fix: either document this as an intentional Dart-only requirement (new scenario in
`ledger-analysis`), or drop the branch to match Swift and the spec as currently written — needs a
product call, not a unilateral fix.

### 10. `AppBoot`'s two `unawaited()` calls have no error handler
`app/lib/boot/app_boot.dart:95,137-143`.

`dispose()`'s `unawaited(_teardown())` and the lifecycle-pause `unawaited(phase.persistence.flush())`
both lack `.catchError`. If either throws (DB connection died right as the app backgrounds or
closes), it becomes an unhandled zone/async error — a crash overlay in debug, silent in release, at
exactly the moment the app is shutting down.

Fix: add `.catchError((e, st) => debugPrint(...))` to both, matching the pattern already used in
`analysis_cache.dart:84-89`.

### 11. Boot-failure error text shown raw to the user
`app/lib/ui/shell/boot_chrome.dart:66-70` — `Text('$error', ...)` interpolates the raw caught
`Object` directly (could be `DriftException`, `FileSystemException`, anything `store.load()` throws).
Not a crash and not a blank screen (a real error state does exist, satisfying the basic requirement),
but it's an unfiltered exception dump that can leak file paths and internal types.

Fix: map known exception types to friendly text, generic fallback message, keep the raw error only
in logs.

### 12. Spec gap: `SystemEntryLocked` guard undocumented
`packages/domain/lib/src/ledger_state_entries.dart:16-21`.

Real, deliberate, task-tracked behavior (rejecting edits to a system-kind entry's name/category/
includeInAnalysis) with no corresponding requirement in `ledger-mutations` spec or anywhere else
promoted.

Fix: add a requirement/scenario documenting when a system-kind entry update is rejected.

### 13. Spec overclaim: localization scaffolding marked delivered, isn't
`openspec/specs/accessibility-and-localization/spec.md:35-47`.

States "The app SHALL be set up for localization" as delivered. Zero `l10n.yaml`, `.arb` files, or
`AppLocalizations`/`Intl.` usage anywhere in `app/lib` — confirmed via `rg`. The still-open change's
own tasks.md explicitly marks this deferred (personal-use app, no need yet) — matches the
`docs/NAVIGATION.md` skip note already on record. The promoted main spec shouldn't claim this
requirement is done.

Fix: mark the requirement deferred in the main spec, or hold its promotion until built. The other
two requirements in this spec (semantics on custom widgets, reachable actions) are genuinely
delivered — verified against `stats_donut.dart:28-32` and
`daily_transactions_screen.dart:322-333`.

## Low severity / stale spec wording

### 14. `mainBucketID` roll-up spec text is stale, code is correct
`packages/domain/lib/src/accounting.dart:253-264` vs
`openspec/specs/ledger-analysis/spec.md:121-127`.

Spec says an item naming an absent category "SHALL remain in its own null bucket." Code returns the
leaf id unchanged — necessary now that synthetic transfer-expense buckets exist and must roll up to
themselves rather than collapse into Uncategorized (tested, and justified in
`add-parity-gaps-and-platform-pass/design.md:30-36`). The merge that produced the current
`ledger-analysis` main spec never touched this requirement's wording, so it kept the older text.
Fix is spec wording, not code.

### 15. Delete-via-semantics actions have no post-await context guard
`app/lib/ui/transactions/day_sections.dart:697-705`, `app/lib/ui/accounts/account_row.dart:41-43,70-74`.

Same shape as finding 6 but narrower — these don't touch `context` after the await today (only
captured `ledger`/callback objects), so no crash currently, but `showDeleteConfirmation` itself calls
`showDialog(context: context, ...)` and would throw if the row's context is unmounted by the time the
dialog opens. Fix most easily applied once, inside `showDeleteConfirmation`/
`delete_holder_confirmation.dart` rather than at each call site.

### 16. `EventBus` reentrancy guard is an implicit SDK detail
`app/lib/ledger/event_bus.dart:5-8`. The "throws on reentrant add" guarantee the doc comment claims
comes entirely from `StreamController.broadcast(sync: true)`'s behavior, invisible from this file.
Correct today; a future refactor to `sync: false` (for an unrelated reason) would silently remove the
guarantee with no local signal. Flagging as a trap, not a defect.

### 17. Unmemoized full recompute in `build()`
`app/lib/ui/stats/stats_screen.dart:91-96` (`slices()`) and
`app/lib/ui/accounts/accounts_screen.dart:113-114` (`accountSections()`, `Accounting.netWorth()`)
both recompute from scratch on any rebuild of the enclosing `ListenableBuilder`, including rebuilds
from unrelated local state changes (e.g. expanding one account row re-triggers a full net-worth
recompute). Not user-visible at expected personal-finance data volumes; `AnalysisCache` already
exists as the intended derived-data seam but `slices()` redoes the roll-up on top of it rather than
caching the sliced result. Flag for later if entry counts grow — not urgent now.

## Ruled out (checked, no finding)

- `Accounting.fraction()` (`accounting.dart:244-251`) is the only `double` in the whole domain
  package — confirmed via full-package grep — and it's a display-only progress-bar ratio, never
  stored or fed back into money math. Not a violation of the Decimal rule.
- `Entry.date` default (`entry.dart:40`) uses `startOfDayUtc(date ?? DateTime.now())`, which is
  day-preserving regardless of the input's own zone — not the instant-preserving bug the convention
  warns about.
- `_addMonths`/`_clampDay` boundary comparisons (`plan_scheduling.dart:39-73`, `calendar_day.dart`)
  use strict `<` but still clamp correctly when `day == lastDay` — both branches agree at that point.
- Formatters and symbol maps: `DateFormat`/`NumberFormat` each defined exactly once
  (`app/lib/ui/format/`), `symbol_map.dart` centralized — no screen duplicates them.
- Active-entity filtering in pickers is correct (`source_picker.dart:13`, `category_picker.dart:17`
  restrict to active only); archived-holder names still resolve for old entries via
  `ledger_state_queries.dart:38` rather than showing blank.
- Client-side save gating (`entry_form_logic.dart`, `account_form_logic.dart`) correctly blocks
  zero-amount/empty-name saves before the domain layer would reject them.
- Boot `Ready`-phase / `resolvePlans` ordering (`app_boot.dart:73-76`) has no real await gap between
  entering `Ready` and running the first `resolvePlans` — checked specifically for a stale-data
  render window, none found. `Loading` phase correctly gates the shell from rendering before
  `store.load()` resolves.
- Analysis-cache invalidation is structurally exhaustive, not an allowlist — every mutator funnels
  through one `_mutate` → `bus.publish` choke point, so no mutation type can be missed from a list
  that doesn't exist. `AnalysisCache.start`/`dispose` correctly cancel prior subscriptions, no
  double-registration or leak found.
- DI/singleton ordering in `app/lib/boot/providers.dart` is correctly sequenced aside from finding 1.
- Merged spec content for `transactions-screen` and `ledger-analysis` (the two built from
  chronologically-layered deltas this session) verified — the "newer wins" sections (Section totals,
  Transfer classification) are the versions actually implemented; nothing lost in the merge beyond
  finding 14's pre-existing stale wording.

## Not reviewed this pass

`ui-foundation`, `app-shell`, `ledger-runtime`, `holder-forms`, `category-management`,
`accounts-screen` specs were not walked in the spec-conformance pass (budget ran out after the
priority specs) — flagged as unchecked rather than false-MATCH. Two stats-donut golden image tests
are failing on ~1.5-2% pixel diff (`stats_donut_multi.png`, `stats_donut_single.png`) — looks like
environment/font drift rather than a behavioral defect, but not conclusively attributed; worth
regenerating the goldens or investigating separately.

## Suggested fix order

1. Finding 1 (boot retry lockout) — total denial-of-service hiding behind a working-looking button.
2. Finding 3 (loan/overdraft corruption) — silent, small, mechanical fix, real user data damage.
3. Finding 2 (resolvePlans data loss) — needs a design decision on cursor semantics, not just a patch.
4. Finding 4 (referenceOnly release escape) and finding 5 (replay validation) — same shape (release-mode
   invariant gap), worth fixing together.
5. Finding 6 (mounted guards) — mechanical, ten call sites, low risk.
6. Findings 7-13 — product/UX and spec-hygiene, no urgency but worth a pass before the next feature
   phase.
