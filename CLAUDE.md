# SpendWise

A personal finance app built in Flutter. The app reached full parity with an earlier native
prototype; work past that point (starting with `add-budgets`) is greenfield design, not a port —
design from domain/product reasoning and this repo's own conventions.

## Agent skills

### Issue tracker

Issues live as GitHub issues on `zheng-ze/SpendWise`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context layout: `CONTEXT.md` + `docs/adr/` at the repo root, created lazily by `/domain-modeling`. See `docs/agents/domain.md`.

## Response style

**Default to the `terse` skill for every session.** `.claude/hooks/terse-activate.sh` injects its
ruleset on `SessionStart`, and `.claude/hooks/terse-reinforce.sh` re-injects a short reminder on
every `UserPromptSubmit` so the style survives context compaction mid-session — both wired in
`.claude/settings.json`. This governs chat replies only; comments, docstrings, and prose docs are
untouched by it and go through `tech-writer` instead. "stop terse" or "normal mode" turns it off.

## Layout

- `packages/domain/` — pure Dart. Models, `LedgerState`, accounting. Has no Flutter dependency and
  must never gain one; that is what keeps the domain portable and testable.
- `app/` — the Flutter app. Depends on `domain` by path.
- `docs/` — behavior specs (`docs/specs/`), architecture decisions (`docs/adr/`) and working
  procedure.
- `CONTEXT.md` — the domain glossary and index, at the repo root. Read this first: it defines the
  vocabulary and points at every ADR and spec.

**Read `docs/NAVIGATION.md` before starting work.** It is the reading order across `CONTEXT.md`,
`docs/adr/` and `docs/specs/`, plus the older module docs and `docs/ARCHITECTURE.md`. The app is at
full parity with an earlier native prototype; work from the budgets feature onward is greenfield
design, not a port — see `docs/NAVIGATION.md` for what that changes about how to read `docs/adr/`.

**Invoke `spec-keeper` at exactly two points in any change that touches behavior**: once right
after a plan is settled, before implementation starts, and once right after implementation is
done, before reporting green. Not per edit — checking specs on every file touch spends tokens
`docs/specs/` doesn't need spent that often. This applies regardless of which skill is driving —
`wayfinder`, `grilling`, `domain-modeling`, `tdd`, `prototype`, or plain unassisted work. `CONTEXT.md`
only indexes `docs/specs/` files by name; it never inlines their content. A `wayfinder` map's
`## Notes` block should name `spec-keeper` alongside `/grilling` and `/domain-modeling` whenever the
effort's destination is, or depends on, behavior a spec describes.

## Conventions

**Comments, docstrings and prose docs (README, design doc, guide): use the `tech-writer` skill.**
It carries the full comment rules (minimal, standalone, two-line cap, `///` vs `//`, write/verify
discipline) plus the Google Developer Documentation Style Guide for prose. Auto-triggers on doc/
comment requests; invoke it directly if it doesn't fire. `docs/WORKING-CONVENTIONS.md` has the
failure patterns behind the rule.

**Run a `tech-writer` comment pass once implementation is done, before reporting green** — same
checkpoint as `spec-keeper`'s post-implementation run, and fine to do in the same pass.

**Plain language everywhere**, not only in task files: comments, identifiers and reports alike. Say
what a thing does in ordinary words rather than in jargon or borrowed vocabulary. A function called
`monthWithDayUtc` needed a comment to explain that it shifts the month before clamping the day;
`shiftMonthThenClampDayUtc` needed none.

**Mutators validate, mutate, then return `List<LedgerChange>`.** Every mutation on `LedgerState`
keeps this contract.

**Money is `Decimal`, never `double`.** `double` in `packages/domain/lib/` is a defect.

**IDs are lowercase uuid strings**, normalized at every construction boundary.

**Int-coded enums** carry an explicit `code` field, never `enum.index` — persistence writes these
codes, and `enum.index` shifts silently if a variant is ever reordered.

**Window filters are half-open `[start, end)`** everywhere.

**A domain date is UTC midnight of the calendar day it names.** Normalize with `startOfDayUtc` in
`calendar_day.dart`, which is day-preserving. Never `.toUtc()`, which preserves the instant and so
moves a local midnight back a day for every user east of Greenwich. `design.md` in
`add-domain-accounting` has the full ruling.

**Touching `LedgerState` or its invariants: read `docs/DOMAIN-INVARIANTS.md` first.** Covers how
illegal states are made unreachable and why `LedgerState` is split into `part` files by concern.

## Checks

`cd packages/domain && dart format . && dart analyze && dart test`, and `cd app && flutter analyze`.
Analyzer must be at zero issues, not just zero errors.

## Working with this repo

**Feature work happens on `dev`, never directly on `main`.** `main` only moves via a reviewed PR.
When a change is ready, open a PR from the working branch targeting `main` and wait for review and
merge — do not push feature commits straight to `main`, and do not merge a PR yourself unless the
user explicitly asks. Creating the PR itself still needs the user's go-ahead, same as any other
action visible to others.

**Close an issue only after its PR merges to `main`, not when implementation goes green on `dev`.**
Verifying green on `dev` is the point to comment on the issue with a link to the PR, not to close
it — closing is what confirms the work actually shipped. Check the PR's merge state
(`gh pr view <n> --json state,mergedAt`) before closing the issue it resolves.

**The user commits themselves — never run `git commit`.** Report green and hand it over. When
staging uncommitted work for them, split it into logical chunks and wait for a go-ahead between
each — `docs/WORKING-CONVENTIONS.md` has the pattern.

**Never `git checkout`, `git restore`, `git stash`, `git reset` or `git clean`.** Restore a mutated
file from a file copy. Under parallel agents these would discard another agent's work. This is
enforced by a blanket `settings.json` deny, so it also blocks the harmless-looking case — unstaging
an already-`git add`ed file with `git restore --staged` or `git reset <path>` — even though that
touches the index, not working-tree content. Don't retry with different flags or paths; either ask
before staging next time, or stage forward past the mistake instead of trying to walk it back.

**Tests first, then implementation.** Write the test against the unfixed code and watch it go red —
that red is the proof it bites, so no mutate-and-revert step is needed. Then fix, then watch it go
green. A test that passes before the fix lands is testing nothing. Any scenario an audit probe ran
belongs in the committed suite.

**A test that cannot fail is worse than no test**, because it reports safety that is not there. When
a test uppercases an id to prove normalization, check the id actually contains letters. An entire
normalization suite here passed because its helper uppercased a digits-only uuid and returned it
unchanged.

**Open work is tracked as GitHub issues, not a `tasks.md`.** See `docs/agents/issue-tracker.md` for
the conventions. A subagent reports what it landed; verify at the cited `file:line` before closing
or commenting on the issue — the same verify-before-trusting discipline this file states elsewhere.
At a phase boundary run adversarial reviews from several angles and file the confirmed gaps as
issues — the `adversarial-review` skill has the procedure.

**Verifying is not the deliverable; the next task is.** A request to check something finished is a
request to check it *and then keep going*, so a turn that audits, reports and stops has done a
fraction of the job. Verification earns its place by unblocking the next piece of work, not by
existing.

**Treat every finding as unverified until read at the cited `file:line`.** This covers a subagent's
own "still open" claims and your own retelling of a subagent's finding, not just its first report.
**`docs/WORKING-CONVENTIONS.md` has the failure patterns**, and also covers what a handover doc
(`docs/HANDOVER.md`) should and should not contain.

Most implementation runs through subagents, one task group at a time. **`docs/SUBAGENTS.md` has the
dispatch procedure** — which agent for which job, how to fence parallel work, and where `pal`'s
`chat` tool pays. Two rules from it that are never worth rediscovering:

- **Grant `Bash` to any agent that must prove its work runs.** An agent without it can only claim.
  It is a floor, not a default: read-only agents do not need it.
- **Split parallel work by file ownership, never by workflow step.** The write-test, watch-red, fix,
  watch-green loop is the unit of proof and stays inside one agent.

## Search tools

**Read `docs/SEARCH-TOOLS.md` before locating code or deciding whether to dispatch a subagent.**
Covers narrowing before reading, sending volume reading to `pal`, and when delegation is mandatory
rather than optional. One rule from it that is never worth rediscovering: `rg` never reports a false
zero and everything else can.

**For a token-cheap locate/edit/review, use the `cavecrew` skill's three agents** —
`cavecrew-investigator` (locate), `cavecrew-builder` (1-2 file surgical edit), `cavecrew-reviewer`
(diff review) — before reaching for a vanilla `Explore` or a full-prose reviewer. Their output is
compressed in the `terse` skill's register, so a delegation costs roughly a third of the main-context
tokens a prose subagent would. `terse-review` gives the same one-line-per-finding format for a
human-facing PR review. All four live in this repo's `.claude/skills/` and `.claude/agents/`, and
Claude Code auto-discovers skills/agents from those paths for any agent working in this repo — no
per-session activation needed for the agents themselves (only `terse`'s chat-reply style needs the
hooks above, since that has to survive mid-session drift, not just be discoverable once).

**A skill missing from the discovered-skills listing may just be manual-only, not absent** — see
`docs/MANUAL-SKILLS.md` before concluding a review/architecture skill doesn't exist.
