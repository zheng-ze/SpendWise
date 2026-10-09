# SpendWise

SpendWise is a personal finance app built in Flutter.

## Project map

- `packages/domain/` contains pure Dart models, `LedgerState`, and accounting. It must not depend on
  Flutter.
- `app/` is the Flutter app and depends on `domain` by path.
- `docs/` contains behavior specs, architecture decisions, and working procedures.
- `docs/knowledge/` is the feature knowledge base. One entry per feature; read the relevant entry
  before planning or changing a feature. Start at `docs/knowledge/INDEX.md`.
- `CONTEXT.md` is the domain glossary and index. Read it first when working on the domain.

## Read before work

- For a feature change, open `docs/knowledge/INDEX.md`, read that feature's entry, then check its
  `Last reconciled:` marker for possible staleness.
- Read `docs/NAVIGATION.md` for the required reading order and the greenfield-design boundary.
- See `docs/agents/issue-tracker.md` for GitHub issue conventions.
- See `docs/agents/domain.md` for the `CONTEXT.md` and ADR layout.
- Read `docs/DOMAIN.md` before changing `LedgerState` or its invariants.
- See `docs/HANDOVER.md` when continuing the repository's recorded working state.

## Domain conventions

- Mutators validate, mutate, then return `List<LedgerChange>`.
- Use `Decimal` for money. `double` in `packages/domain/lib/` is a defect.
- Normalize IDs to lowercase UUID strings at every construction boundary.
- Give int-coded enums an explicit `code`; never persist `enum.index`.
- Use half-open `[start, end)` windows.
- A domain date is UTC midnight for its named calendar day. Normalize it with `startOfDayUtc`, never
  `.toUtc()`.
- `packages/domain/` holds money-world logic only. Screen, layout, and presentation calculations
  belong in `app/`.
- Mockup data is reference only and never acceptance criteria.

## App UI code

- Name every visual value as an easy-to-find constant, including self-explanatory values such as a
  1px divider, transparent color, spacing, radius, and chart axis.

## Comments

- Write self-documenting code: name variables, functions, and types so the code explains itself
  without narration.
- Comments and docstrings are maintenance debt. The default is none. Add one only when it is
  strictly necessary: a maintainer would make a wrong change without it (a non-obvious constraint,
  invariant, or the reason behind a workaround). Never restate the code, reference other files,
  tickets, or sibling work, or duplicate a nearby comment. Full rule:
  `/Users/macbook/dev-tooling/claude/COMMENTS.md`.

## Checks

Run `cd packages/domain && dart format . && dart analyze && dart test`, then run
`cd app && flutter analyze`. The analyzer must report zero issues.
