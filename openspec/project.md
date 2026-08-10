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

A change's `specs/` state the behavior contract in prose. They were derived from `docs/modules/*.md`,
which are longer and more precise — for Phase 1 that is `docs/modules/domain_models.md`, whose section
numbers the design and task files cite directly. When a change's spec and the module spec appear to
disagree, the module spec wins and the change's spec is the thing to correct.

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
- **IDs are lowercase uuid strings**, canonicalized at every construction boundary via
  `canonicalOrNewID` / `canonicalOptionalID` in `lib/src/ids.dart`. The legacy SQLite database holds
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
  an explicit clamp.
- **Occurrence ids are UUIDv5 over SHA-1.** The already-present `uuid` package exposes `v5`, so no new
  dependency is needed. The name string is measured in seconds from 2001-01-01 UTC, not the Unix
  epoch.

## Comment style

Minimal. Comment only tricky nuance, deliberate spec deviations, or ordering constraints a reader
would otherwise break. Never restate what the code says. Also:

- No reference to the Swift project in code comments. Treat this as a fresh codebase.
- No em dashes and no semicolons in comment prose.

## Checks

```sh
cd packages/domain && dart format . && dart analyze && dart test
cd app && flutter analyze
```

The analyzer must be at zero issues, not just zero errors. Toolchain: Flutter 3.44.9 / Dart 3.12.2.

## Working style

The user commits themselves — do not run `git commit`. Report when something is green and let them
take it.

They review closely and push back on unnecessary abstraction. Several things in the codebase exist in
reduced form because a first attempt was rejected as over-built. When in doubt, build the smaller
thing and let them ask for more. Verify claims against the code before asserting them — a "this is
load-bearing" that turns out to have zero callers costs more than the check would have.
