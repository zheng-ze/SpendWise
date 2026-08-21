# Working through subagents

How implementation is dispatched in this repo, and what each agent type is actually for.
`CLAUDE.md` carries the rules that must never be missed. This file is the detail behind them.

## The two rules that do not bend

**Grant `Bash` to any agent that must prove its work runs.** An agent without it can only claim its
work passes. This is a floor, not a blanket default: read-only agents (`cavecrew-investigator`,
`spec-conformance`) prove nothing by running the suite, and handing them `Bash` widens their blast
radius for no verification gain. Match the grant to what the agent must prove. Volume reading no
longer goes through an agent at all — the `pal` MCP server's `chat` tool (and its other tools:
`thinkdeep`, `analyze`, `debug`, and the rest) is called directly by the main thread or any agent
granted it, so there is no `Bash` grant to make for volume reading itself.

**Verification cannot be delegated.** A finding is a claim until the main thread reads it at the
cited `file:line`. A subagent confirming another subagent's report is one more claim, not a check.

## Briefs decide how an agent spends context

An agent reads the way its brief points it. Hand over a bare file path and it opens the file; say
"search this file rather than trusting the offsets" and it reads the whole thing. Both were written
here, and both produced exactly that. The obligation is on the brief, not on the agent's judgement.

Every brief that sends an agent into unfamiliar code states how to narrow before reading: which `rg`
pattern, which graph query, which symbol to anchor on.

**An implementation agent should call the `pal` MCP server's `chat` tool for its reading, and its
brief should say so.** The call spends another model's tokens instead of Claude's, and the saving
compounds at depth — an agent that reads a 573-line module doc itself has burned context its own
work then has to fit around. Name the tool, the exact question and the `model` to pass in the brief:
an instruction saying "delegate the Swift reading" without naming the tool gets a direct read
instead, because there is no agent type left to resolve the intent from. Pick a `model` from
`.pal/gemini_models.json` or `.pal/custom_models.json`, or call `listmodels` first when the brief
does not name one.

**The tool is a leaf.** `chat` returns an answer and stops. It does not decide where a request should
go instead — that is the caller's job, so a call that cannot be served fails loudly rather than
guessing.

**A failed tool call gets read directly, and the report says so.** There used to be a rule against
an agent silently reading the file itself when the CLI reader was unreachable — three consecutive
dispatches did exactly that and presented the result as though the model had answered. That failure
mode still applies under `pal`: a call that errors or times out (a throttled Gemini key, the LM
Studio host being off) has no ambient permission to keep reading past the failure, so the fallback is
the main thread (or the dispatched agent) reading the file directly and saying so, never a silent
substitution presented as the tool's answer.

Delegate at the start, while the reading is still ahead of the agent. An instruction arriving forty
tool calls in saves nothing, because the tree is already read. Where the main thread has already
located something, put the anchors in the brief rather than making the agent find them again.

## Choosing an agent

| Agent | Tools | Use for | Do not use for |
|---|---|---|---|
| `cavecrew-builder` | Read, Edit, Write, Grep, Glob | Bounded 1-2 file edits needing no proof run: renames, typos, single-function rewrites | Anything requiring red-then-green. It has no `Bash` and will refuse, correctly |
| `general-purpose` | all | Test writing, mutation proofs, any task whose workflow includes running the suite | Broad searches where only the conclusion matters |
| `cavecrew-investigator` | Read, Grep, Glob, Bash | Read-only locating with compressed output | Suggesting fixes. It refuses by design |
| `mutation-prober` | Read, Edit, Bash, Grep, Glob | Proving a rule is unguarded, or that a new test really bites | Sharing a working tree with another agent |
| `gate-runner` | Bash, Read | Independent green verification | Writing code |
| `spec-conformance` | Read, Grep, Glob, Bash | The spec angle of an adversarial review | Landing the fixes it finds |

`cavecrew-builder` refusing an oversized or unprovable task is the tool working as designed, not a
failure to brief it. Reach for it when the edit is genuinely bounded.

Volume reading is not in this table because it is not an agent anymore. Any agent granted the `pal`
MCP tools (or the main thread) calls `chat(prompt, model)` directly, the same way it would call `rg`.
See "Where `chat` pays" below for which questions earn the call and which `model` to pass.

## Splitting work across parallel agents

**Split by file ownership, never by workflow step.** The write-test, watch-red, fix, watch-green loop
is the unit of proof and must stay inside one agent. Split across a boundary, the handoff carries a
claim where an observation should be: the agent that writes a test must be the one that watches it
fail.

Finer granularity is bought along the file axis, never the step axis: more agents each owning fewer
files, each still running the whole loop. Handing one agent the test, another the red run and a
third the fix looks like tighter scoping but destroys the proof, because an agent that inherits
"the test failed" was told a result rather than seeing one, and a test that never ran red reads
exactly like one that did.

Give every parallel agent an explicit scope fence naming the files it owns and the files other
agents hold. When two agents must touch the same file, name the regions, and tell both to re-read
immediately before editing.

**Line numbers in `tasks.md` go stale the moment a neighbouring edit lands.** A task written against
`:489` pointed at `:934` by the time a parallel agent reached it. Tell agents to anchor on the
assertion or symbol text rather than the number, and re-run `rg -n` on that text before dispatch when
the task text is not fresh.

## Where `chat` pays

`pal`'s `chat` tool exists to read volume that would otherwise cost Claude tokens. Every call takes
a `model` parameter: pass a Gemini id from `.pal/gemini_models.json` (e.g. `gemini-3.6-flash`) when
the large window is the point, or a Custom/local id from `.pal/custom_models.json` (e.g.
`qwen2.5.1-coder-7b-instruct`, served by LM Studio on the user's PC over the LAN) for narrower,
higher-frequency lookups. Call `listmodels` first when the brief does not already name one.

The old Gemini-CLI setup enforced a hard 20-calls-a-day quota that made batching and a two-tier
model split load-bearing; whether pal's Gemini provider carries the same or a different quota has
not been verified since the migration, so treat per-provider limits as unknown until measured rather
than assuming the old numbers carry over. Until then, still **batch every question about an area
into one call** and let the model answer in numbered sections — that discipline costs nothing and
pays off regardless of the actual quota.

`chat`'s wins, in order:

1. **Gathering the context a change is drafted from.** The strongest case, provided the split is
   right: call `chat` across the Swift source, the module spec in `docs/modules/` and the delivered
   Dart, then hand the briefing to an Opus agent to draft the proposal, specs and tasks. The drafting
   agent then spends its judgment on the writing rather than on the reading. The model must not write
   the spec itself — a spec is a checked-in contract that later work is verified against, so it is
   the artefact whose every line needs the judgment the briefing was gathered to inform.
2. **Phase-boundary orientation.** Before a new phase, call `chat` against the delivered tree and
   read the briefing back, then read only what it flags.
3. **Locating anchors when task line numbers are old.** Cheap, read-only, and it kills the drift
   problem before an agent is dispatched.
4. **Cross-file sweeps.** "Which test files call `uuid()`?" is a question worth answering before
   deciding whether a shared helper can be changed.
5. **Pre-review reconnaissance**, so several review angles do not each re-read the same tree.
6. **Reading the frozen Swift app.** `../SpendWise-SwiftUI` is the behavior source of truth and is
   read constantly, yet none of it is ever edited, so every token spent reading it in the main
   thread is pure cost. Ask for the shape of a Swift type, what a view actually renders, or which
   call sites touch a method, then read only the Swift the briefing flags.
7. **Swift-to-Dart parity sweeps.** "Which `AccountingTests.swift` cases have no Dart counterpart?"
   spans two repos and hundreds of test names. The coverage map in a change's `tasks.md` is exactly
   this question answered by hand.
8. **Locating where a behavior lives before a UI phase.** Phases 5 to 7 port screens whose logic is
   spread across SwiftUI views, view models and helpers. Trace it once with `chat` rather than
   opening the tree in the main thread.
9. **Auditing a convention across the tree.** "Every `raw…ID` parameter that reaches a map lookup
   without `normalizedID`" or "every `DateTime` construction that is not `startOfDayUtc`" are sweeps
   whose answer is a candidate list, and the main thread then reads each hit to confirm. This is how
   a rule in `CLAUDE.md` gets checked against reality instead of assumed.
10. **Sizing an unfamiliar change before planning it.** Which files a phase will touch, and roughly
    how much already exists, is worth knowing before tasks are written against it.
11. **Reconstructing history.** Long `git log` output and old design rationale recovered from
    deleted-but-tracked files (the pre-migration OpenSpec change directories, findable via
    `git log --all --diff-filter=D`) answer "why is it like this" at a volume not worth paying
    Claude tokens to read.

For items 1, 2, 6, 7, 8 and 11 above — where the large window is the point — pass a Gemini model.
For items 3 and 4 — locating anchors and narrow cross-file sweeps over a named short list — a Custom
provider model such as `qwen2.5.1-coder-7b-instruct` is unmetered and does not touch the Gemini
provider's limits at all, whatever those turn out to be. Use the default `qwen2.5.1-coder-7b-instruct`
unless a single file will not fit its 32768-token window, which is what
`qwen2.5-coder-7b-instruct-128k` (131072) is kept for.

Note where the token asymmetry actually falls: the tree is read far more often than it is written,
and reading is the part with no judgment in it. Anything that is pure lookup, spans many files, and
ends in a short answer belongs here.

It is worth little on a task that already carries `file:line` for every target.

**Where it is the wrong tool.** Anything whose output is acted on without a read: a briefing is a
claim, and confirming a finding at its cited line is the main thread's job and cannot be delegated.
Anything requiring an exact quote, since a summary paraphrases and a spec argument turns on the
words. Deciding whether a finding is a real defect, which needs the change's `design.md` and its
sanctioned deviations. Writing to the tree is not a risk `chat` carries — it only returns text, and
any write still happens through the caller's own tools where it is reviewed.

The pattern across all of it: `chat` narrows a large tree to a short list of places worth reading.
It never settles what is true there. It cannot verify — the main thread reads and decides.
`docs/TOOLING.md` has what is known so far about each provider's behavior, and
`docs/LOCAL-MODEL-BENCHMARKS.md` carries the retired qwen.sh setup's measurements as historical
record; they describe the old direct-to-LM-Studio path, not pal, so read them as background rather
than as claims about pal's Custom provider.

Four things that still apply to the Custom/local provider specifically, carried over from the old
qwen.sh measurements and not yet re-verified against pal's own call path:

- **It is not an anchor finder.** Never send it a task that needs a line number; `rg -n` answers
  those exactly and for free. Its job is orientation: which files cover a concern, how
  responsibilities divide, what an unfamiliar area contains.
- **Ask one thing per call.** Several questions in one prompt degrade all of them.
- **The window is per-model.** `qwen2.5.1-coder-7b-instruct` holds 32768, `qwen2.5-coder-7b-instruct-128k`
  holds 131072, per `.pal/custom_models.json`.
- **It declined to fabricate a symbol** that did not exist under the old setup, answering
  `NOT PRESENT` rather than inventing an anchor. Worth re-checking under pal before relying on it.

## Beyond `chat`: consensus, thinkdeep, debug

Three more `pal` tools earn their place in this repo's workflow, each for a narrower job than
`chat`'s volume reading. All three are claims like `chat` is — the main thread still verifies
anything actionable at its cited line before acting on it.

**`consensus` for a real architectural fork, not a lookup.** It sends the same proposal to several
models, each assigned a stance (`for`, `against`, `neutral`), and returns each answer plus a
synthesis — built for "should X throw or coerce" questions with a real tradeoff, not for anything
`chat` can already answer in one pass. `.pal/openrouter_models.json`'s 16 free-tier models
(`docs/TOOLING.md` has the full table) make this free to run wide: 3-4 models with mixed stances
costs nothing beyond latency. Reach for it at a change's `design.md` stage when a decision is
genuinely contested, or during an adversarial review when a finding's severity itself is in dispute.
Do not reach for it on anything with a single clearly-correct answer — that is `chat` wasting a
multi-model call on a question one model already settles.

**`thinkdeep` for a second opinion on one hard tradeoff.** Narrower than `consensus`: one model,
extended reasoning, pressure-testing a specific design decision or edge-case analysis rather than
staging a debate. Useful before committing to an approach in a change's `design.md` when the main
thread's own reasoning wants a check, not a vote.

**`debug` for a bug with concrete evidence.** Structured hypothesis formation over a stack trace,
failing test output, or reproduction steps — not a substitute for `mutation-prober`'s proof-that-a-test-bites
loop, and not useful on a vague "something's wrong" report; it wants symptoms already in hand.

**`planner` and `apilookup`, situationally.** `planner`'s incremental step-by-step breakdown mostly
duplicates what `wayfinder` and GitHub issues already give this repo — reach for it only when a plan
is too exploratory or too large for a wayfinder map, not as a default planning step. `apilookup`
forces a live documentation search instead of trained-in knowledge, useful for Flutter/Dart API
currency checks, but depends on web search being enabled in the CLI config, which has not been
confirmed here — treat as unverified until tried once.

**`codereview` for an independent second reviewer.** The repo's own `/code-review` skill and the
`code-review-graph` MCP already cover structural review; `codereview` is worth adding alongside them
specifically because it carries none of this repo's house conventions and none of Claude's own
blind spots — a genuinely independent model looking at the diff cold. Feed it the same convention
list `ast-grep`'s rule files audit (Decimal-not-double, half-open windows, `normalizedID`, pinned
`code` fields) in the prompt so it is reviewing against SpendWise's actual rules, not generic
practice, or its findings will mostly be noise. Use at a phase boundary alongside the adversarial
review, not as a replacement for either existing path.

**`secaudit`.** Methodical OWASP-based security assessment across a 6-step workflow — authentication,
data protection, dependency vulnerabilities, and (optionally) compliance framing (PCI DSS, HIPAA,
GDPR). Today's audit surface is narrow — SpendWise is local storage with no network calls or auth —
but still worth pointing at how the app persists financial data on disk and whatever export/import
paths exist, since those are the parts of the current app closest to a real vulnerability. Its
value grows sharply once the sync engine lands (auth, data in transit) and further if the app is
ever monetised (payment handling, compliance surface) — run it again at each of those points, not
just once now.

**`challenge` to offload pushback to a model with no stake in the answer.** Distinct from Claude
self-challenging: a free external model given the counter-position has no incentive to agree with
work already in front of it, so it is worth a call when a proposal or a review finding needs a real
adversarial pass rather than the same model marking its own work. Pair with `consensus` when the
question has more than two sides — `challenge` is cheaper for a straight "is this actually right".

**Deliberately not adopted:** `precommit` and `analyze` still overlap `/code-review` and the graph
closely enough that adding them changes nothing `codereview` above does not already cover.
`refactor`/`testgen`/`docgen` generate output blind to this repo's house conventions (tests-first,
minimal comments, translation-not-redesign) and would cost more to correct than to write by hand.
`tracer` duplicates what `ast-grep`/the graph already answer directly, with an extra step in between.

## Briefing an agent

State what to test, where the bug goes, what breaks for the user, why the current tests miss it, and
what to add. That fourth clause is the one that stops a reader assuming the case is already covered.

Also state which behavior is new in the change and which predates it, or the agent will re-derive
existing behavior as a defect. Say plainly when the source is already correct and the task is
test-only, and tell the agent to stop and report rather than "fix" working source.

**Retry failed work with a brand-new agent**, briefed from the task and the code, never from the
failed attempt. Verify the tree is clean first.

## Mutation proofs

Restore mutated files **by file copy from a backup**, never with `git checkout`, `git restore`,
`git stash` or `git reset`. Those are hard-denied here, and under parallel agents they would discard
another agent's committed-in-progress work. Back up to the scratchpad first, and `diff` after
restoring to prove the restore was exact.

An agent running mutations cannot share a working tree with an agent reading the same files.

## Keeping the graph current

**Nobody commits but the user.** Agents get exactly one git write, `git add -N <path>`, and it exists
for the knowledge graph: discovery is git-tracked files only, so an untracked file is invisible no
matter how often the graph is rebuilt. Registering the path is what makes it visible. The commit adds
nothing on top, which is why this needs no commit at all.

**Every agent that creates a file runs `git add -N` on it.** Measured, in a scratch repo, on a file
whose contents were never staged:

| | `update` | `build` |
|---|---|---|
| New file, `git add -N` | 0 nodes | 3 nodes, visible |
| Later edit to that path | 0 nodes | 1 node, visible |

So `-N` is sufficient and content staging is never needed. `update` is useless here regardless — it
diffs commits and reports `0 files updated` for a file that visibly changed on disk.

The rebuild is not the agent's job. `.claude/hooks/graph-rebuild.sh` runs `build --skip-flows` after
every `Edit`/`Write`, 1.2 s, no extension filter — the parser covers 60+ languages and that list
moves between releases, so `build` decides what it can parse rather than the hook.

Two limits worth knowing. The graph stores Files, Classes and Functions, so an agent that only
changed method bodies produces no new node and the rebuild is a no-op; the wins concentrate on work
adding files, classes or methods. And a registered file that is later deleted shows as `D` in
`git status` until the user clears it, so scratch files stay unregistered — use the job's tmp
directory for those.

**Never register a file while a mutation proof is in flight.** `-N` stages no content, so a broken
file cannot reach the index, but the rebuild will index the broken parse and the graph will carry it
until the restore triggers another rebuild.
