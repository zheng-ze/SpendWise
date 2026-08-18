# Working through subagents

How implementation is dispatched in this repo, and what each agent type is actually for.
`CLAUDE.md` carries the rules that must never be missed. This file is the detail behind them.

## The two rules that do not bend

**Grant `Bash` to any agent that must prove its work runs.** An agent without it can only claim its
work passes. This is a floor, not a blanket default: read-only agents (`cavecrew-investigator`,
`spec-conformance`) prove nothing by running the suite, and handing them `Bash` widens their blast
radius for no verification gain. Match the grant to what the agent must prove. Volume reading no
longer goes through an agent at all — the `reader-models` MCP server's `ask_gemini` and `ask_qwen`
tools are called directly by the main thread or any agent granted them, so there is no `Bash` grant
to make for volume reading itself.

**Verification cannot be delegated.** A finding is a claim until the main thread reads it at the
cited `file:line`. A subagent confirming another subagent's report is one more claim, not a check.

## Briefs decide how an agent spends context

An agent reads the way its brief points it. Hand over a bare file path and it opens the file; say
"search this file rather than trusting the offsets" and it reads the whole thing. Both were written
here, and both produced exactly that. The obligation is on the brief, not on the agent's judgement.

Every brief that sends an agent into unfamiliar code states how to narrow before reading: which `rg`
pattern, which graph query, which symbol to anchor on.

**An implementation agent should call the `reader-models` MCP server's `ask_gemini` or `ask_qwen`
tool for its reading, and its brief should say so.** Either call spends another model's tokens
instead of Claude's, and the saving compounds at depth — an agent that reads a 573-line module doc
itself has burned context its own work then has to fit around. Name the tool and the exact question
(and, for `ask_qwen`, the file list) in the brief: an instruction saying "delegate the Swift reading"
without naming the tool gets a direct read instead, because there is no agent type left to resolve
the intent from.

**The tools are leaves.** Both `ask_qwen` and `ask_gemini` return an answer and stop. Neither one
decides where a request should go instead — that is the caller's job, so a call that cannot be served
fails loudly rather than guessing. `ask_qwen` proves its call through `scripts/qwen.sh`'s
`prompt_tokens` line on stderr, folded into the tool's returned text, and a report without it means
the local model was never asked. `ask_gemini` proves its call the same way with `scripts/gemini.sh`'s
`[gemini.sh: model=... elapsed=...s]` line.

**A failed tool call gets read directly, and the report says so.** There used to be a rule against
an agent silently reading the file itself when the CLI reader was unreachable — three consecutive
dispatches did exactly that and presented the result as though the model had answered. That failure
mode is gone along with the agent layer it lived in: `ask_gemini` and `ask_qwen` wrap plain Bash calls
with no ambient permission to keep reading past a failure, so when Gemini's 20 daily calls are spent
and the qwen host is off, the fallback is the main thread (or the dispatched agent) reading the file
directly and saying so, never a silent substitution presented as the tool's answer.

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

Volume reading is not in this table because it is not an agent anymore. Any agent granted the
`reader-models` MCP tools (or the main thread) calls `ask_gemini(question)` or
`ask_qwen(question, files)` directly, the same way it would call `rg`. See "Where Gemini pays" and
"Reading without Gemini" below for which tool fits which question.

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

## Where Gemini pays

Gemini exists to read volume that would otherwise cost Claude tokens. Its free tier is now easy to
exhaust, so spend it where the large window is the point and send the rest to `ask_qwen`; the
split is in "Reading without Gemini" below.

The quota is counted in calls, not tokens: 20 a day on `gemini-3.6-flash` at 5 a minute, with
`gemini-3.5-flash-lite` behind it at 500 a day and 15 a minute. Both share a 250k
input-tokens-per-minute ceiling and both hold a 1M context window. A narrow question therefore costs
exactly what a broad one costs, so **batch every question about an area into one dispatch** and let
the agent answer them in numbered sections. Splitting a brief into two calls because the topics feel
unrelated halves the day's budget for nothing. Split only to stay under the token ceiling.

Gemini's wins, in order:

1. **Gathering the context a change is drafted from.** The strongest case, provided the split is
   right: call `ask_gemini` across the Swift source, the module spec in `docs/modules/` and the
   delivered Dart, then hand the briefing to an Opus agent to draft the proposal, specs and tasks.
   The drafting agent then spends its judgment on the writing rather than on the reading. Gemini
   must not write the spec itself — a spec is a checked-in contract that later work is verified
   against, so it is the artefact whose every line needs the judgment the briefing was gathered to
   inform.
2. **Phase-boundary orientation.** Before a new phase, call `ask_gemini` against the delivered
   tree and read the briefing back, then read only what it flags.
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
   spread across SwiftUI views, view models and helpers. Trace it once with `ask_gemini` rather
   than opening the tree in the main thread.
9. **Auditing a convention across the tree.** "Every `raw…ID` parameter that reaches a map lookup
   without `normalizedID`" or "every `DateTime` construction that is not `startOfDayUtc`" are sweeps
   whose answer is a candidate list, and the main thread then reads each hit to confirm. This is how
   a rule in `CLAUDE.md` gets checked against reality instead of assumed.
10. **Sizing an unfamiliar change before planning it.** Which files a phase will touch, and roughly
    how much already exists, is worth knowing before tasks are written against it.
11. **Reconstructing history.** Long `git log` output and old change directories under
    `openspec/changes/archive/` answer "why is it like this" at a volume not worth paying Claude
    tokens to read.

Note where the token asymmetry actually falls: the tree is read far more often than it is written,
and reading is the part with no judgment in it. Anything that is pure lookup, spans many files, and
ends in a short answer belongs here.

It is worth little on a task that already carries `file:line` for every target.

**Where it is the wrong tool.** Anything whose output is acted on without a read: a briefing is a
claim, and confirming a finding at its cited line is the main thread's job and cannot be delegated.
Anything requiring an exact quote, since a summary paraphrases and a spec argument turns on the
words. Deciding whether a finding is a real defect, which needs the change's `design.md` and its
sanctioned deviations. Writing to the tree is not a risk either script carries — both only print an
answer to stdout, and any write still happens through the caller's own tools where it is reviewed.

The pattern across all of it: Gemini narrows a large tree to a short list of places worth reading.
It never settles what is true there.

## Reading without Gemini

Gemini's quota runs out mid-task, and the fallback has been paying Claude tokens to read the same
tree. `ask_qwen` is the second reader: Qwen2.5-Coder on the user's PC over the LAN, unmetered,
nothing leaving the network. LM Studio on that host keeps several builds and loads one on demand, so
which model answers is a per-call choice made through `ask_qwen`'s `model` parameter, and the build
need not already be resident. `docs/TOOLING.md` has the measurements behind everything here.

Use the default `qwen2.5.1-coder-7b-instruct` unless a single file will not fit its 32768 window,
which is what `qwen2.5-coder-7b-instruct-128k` is kept for — pass that id as `model` when it is
needed. A build loading for the first time adds its own delay before the first answer.

The split is quota against window, not quality:

- **Gemini** keeps the jobs where the large window is the point. Items 1, 2, 6, 7, 8 and 11 above all
  need to read more than 20k tokens at once, and none of them survive being cut down.
- **`ask_qwen`** takes items 3 and 4 — locating anchors when task line numbers are stale, and
  cross-file sweeps over a named short list. Both are narrow by nature and were exhausting the quota
  on work that never needed the window.
- **When Gemini is throttled**, `ask_qwen` is the fallback for anything inside 20k tokens, and
  the main thread reads directly for anything larger. Record which one produced a briefing, because
  the smaller model's output is the weaker lead.

Four things about it that change how a task is written:

- **It is not an anchor finder.** Never send it a task that needs a line number; `rg -n` answers
  those exactly and for free. Its job is orientation: which files cover a concern, how
  responsibilities divide, what an unfamiliar area contains.
- **Ask one thing per call.** Several questions in one prompt degrade all of them.
- **The window is per-load.** LM Studio on the host server serves several builds and loads one on
  demand, so the ceiling is whatever the named build was configured for: 32768 for
  `qwen2.5.1-coder-7b-instruct`, 131072 for `qwen2.5-coder-7b-instruct-128k`. Over-budget comes back
  as HTTP 400 naming both figures, never as silent truncation.
- **A slow answer is a memory problem.** The KV cache has spilled to system RAM. Report the wall
  time; do not rewrite the prompt. A cold load is the exception and costs seconds rather than
  minutes, and `ask_qwen`'s returned text says when one is happening.
- **It declines to fabricate a symbol** that does not exist, answering `NOT PRESENT`, so a negative
  result from it is worth something. It will still misplace one that does exist.

It cannot verify, same as Gemini and held tighter. `docs/LOCAL-MODEL-BENCHMARKS.md` has the numbers.

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
