## Context

See proposal.md for the full list of findings and why each is real. This document covers the
handful of decisions that aren't obvious from the spec deltas alone: how to invalidate a poisoned
Riverpod provider, how a plan cursor represents "stopped early," what a corrupted `loan`/`overdraft`
account looks like on an existing user's device before this change ships, and which error-message
mapping approach to use across three different forms.

## Goals / Non-Goals

**Goals:**
- Fix all 13 in-scope findings so the app matches its specs again.
- Keep every fix minimal and localized — this is a bug-fix pass, not a redesign.
- Add the test for each finding against the unfixed code first, per the project's red-then-green
  convention, so every fix is proven to bite before it lands.

**Non-Goals:**
- Migrating existing on-disk data for users who already have a `loan`/`overdraft` account silently
  stored as `other` before this fix ships. See Risks below — flagged, not solved here.
- Building the `friendlyMessage()` mapping into a general i18n-ready abstraction. Localization is
  spec'd as deferred (finding 13); the message mapping this change adds is a plain Dart function
  returning English strings, nothing more.
- Redesigning `selectedMonthProvider`'s shape. Finding 7's fix wires Stats into the provider that
  already exists; if that provider's design turns out to need changing, that's separate work.
- Persistence-layer test infrastructure changes beyond what's needed to exercise the two new
  `data-persistence` requirements.

## Decisions

### Boot retry (finding 1): invalidate the provider, don't restructure boot

`storeProvider` is a plain `Provider`, cached for the container's lifetime by design — that's
correct for the normal case (one store instance backing the whole app). The bug is narrower: retry
has no way to discard a poisoned instance. Fix: `AppBoot.retry()` calls
`ref.invalidate(storeProvider)` (and `ref.invalidate(databaseConnectionProvider)`, since the poisoned
`LazyDatabase` closure captures the old connection future) before calling `start()` again. Riverpod
disposes the old provider value and rebuilds fresh on the next read, which builds a brand-new
`LazyDatabase` with a clean `_openDelegate`.

Alternative considered: make `DriftLedgerStore`/`LazyDatabase` retryable internally (clear
`_openDelegate` on error). Rejected — that would mean wrapping or forking Drift's `LazyDatabase`,
more code and more risk than invalidating a Riverpod provider, for the same outcome.

### Plan cursor on partial failure (finding 2): stop-before-first-failure, not skip-and-retry-individually

The spec change adds "the cursor SHALL stop at the earliest failed occurrence." Concretely:
`resolvePlans` currently computes `advanced = plan.resolvedAt(now)` unconditionally. The fix
computes the earliest failed date within the current `due` list (if any) and, when one exists, calls
`plan.resolvedAt(earliestFailure)` instead of `plan.resolvedAt(now)` — since `resolvedAt` sets
`lastResolvedDate` to whatever instant is passed, and `occurrences(after:)` is exclusive of that
value, this makes the failed date (and everything after it, even ones that "succeeded" in this same
sweep) eligible again on the next sweep.

This is a deliberate simplification over a per-occurrence retry set: if occurrence day 5 fails and
day 10 succeeds in the same sweep, the fix re-attempts day 10 too on the next sweep (it's already in
the entry table by then, so it's skipped as "already materialized" — no duplicate, just a wasted
lookup). Tracking a sparse retry set instead of a single cursor would avoid that redundant lookup but
adds real state-shape complexity (a set that must itself survive persistence) for a cost that's one
cheap idempotent check. Not worth it.

### Account type codes 8/9 (finding 3): explicit cases, not a generic fallback-throws rewrite

`_lifecycle` and `_frequency` in the same file also default unknown codes, but their defaults are
provably correct today (verified during the adversarial review — every real enum value has an
explicit case, the default only ever catches genuinely unknown/future codes). Only `_accountType` is
actually broken. Fix: add explicit `8 => AccountType.loan` and `9 => AccountType.overdraft` cases;
leave the default fallback in place for genuinely unrecognized codes (matches the project's
already-established `_lifecycle` pattern, not a throw — see Risks for why this one stays a default
rather than following `CategoryKind.fromCode`'s throw-on-unknown).

### referenceOnly release guard (finding 4): a real throw, sharing the referencedness check the purge path already computes

`_isHolderReferenced`/`_isCategoryReferenced` already exist and are what the debug-only invariant
calls. The fix moves the check (or a call to the same private helper) into `updateAccount`,
`updatePocket`, and `updateCategory` themselves: when the incoming lifecycle is `referenceOnly` and
the stored lifecycle isn't already `referenceOnly`, run the referencedness check and throw
`InactiveReference` (or a new, more precisely named error — see Open Questions) if it fails. This
reuses the existing helper rather than duplicating referencedness logic.

### Replay validation (finding 5): call the existing `_checked` path, not a new validator

`LedgerState` already has `_checked`/`assertInvariants` used by every mutator internally. The
straightforward fix is for `LedgerStateReplay.apply` to call `assertInvariants()` directly (not
through the debug-only `assert(() {...}())` wrapper) after the loop completes, and for the call site
that constructs a `LedgerState` from a replayed stream to catch whatever `assertInvariants` throws
and surface a real, catchable load error. This keeps one source of truth for what "valid" means
instead of writing a second, parallel check.

### Error message mapping (findings 8, and the holder-forms delta): one function, not three

`LedgerError` has a fixed, small set of subclasses. Rather than writing separate friendly-message
logic in `entry_form.dart`, `account_form.dart`, `category_form.dart`, and `source_edit_form.dart`,
this change adds one `String friendlyLedgerErrorMessage(LedgerError error)` function (location:
alongside `error_section.dart`, since that's the one widget every save-failure path already routes
through) and updates `ErrorSection` to call it instead of interpolating `error` directly. Every save
catch site keeps working unchanged since they already pass the error to `ErrorSection`.

### Stats screen shared state (finding 7): adopt `selectedMonthProvider` as-is

The provider already exists with the right shape (`StateProvider<DateTime>`) and is exercised by an
existing test (`app_shell_test.dart`). The fix replaces `_StatsScreenBodyState`'s local
`_selectedDate` field with `ref.watch(selectedMonthProvider)` / `ref.read(selectedMonthProvider.notifier).state = ...`,
converting the widget from `StatefulWidget` to a `ConsumerWidget` (or keeping it a
`ConsumerStatefulWidget` if other local state, like `_kind`/`_range`, stays put — those two aren't
part of this fix's scope, since the proposal and spec delta only cover the selected month/date, not
kind or range). `_kind` and `_range` remain screen-local; nothing in the adversarial review or the
spec flags them as needing to be shared.

## Risks / Trade-offs

- **[Existing corrupted accounts]** A user who already has a `loan` or `overdraft` account stored
  under this bug will have it sitting in their database as `AccountType.other` right now. This fix
  stops new corruption but does not un-corrupt data already on a device. → Out of scope for this
  change; flagged for the user, who can decide whether a one-time migration is worth writing given
  this is pre-launch personal-use software.
- **[`_accountType`'s default still swallows unknown codes]** Codes 10+ (there are none today) would
  still silently decode as `other` rather than throwing, unlike `CategoryKind.fromCode`. Fully
  closing this gap would mean rewriting `_accountType` to throw on any code without an explicit case
  — a bigger, riskier change to a function every account load goes through, for a case
  (`AccountType` growing an 11th value) that isn't imminent. → Accepted for now; the spec requirement
  ("Enum codes round-trip") is satisfied for every *currently defined* value, which is what the
  finding actually demanded.
- **[Plan cursor fix changes persisted plan state shape]** `resolvedAt(earliestFailure)` instead of
  `resolvedAt(now)` means a plan's `lastResolvedDate` after a partial failure will differ from what
  today's code would have stored. This is the intended fix, not a side effect, but it does mean a
  plan that hit this bug before the fix ships keeps its already-advanced (too-far) cursor — the fix
  only changes behavior going forward. → Accepted; matching the "Existing corrupted accounts" risk
  above, this is a pre-launch app and no migration is planned for already-skipped occurrences either.
- **[`referenceOnly` error type]** Reusing `InactiveReference` for this new release-reachable throw
  slightly overloads that error's existing meaning (today it means "the referenced row isn't
  active"). See Open Questions.

## Open Questions

None remaining. The one open question this file previously carried — reuse `InactiveReference` or
add a new `LedgerError` case for finding 4's release-reachable throw — is resolved: add a new sealed
subclass, `StillReferenced(id)`. `InactiveReference`'s 8 existing call sites all mean "you tried to
point a new reference at an inactive row"; the finding 4 check is the inverse — "you tried to retire
a row other things still point at" — and conflating the two under one persisted `_case` would leave
`friendlyLedgerErrorMessage` unable to give the right recovery text for each. The persistence
constraint on `_case` (`ledger_error.dart`'s doc comment: "the exact spelling is persisted, so
changing it breaks stored rows") is about renaming or removing an existing case, not adding a new
one — a new case is an additive, safe expansion, so it does not weigh against this.
