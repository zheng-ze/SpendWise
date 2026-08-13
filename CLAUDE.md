# SpendWise — Flutter port

Rewrite of the frozen SwiftUI app at `../SpendWise-SwiftUI`. That repo is the source of truth for
behavior; its own CLAUDE.md is stale — trust the Swift code, not its docs.

## Layout

- `packages/domain/` — pure Dart. Models, `LedgerState`, accounting. Has no Flutter dependency and
  must never gain one; that is what keeps the domain portable and testable.
- `app/` — the Flutter app. Depends on `domain` by path.
- `docs/` — behavior specs and working procedure.
- `openspec/` — the planned work. `project.md` holds the full technical rules (this file is its
  summary); `changes/<name>/` holds each change's proposal, specs, design and tasks.

**Read `docs/NAVIGATION.md` before starting work.** It is the reading order, the phase table and the
sequencing rules. Two things from it that decide what you may touch: the current change is
`add-ledger-runtime`, and **no UI work happens before Phase 3 is green.**

## Conventions

**Comments:** minimal. Comment only tricky nuance, deliberate spec deviations, or ordering
constraints a reader would otherwise break. Never restate what the code says. No Swift references
and no spec citations in source; no em dashes, semicolons or colon splices in comment prose. Tests
are held to the same budget — the test name carries the intent.

Write the comment last, and only after asking what a reader would get wrong without it. This is the
most-repeated correction on the project by a wide margin: comments get written by default and
trimmed on request, when the default should be silence. A name that carries the behaviour retires
the comment that explained it — prefer renaming to annotating.

**Plain language everywhere**, not only in task files: comments, identifiers and reports alike. Say
what a thing does in ordinary words rather than in jargon or borrowed vocabulary. A function called
`monthWithDayUtc` needed a comment to explain that it shifts the month before clamping the day;
`shiftMonthThenClampDayUtc` needed none.

**The port is a translation, not a redesign.** Type names match Swift (`LedgerState`, `Entry`,
`MoneySource`, `TransactionCategory`, `LedgerChange`, `LedgerError`). Mutators keep the
validate → mutate → return `List<LedgerChange>` contract. Deviations from Swift happen only where
a spec's "KNOWN DEFECT" or "PORT FIX" section sanctions one.

**Money is `Decimal`, never `double`.** `double` in `packages/domain/lib/` is a defect.

**IDs are lowercase uuid strings**, normalized at every construction boundary.

**Int-coded enums** carry an explicit `code` field pinned to the Swift raw value, never
`enum.index` — persistence writes these codes.

**Window filters are half-open `[start, end)`** everywhere.

**A domain date is UTC midnight of the calendar day it names.** Normalize with `startOfDayUtc` in
`calendar_day.dart`, which is day-preserving. Never `.toUtc()`, which preserves the instant and so
moves a local midnight back a day for every user east of Greenwich. `design.md` in
`add-domain-accounting` has the full ruling.

**Illegal states are unreachable; invariants only catch what slips.** `_checked` runs
`assertInvariants` inside `assert(() {...}())`, so every clause is debug-only. The state maps are
private behind `UnmodifiableMapView`, and `_detachAndTombstonePocket` is the sole remover of a
pocket row — those two are what make the bad states impossible rather than merely unlikely. Reject
rather than silently coerce: `addPocket` throws on a non-active parent, and a category's `kind` is
fixed at creation. A check that must hold in release needs a real throw, not an `assert`.

**Keep file scope small and single-purpose.** `LedgerState` is split by concern into `part` files.
Split by concern, not by symbol count.

## Checks

`cd packages/domain && dart format . && dart analyze && dart test`, and `cd app && flutter analyze`.
Analyzer must be at zero issues, not just zero errors.

## Working with this repo

**The user commits themselves — never run `git commit`.** Report green and hand it over.

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

**Treat every finding as unverified until read at the cited `file:line`.** A subagent may cite a
user instruction that is absent from your transcript and still be right — the user intervenes in
running subagents directly.

Most implementation runs through subagents, one task group at a time. **`docs/SUBAGENTS.md` has the
dispatch procedure** — which agent for which job, how to fence parallel work, and where Gemini pays.
Two rules from it that are never worth rediscovering:

- **Grant `Bash` to any agent that must prove its work runs.** An agent without it can only claim.
  It is a floor, not a default: read-only agents do not need it.
- **Split parallel work by file ownership, never by workflow step.** The write-test, watch-red, fix,
  watch-green loop is the unit of proof and stays inside one agent.

## Search tools

**Narrow before you read.** Context is the scarce resource, and a `Read` on a file you have not
located spends it faster than anything else. Find the lines first — `rg` for text, the graph for what
calls what, `ast-grep` through a rule file for structure — then read the region those return. Reading
a whole file to find out whether it is relevant is the thing to avoid; reading it once you know it is
relevant is the job. This binds subagents too, so briefs must not hand over a file path and leave the
narrowing implied.

**Send the volume reading to another model.** `gemini-executor` for anything where the large window
is the point (the frozen Swift app, a whole module doc, cross-repo sweeps), `qwen-local` for the same
question when Gemini is throttled. Ask either which files cover a concern and where to look next,
never for a line number — `rg -n` answers that exactly and for free. Both return claims to verify,
never conclusions to act on. `docs/SUBAGENTS.md` has the split and the quota arithmetic, and
`docs/LOCAL-MODEL-BENCHMARKS.md` the measurements behind it.

**Delegating is the default, and it fails by being forgotten rather than by being rejected.** Knowing
the rule does not fire it: it has been broken twice in one session by an agent that had just written
it down, once reading a 573-line doc directly and once hand-filtering a file already earmarked for
Gemini. Three moments are the trigger, and each is a hard stop, not a preference:

- About to `Read` a file over ~300 lines, or the third file in a row on one question. Dispatch instead.
- About to write a second shell command that filters, greps or reshapes the same data. The first is
  narrowing; the second means the analysis itself is the job, and the job belongs to a reader model.
- Already decided a file goes to Gemini. Then it goes now, unfiltered. Preparing it by hand spends
  the tokens the dispatch existed to save.

**`docs/TOOLING.md` has the measured behavior** of `rg`, `ast-grep`, the code-review-graph MCP server
and the local model, and which to reach for. Two rules from it that are never worth rediscovering:

- **`rg` never reports a false zero, and everything else can.** A bare `ast-grep -p` pattern matches
  nothing on Dart whatever the code contains, because the pattern parses without surrounding context.
  Ground-truth every empty result with `rg`.
- **The knowledge graph sees git-tracked files only.** `git add -N` on a file you create is what
  makes it visible; the rebuild is a hook's job, not yours.
