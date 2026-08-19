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
`add-transactions-ui`, and **the four screen changes all build on `add-app-shell-and-boot`**, so a
screen never introduces its own formatter, symbol map or month state.

## Conventions

**Comments: minimal, standalone, write-time and verify-time discipline.** Comment only tricky
nuance a reader would otherwise get wrong. Never restate the code. No Swift references or spec
citations in source, no em dashes, semicolons or colon splices in comment prose. Every comment must
be understandable with only this one file open — no leaning on another function/file/doc without
restating its point locally. Write the comment last. A dispatched agent should not write one that
fails this, and whoever verifies the work checks before marking the task complete — this is never a
later sweep. **`docs/WORKING-CONVENTIONS.md` has the full rule and the failure patterns.**

**At most two wrapped lines, no examples.** A comment runs at most two lines at the file's normal
wrap width (~100 chars/line) — not one line crammed past that width, and not a paragraph. No
made-up dates or ids, no step-by-step trace, no `(e.g. X)` naming a real symbol the surrounding code
already names, and no restating the mechanism the code below already shows — say only the why a
reader could not get from the code itself. If that why does not fit two lines, the code needs a
better name, not a longer comment.

**`///` doc comments are for API callers, not implementers.** Write one only when a public member has
behavior a caller must know and the signature does not already say it — a non-obvious precondition,
a surprising return value, a contract detail. A private member or an implementation detail (why the
body is written the way it is) takes a `//` comment instead, never `///` — a caller of the API never
reads it, so it does not belong in the doc comment. **A `///` states behavior only, never rationale**
— why the member is built that way is an implementation concern and, if worth keeping at all, belongs
in a `//` inside the body, not in the doc comment above it.

**A comment sits on the line it explains, not above the block.** Put a `//` right against the
specific statement it justifies, not once at the top of a function covering several lines below it —
a reader should never have to carry a comment down past code it does not apply to.

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

**Narrow before you read.** Context is the scarce resource, and a `Read` on a file you have not
located spends it faster than anything else. Find the lines first — `rg` for text, the graph for what
calls what, `ast-grep` through a rule file for structure — then read the region those return. Reading
a whole file to find out whether it is relevant is the thing to avoid; reading it once you know it is
relevant is the job. This binds subagents too, so briefs must not hand over a file path and leave the
narrowing implied.

**Send the volume reading to another model.** Call the `pal` MCP server's `chat` tool for anything
where the large window is the point (the frozen Swift app, a whole module doc, cross-repo sweeps),
passing a `model` from `.pal/gemini_models.json` or `.pal/custom_models.json` — ask `listmodels`
first if none is named. Ask it which files cover a concern and where to look next, never for a line
number — `rg -n` answers that exactly and for free. It returns an answer to act on only after you
verify it, never a conclusion to act on directly. `docs/SUBAGENTS.md` has the dispatch detail, and
its "Beyond `chat`" section has the per-tool call: `consensus` (multi-model debate, free across
`.pal/openrouter_models.json`'s 16 models, for a genuinely contested design decision), `thinkdeep`
(one model's second opinion on a hard tradeoff), `debug` (hypothesis-driven investigation given
concrete failure evidence), `codereview` (an independent second reviewer with none of this repo's
conventions baked in, fed those conventions explicitly), `secaudit` (OWASP-based audit — narrow
surface today, on-disk storage and import/export paths are what it can usefully check now, real
value once sync/auth or monetisation land) and `challenge` (offloading pushback to a model with no
stake in the answer) are all adopted. `precommit`/`analyze` stay redundant with `/code-review` and
the graph, `refactor`/`testgen`/`docgen` a poor fit for this repo's conventions. `docs/TOOLING.md`
has the full model catalogue.

**Delegating is the default, and it fails by being forgotten rather than by being rejected.** Knowing
the rule does not fire it: it has been broken twice in one session by an agent that had just written
it down, once reading a 573-line doc directly and once hand-filtering a file already earmarked for
`pal`. Three moments are the trigger, and each is a hard stop, not a preference:

- About to `Read` a file over ~300 lines, or the third file in a row on one question. Dispatch instead.
- About to write a second shell command that filters, greps or reshapes the same data. The first is
  narrowing; the second means the analysis itself is the job, and the job belongs to a reader model.
- Already decided a file goes to `pal`. Then it goes now, unfiltered. Preparing it by hand spends
  the tokens the dispatch existed to save.

**`docs/TOOLING.md` has the measured behavior** of `rg`, `ast-grep`, the code-review-graph MCP server
and `pal`, and which to reach for. Two rules from it that are never worth rediscovering:

- **`rg` never reports a false zero, and everything else can.** A bare `ast-grep -p` pattern matches
  nothing on Dart whatever the code contains, because the pattern parses without surrounding context.
  Ground-truth every empty result with `rg`.
- **The knowledge graph sees git-tracked files only.** `git add -N` on a file you create is what
  makes it visible; the rebuild is a hook's job, not yours.
