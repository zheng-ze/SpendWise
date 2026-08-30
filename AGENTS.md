# SpendWise

SpendWise is a personal finance app built in Flutter.

## Project map

- `packages/domain/` contains pure Dart models, `LedgerState`, and accounting. It must not depend on
  Flutter.
- `app/` is the Flutter app and depends on `domain` by path.
- `docs/` contains behavior specs, architecture decisions, and working procedures.
- `CONTEXT.md` is the domain glossary and index. Read it first when working on the domain.

## Read before work

- Read `docs/NAVIGATION.md` for the required reading order and the greenfield-design boundary.
- See `docs/agents/issue-tracker.md` for GitHub issue conventions.
- See `docs/agents/domain.md` for the `CONTEXT.md` and ADR layout.
- Read `docs/DOMAIN-INVARIANTS.md` before changing `LedgerState` or its invariants.
- See `docs/HANDOVER.md` when continuing the repository's recorded working state.

## Domain conventions

- Mutators validate, mutate, then return `List<LedgerChange>`.
- Use `Decimal` for money. `double` in `packages/domain/lib/` is a defect.
- Normalize IDs to lowercase UUID strings at every construction boundary.
- Give int-coded enums an explicit `code`; never persist `enum.index`.
- Use half-open `[start, end)` windows.
- A domain date is UTC midnight for its named calendar day. Normalize it with `startOfDayUtc`, never
  `.toUtc()`.

## Checks

Run `cd packages/domain && dart format . && dart analyze && dart test`, then run
`cd app && flutter analyze`. The analyzer must report zero issues.
