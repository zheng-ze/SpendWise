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
- Work is tracked as GitHub issues. The assignee is the claim. Record decisions on
  the issue; the PR body closes it with `Closes #<n>`.
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
- In widget code, never extract a piece as a `Widget _buildX()` method. Use a local or its own
  `StatelessWidget`.
- Every bottom sheet is an `AppSheet` that dismisses by dragging it down (phone) and by tapping
  outside it, and has no Cancel button. Header actions are only those that apply a choice, such as
  Done or Today. This deliberately differs from the approved reference frames, which draw Cancel.

## Nesting

- Keep all code flat, in every package and every language: production code, tests, and test setup.
  Nesting depth is 2 to 3 levels ideally and 5 at the absolute maximum. Never exceed 5.
- Depth counts every nested construct: widget constructors, callbacks and closures, control flow
  (`if`, `for`, `switch`, `try`), collection literals, and chained call arguments.
- Fix depth by naming pieces as locals before the final `return`, using early returns and guard
  clauses, and extracting a piece into its own function, class, or widget. The final expression
  reads as an outline.
- Test setup follows the same limit: extract a shared helper instead of repeating a provider-scope,
  app and shell pyramid in each test.
- Full rule: `.agents/rules/code-quality.md`, "Flat methods".

## Comments

- Write self-documenting code: name variables, functions, and types so the code explains itself
  without narration.
- Comments and docstrings are maintenance debt. The default is none. Add one only when it is
  strictly necessary: a maintainer would make a wrong change without it (a non-obvious constraint,
  invariant, or the reason behind a workaround). Never restate the code, reference other files,
  tickets, or sibling work, or duplicate a nearby comment. Full rule:
  `/Users/macbook/dev-tooling/claude/COMMENTS.md`.

## Tests

- Unit test every component's reachable behavior: domain, controllers, view models, flows,
  services, stores, and mappers. Cover each distinct happy path, each error path production can
  trigger, boundaries, and invariants.
- A hypothetical flow (an input, state, or path production cannot currently produce) may be tested
  as a defensive guard, but do not overdo it: one case per guarded edge, never a matrix of
  variants. Merge exact duplicates.
- Critical code is tested to 100 percent line and branch coverage with every error path: domain
  accounting and `LedgerState` invariants, ID and date normalization, persistence and mappers, and
  sync (engine, coordinator, enrollment, write gates).
- Test behavior, never visuals. Do not assert geometry, layout, spacing, insets, placement,
  scrolling extents, or colors. Do not test UI declarations (screens, sheets, rows, cards, pickers,
  charts, bars, theme).
- Write a widget test only for behavior logic tests cannot prove, such as navigation, route
  lifetime, or a past behavior defect.
- Coverage is advisory at 80 to 90 percent of the filtered figure from
  `app/tool/coverage_summary.dart`, which excludes generated code and UI declarations. It never
  blocks a change.
- Full rule: `.agents/rules/testing-and-mocking.md`, "Test proportion and selection".

## Checks

Run `cd packages/domain && dart format . && dart analyze && dart test`, then run
`cd app && flutter analyze`. The analyzer must report zero issues. For coverage, run
`cd app && flutter test --coverage && dart run tool/coverage_summary.dart coverage/lcov.info`.
