# SpendWise

A personal finance app built in Flutter. The app reached full parity with the earlier frozen
SwiftUI prototype at `../SpendWise-SwiftUI`; work past that point (starting with `add-budgets`) is
greenfield design, not a port — design from domain/product reasoning and this repo's own
conventions, not by reading the Swift source.

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
- `docs/` — behavior specs and working procedure.
- `openspec/` — the planned work. `project.md` holds the full technical rules (this file is its
  summary); `changes/<name>/` holds each change's proposal, specs, design and tasks.

**Read `docs/NAVIGATION.md` before starting work.** It is the reading order, the phase table and the
sequencing rules. Two things from it that decide what you may touch: the current change is
`add-transactions-ui`, and **the four screen changes all build on `add-app-shell-and-boot`**, so a
screen never introduces its own formatter, symbol map or month state.

## Conventions

**Comments, docstrings and prose docs (README, design doc, guide): use the `tech-writer` skill.**
It carries the full comment rules (minimal, standalone, two-line cap, `///` vs `//`, write/verify
discipline) plus the Google Developer Documentation Style Guide for prose. Auto-triggers on doc/
comment requests; invoke it directly if it doesn't fire. `docs/WORKING-CONVENTIONS.md` has the
failure patterns behind the rule.

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

**The user commits themselves — never run `git commit`.** Report green and hand it over. When
staging uncommitted work for them, split it into logical chunks and wait for a go-ahead between
each — `docs/WORKING-CONVENTIONS.md` has the pattern.

**Run `git add -N <path>` on every file you create, agents included.** It is the one git write
allowed here. The knowledge graph indexes git-tracked files only, so an untracked file is invisible
to it, and `-N` registers the path without staging any content — `git diff --staged` stays empty and
nothing reaches a commit. A `PostToolUse` hook rebuilds the graph after every edit, so registering
the path is all an agent has to do. Bare `git add`, `git add -A` and `git add .` stay denied: those
stage content and that is the user's call. Delete a registered file and git will show it as `D` until
the user clears it, so do not register scratch files.

**Never `git checkout`, `git restore`, `git stash`, `git reset` or `git clean`.** Restore a mutated
file from a file copy. Under parallel agents these would discard another agent's work.

**Tests first, then implementation.** Write the test against the unfixed code and watch it go red —
that red is the proof it bites, so no mutate-and-revert step is needed. Then fix, then watch it go
green. A test that passes before the fix lands is testing nothing. Any scenario an audit probe ran
belongs in the committed suite.

**A test that cannot fail is worse than no test**, because it reports safety that is not there. When
a test uppercases an id to prove normalization, check the id actually contains letters. An entire
normalization suite here passed because its helper uppercased a digits-only uuid and returned it
unchanged.

**`tasks.md` in the open change is the queue and the record, and only the main thread edits it.** A
subagent reports what it landed and the main thread ticks after verifying at the cited `file:line`.
Tick as you land, renumber or append when inserting, and check a group's dependencies are really
done before starting it. At a phase boundary run adversarial reviews from several angles and file
the confirmed gaps as numbered tasks — the `adversarial-review` skill has the procedure.

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
rather than optional. Two rules from it that are never worth rediscovering: `rg` never reports a
false zero and everything else can, and the knowledge graph sees git-tracked files only — `git add -N`
on a file you create is what makes it visible.

**For a token-cheap locate/edit/review, use the `cavecrew` skill's three agents** —
`cavecrew-investigator` (locate), `cavecrew-builder` (1-2 file surgical edit), `cavecrew-reviewer`
(diff review) — before reaching for a vanilla `Explore` or a full-prose reviewer. Their output is
compressed in the `terse` skill's register, so a delegation costs roughly a third of the main-context
tokens a prose subagent would. `terse-review` gives the same one-line-per-finding format for a
human-facing PR review. All four live in this repo's `.claude/skills/` and `.claude/agents/`, and
Claude Code auto-discovers skills/agents from those paths for any agent working in this repo — no
per-session activation needed for the agents themselves (only `terse`'s chat-reply style needs the
hooks above, since that has to survive mid-session drift, not just be discoverable once).
