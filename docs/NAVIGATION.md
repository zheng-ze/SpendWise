# Where to look

Planning lives in `CONTEXT.md`, `docs/adr/` and `docs/specs/`. Read in this order.

1. `CONTEXT.md` — the domain glossary and an index pointing at every ADR and spec location. Start
   here for vocabulary and for what exists.
2. `docs/adr/` — the decisions: what was chosen, what was rejected, and why. Read the ones
   touching the area you're about to work in before changing it. Numbered `0001` onward,
   roughly chronological by when each decision was made.
3. `docs/specs/` — the behavior contracts (Given/When/Then requirements), one file per capability,
   28 files covering domain core, runtime and every UI screen. This is "what the code must do";
   it does not carry the "why," which lives in the ADRs instead.
4. `docs/modules/*.md` — longer, more detailed behavior specs that some of the contracts in
   `docs/specs/` were originally derived from: `domain_models.md`, `plans_and_accounting.md`,
   `ledger_runtime.md`, `persistence.md`, `ui_screens.md`. Still the reference for anything a spec
   in `docs/specs/` leaves ambiguous.
5. `docs/Flutter_Port_Tech_Doc.md` — the master plan for the port from the frozen SwiftUI
   prototype. §6 defines the phases the port went through, §1 lists the V1 defects the port fixed,
   §8 is the definition of done. Historical now that the port is complete and past work is
   greenfield design (see below), but still the record of what each phase covered and why.
6. `docs/reviews/` — completed adversarial and quality-review passes. All confirmed corrections
   are already applied, either directly or via a later ADR recording the fix (see ADR-0050 for the
   review currently in this directory). Do not re-litigate their findings; if one looks
   unresolved, check `docs/adr/` first for the ADR that already covers it.

## Current planning system

This repo used to plan work through OpenSpec (`openspec/`), which has been retired. `CONTEXT.md`
plus `docs/adr/` plus `docs/specs/` replace it entirely: `CONTEXT.md` is the glossary and index,
ADRs hold decisions, specs hold behavior contracts. Open work items — the equivalent of what used
to be an OpenSpec change's `tasks.md` — are tracked as GitHub issues; see
`docs/agents/issue-tracker.md`.

The frozen SwiftUI app at `../SpendWise-SwiftUI` was the source of truth for behavior through the
end of the port (everything through `add-drift-store`). Its own CLAUDE.md is stale, so trust the
Swift code over its docs if you ever need to check it. **The app reached full parity with that
prototype once the port finished; work past that point (starting with the budgets feature) is
greenfield design, not a port** — design from domain and product reasoning and this repo's own
conventions, not by reading the Swift source. `docs/adr/` reflects this split: decisions up through
the persistence layer are mostly translation calls (where a straight port of the Swift behavior
would have been wrong, and what replaced it); decisions from the budgets feature onward are
original product and architecture calls with no Swift equivalent to check against.
