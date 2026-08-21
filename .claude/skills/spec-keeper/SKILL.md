---
name: spec-keeper
description: Run at two checkpoints only — once a plan is settled (before implementation starts) and once implementation is done (before reporting green) — to consult docs/specs/ and keep it in sync with behavior. Not a per-edit or continuous check. Use right after a plan is finalized, or right before declaring a change complete, or when CONTEXT.md's index needs a new entry after a spec is added, renamed, or retired.
disable-model-invocation: false
---

# Skill: Spec keeper

`docs/specs/*.md` are this repo's behavior contracts — Given/When/Then requirements for one
capability each, replacing what OpenSpec used to hold. No Matt Pocock plugin skill owns them:
`domain-modeling` explicitly keeps `CONTEXT.md` glossary-only and calls it "not a spec, not a
scratch pad, not a repository for implementation decisions." This skill is the thing that fills
that gap for this repo specifically.

**Two checkpoints, not a continuous concern.** Checking specs on every edit burns tokens on a
question that only changes shape once per change: what a plan touches, and what actually landed.
Run this skill exactly twice per change — right after the plan is settled, and right after
implementation is done — never per file edit.

## Checkpoint 1: right after a plan is settled, before implementation starts

1. Check `CONTEXT.md`'s `## Index` section for the spec file(s) covering the area you're about to
   touch — it lists every current file under `docs/specs/`, grouped by domain core / runtime / UI.
2. Read the specific spec file(s), not just the index line. A spec's Given/When/Then scenarios are
   the actual contract; planning against the index alone risks missing a scenario the new behavior
   would break.
3. If the spec and the current code already disagree — the spec describes something the code
   doesn't do, or vice versa — surface this before proceeding. Don't silently trust either side;
   name the conflict and ask which one is wrong, the same way `domain-modeling`'s "cross-reference
   with code" step does for `CONTEXT.md`.

## Checkpoint 2: right after implementation is done, before reporting green

Update the relevant `docs/specs/<name>.md` in the **same change**, not as a follow-up:

- A new requirement or scenario: add it under the right `### Requirement` heading, with a
  `#### Scenario` block in the existing Given/When/Then shape.
- A changed rule: edit the requirement text in place. Don't leave the old wording next to the new
  behavior — a spec that contradicts the code it describes is worse than no spec.
- A removed capability: delete the requirement, or the whole file if the capability is gone
  entirely. A stale spec for dead behavior is a false trail for the next reader.
- A new capability with no existing spec file: create `docs/specs/<new-name>.md` following the
  shape of a neighboring file (`## Purpose`, then `### Requirement` / `#### Scenario` blocks), then
  add it to `CONTEXT.md`'s index in the same edit — the index must never drift from what's actually
  under `docs/specs/`.

## Offering an ADR

If the change you just made was a genuine decision — hard to reverse, surprising without context,
and the result of a real trade-off (the same three-part test `domain-modeling` uses) — offer to
record it in `docs/adr/` rather than folding the reasoning into the spec. A spec states what must be
true; an ADR explains why this way was chosen over a real alternative. Keep the two separate: don't
let a spec file accumulate "we considered X but..." prose that belongs in an ADR instead.

## What this skill does not do

It does not replace `domain-modeling` for `CONTEXT.md` or ADR work — invoke that skill for
glossary/decision work as usual. This skill's only job is the layer `domain-modeling` explicitly
declines to own: the detailed behavior contracts and keeping `CONTEXT.md`'s index of them accurate.
