---
name: spendwise-project-rules
description: Non-negotiable technical rules for the SpendWise Flutter port. Load before writing any change artifact or domain code.
globs: ["**/*"]
alwaysApply: true
---

# SpendWise — project rules

A Flutter rewrite of a finished SwiftUI app. The Swift app is frozen at `../SpendWise-SwiftUI` and is
the source of truth for behavior. Its own CLAUDE.md is stale — trust the Swift code, not its docs.

## Layout

- `packages/domain/` — pure Dart. Models, `LedgerState`, accounting. No Flutter dependency, ever.
- `app/` — the Flutter app. Depends on `domain` by path.
- `docs/` — behavior specs. `Flutter_Port_Tech_Doc.md` is the master plan, `docs/modules/*.md` are the
  per-phase specs, `docs/reviews/` are completed adversarial passes whose corrections are already
  applied. Do not re-litigate review findings.

`packages/domain/pubspec.yaml` has no `flutter:` key. That single omission is the whole purity
mechanism — `import 'package:flutter/...'` there fails to resolve. Do not add one.

## Where the specs live

`openspec/specs/` holds the promoted contracts — the behavior an archived change has already
delivered. Phase 1 promoted five: `ledger-state`, `ledger-mutations`, `ledger-lifecycle`,
`ledger-plans`, `ledger-invariants`. An open change's `specs/` state its own contract as a delta and
are merged here when the change is archived (`openspec/changes/archive/<date>-<name>/` keeps the
change itself).

Both kinds were derived from `docs/modules/*.md`, which are longer and more precise — for Phase 1
that is `docs/modules/domain_models.md`, whose section numbers the design and task files cite
directly. When a spec and the module spec appear to disagree, the module spec wins and the spec is
the thing to correct.

`docs/HANDOVER.md` is historical: it records why commits 1.1 and 1.2 were built the way they were, and
nothing about work still to come. The plan for outstanding work is the tasks file of the open change.
This file, not `CLAUDE.md`, is the authoritative statement of the rules below; `CLAUDE.md` carries a
summary of them and a reading order.

## The port is a translation, not a redesign

Type names match Swift (`LedgerState`, `Entry`, `MoneySource`, `TransactionCategory`, `LedgerChange`,
`LedgerError`). Deviations happen only where a spec's "KNOWN DEFECT" or "PORT FIX" section sanctions
one. Inventing behavior the spec does not describe is a defect, even when it looks like an
improvement.

## Domain rules

- **Money is `Decimal`, never `double`.** A `double` anywhere in `packages/domain/lib/` is a defect.
- **IDs are lowercase uuid strings**, normalized at every construction boundary via
  `normalizedOrNewID` / `normalizedOptionalID` in `lib/src/ids.dart`. The legacy SQLite database holds
  uppercase ids, so this is load-bearing. Case-insensitivity is safe only because uuids are hex —
  never route a case-sensitive id through these helpers.
- **Int-coded enums carry an explicit `code` field** pinned to the Swift raw value, never
  `enum.index`. Persistence writes these codes. `fromCode` throws `ArgumentError` on an unknown code
  so a corrupt or newer-version row surfaces as a load error rather than being silently absorbed.
- **Window filters are half-open `[start, end)`** everywhere.
- **Models are immutable with hand-written value `==`/`hashCode`.** This is load-bearing: change
  payloads carry stored objects and the change-emission tests compare change lists by value. A
  mutable model would let a mutator edit an object already emitted in a change, and the test would
  compare an object to itself and pass regardless. `equatable` is deliberately not used — its `props`
  list is a silent-failure surface for exactly those tests.
- **Mutators keep the `validate → mutate → return List<LedgerChange>` contract.**

## Illegal states are unreachable, and invariants only catch what slips

`_checked` runs `assertInvariants` inside an `assert(() {...}())`, so **every invariant clause is
debug-only** and a release build pays nothing and catches nothing. The invariants are a backstop
against a future mutator's mistake, never the primary defense. Anything a release build must not do
has to be impossible by construction, or a real throw.

Two mechanisms carry that weight:

- **The maps are closed.** `_moneySources`, `_entries`, `_categories` and `_plans` are private, and
  the public getters return `UnmodifiableMapView`. Every illegal state the audits demonstrated —
  a pocket claimed by two accounts, an orphan active pocket, order-dependent `_owningAccount` —
  required writing to a map directly. Closing them is what made the class of bug unreachable rather
  than merely unlikely.
- **One row remover per row kind.** `_detachAndTombstonePocket` is the sole remover of a pocket row,
  killing the row and the parent's link in one operation, so a dangling link has no window to exist
  in. Route new removal paths through it rather than repeating the pair.

Inverting the pocket-parent link (`pocket.parentID` instead of `Account.subPocketIDs`) was
considered and **rejected**: it contradicts the translation rule on the structure the whole domain
is keyed to, and it would silently drop the `UpsertAccount` that `addPocket` emits, which the
change-emission tests pin. The root cause was the open maps, not the link direction.

Reject rather than silently coerce when the caller would otherwise not learn they were wrong.
`addPocket` throws `InactiveReference` on a non-active parent instead of demoting the incoming
pocket. A category's `kind` is fixed at creation: `updateCategory` throws `CategoryKindMismatch`
rather than moving a category between kinds, so a user creates a new category instead.

Where a check has to survive into release — a corrupt store on load being the live example — it
needs a real conditional throw and a user-visible error, not an `assert` and not a silent load.

## Scope: Recurring Plans land inside the ledger core

Plans were deferred until accounts and entries existed, not dropped, since purge and the dereference
sweep are what the plan cascade hooks into. Those are now in place, so plans are group 8 of
`complete-domain-ledger-core`, ahead of the invariants: clauses 7 and 8 (dangling plan reference,
exhausted plan) are then written once against real plan data rather than added later as an amendment.

Group 8 covers `RecurringPlan` / `EntryTemplate` / `RecurrenceFrequency`, `OccurrenceID`, the
`LedgerState.plans` map, the plan mutators, `resolvePlans`, and the plan cascade in `deleteAccount`.
With it `LedgerChange` reaches its full 9 cases (adding `upsertPlan`, `deletePlan`) and `LedgerError`
its full 12 (adding `unknownPlan`, `exhaustedPlan`).

Two places where a straight translation of the Swift would be wrong:

- **Month-end strides clamp.** `Calendar.date(byAdding:)` clamps a monthly stride off 31 January to
  the end of February. Dart's `DateTime` constructor overflows into March instead, so the port needs
  an explicit clamp. Every stride is measured from the anchor rather than from the previous
  occurrence, so the clamping never accumulates.
- **Occurrence ids are UUIDv5 over SHA-1.** The already-present `uuid` package exposes `v5`, so no new
  dependency is needed. The name string is measured in seconds from 2001-01-01 UTC, not the Unix
  epoch.
- **The plan id goes into the UUIDv5 name in lowercase normalized form.** Swift builds the name from
  `planID.uuidString`, which Foundation renders **uppercase**; the port routes the plan id through
  `normalizedID` first, so the name carries the lowercase form. A UUIDv5 name is hashed bytewise, so
  the two cases are different names and the same plan and day therefore yield a **different occurrence
  id here than in the Swift app**. This is intentional and is not a defect to repair. The frozen
  SwiftUI app is a behavioral reference, not a conformance target, and lowercase normalized ids are a
  project-wide rule (see Domain rules above) precisely so that no id's identity depends on the case it
  happened to be written in. Matching Swift byte-for-byte would mean reintroducing an uppercase id at
  exactly the boundary the rule exists to normalize. Nothing cross-reads occurrence ids between the two
  apps, so the divergence has no consumer. Keep the plan id normalized on the way into the name
  regardless of how the rest of the derivation evolves.

**Archival freezes a plan; deletion removes it.** These are two different rules and the distinction is
deliberate.

- `deleteAccount` hard-removes every plan naming the account or any of its pockets. Archiving an
  account is a whole-holder retirement that takes its pockets with it.
- `deletePocket` and `deleteCategory` remove nothing. The plan stays, its occurrences fail validation
  while the row is inactive, and `resolvePlans` reports those failures instead of throwing. Archiving
  a single pocket or category is routine tidying a user is expected to undo, and dropping plans on the
  archive step would make restore silently lossy, since nothing holds an archived plan to bring back.
  This is also the only way to reach the `PlanFailure` path through the public API, which is what the
  `resolvePlans failures` test group exercises.
- Every path that DELETES a row outright rather than archiving it must take the plans naming that row
  with it: the dereference sweep (`_sweepHolder`, `_sweepCategory`) and the purge row helpers.
  Otherwise a plan is left naming a row that no longer exists, violating invariant clause 7.

Invariant clause 14 encodes exactly this: a plan may name an **archived** row, but never a
`referenceOnly` or `tombstoned` one.

## Comment style

Minimal. Comment only tricky nuance, deliberate spec deviations, or ordering constraints a reader
would otherwise break. Never restate what the code says. Also:

- No reference to the Swift project in code comments. Treat this as a fresh codebase.
- No em dashes and no semicolons in comment prose, and no colon splicing two thoughts together.
- No spec or doc citations in source. Section numbers belong in the change's design and tasks files.
- Comment budget applies to tests too. The test name carries the intent; a comment earns its place
  only where an assertion looks wrong without it.

## File and helper shape

Keep each file's scope small and single-purpose. `LedgerState` is split by concern into
`ledger_state_holders`, `_categories`, `_entries`, `_plans`, `_purge`, `_queries` and `_invariants`
as `part` files of one class rather than one long file. Pull repeated bodies into a named helper.

The counter-pressure is real and has been applied: a file whose whole content was a couple of date
helpers was judged too small a scope and folded into `plan_scheduling.dart`. Split by concern, not
by symbol count.

## Checks

```sh
cd packages/domain && dart format . && dart analyze && dart test
cd app && flutter analyze
```

The analyzer must be at zero issues, not just zero errors. Toolchain: Flutter 3.44.9 / Dart 3.12.2.

## Working style

The user commits themselves — do not run `git commit`. Report when something is green and let them
take it. When asked for a commit message: Conventional Commits, succinct, describing what changed.
Do not mention adversarial reviews, subagents, or how the work was produced.

They review closely and push back on unnecessary abstraction. Several things in the codebase exist in
reduced form because a first attempt was rejected as over-built. When in doubt, build the smaller
thing and let them ask for more. Verify claims against the code before asserting them — a "this is
load-bearing" that turns out to have zero callers costs more than the check would have.

### Delegating to subagents

Most implementation here runs through subagents, one task group at a time, parallel only where the
groups touch disjoint files. Two failure modes have cost real time:

- **A subagent without `Bash` cannot verify anything.** Several returned "cannot run `dart analyze`
  / `dart test`, please run them yourself" after writing code, which makes the report worthless as
  evidence. Grant `Bash` to any agent that writes code, or run the gate in the main thread and treat
  the report as a claim rather than a result.
- **Report findings are unverified until checked at the cited file:line.** An audit has reported as
  CRITICAL behavior that the spec explicitly requires, taking three dependent findings down with it.
  Running two agents from different angles surfaces the disagreement.

A subagent may cite a user instruction that is nowhere in the main transcript and still be telling
the truth: the user intervenes in a running subagent directly, and those messages never reach the
main thread. Judge the instruction against the spec and the code, not against the transcript.

### Task list hygiene

`tasks.md` in the open change is the queue and the record, and only the main thread edits it. A
subagent reports what it landed; the main thread verifies at the cited `file:line` and ticks. This
keeps the record a statement of what was checked rather than what was claimed, and it keeps two
agents from writing the same file. Tick items as they land. When new work is inserted mid-list,
renumber the items below it or append at the end — do not leave two 10.1s. Before starting a group,
confirm the groups it depends on are actually complete rather than merely ticked.

### Review before a phase boundary

At the end of a phase, run adversarial reviews from several angles before moving on, consolidate the
findings into `tasks.md`, and fix from there. Confirmed gaps become numbered tasks, not ad-hoc edits.
See the `adversarial-review` skill.

### Tests

Write the tests first, then the implementation. A test that cannot fail is worse than no test, so
run each new test against the unfixed code and watch it go red before writing the fix. That red is
the proof it bites, which is why nothing has to be mutated and reverted afterward. Then land the fix
and watch the same test go green. A test that was already green before the fix is pinning something
other than the defect, and says so loudly if it is written first. When an audit or probe
demonstrates a finding, the scenario it ran belongs in the committed suite. Assert the whole change
list, and assert that a throwing path left state untouched.
