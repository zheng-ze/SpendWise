# Working through subagents

How implementation is dispatched in this repo, and what each agent type is actually for.
`CLAUDE.md` carries the rules that must never be missed. This file is the detail behind them.

## The two rules that do not bend

**Grant `Bash` to any agent that must prove its work runs.** An agent without it can only claim its
work passes. This is a floor, not a blanket default: read-only agents (`gemini-indexer`,
`gemini-executor`, `cavecrew-investigator`, `spec-conformance`) prove nothing by running the suite,
and handing them `Bash` widens their blast radius for no verification gain. Match the grant to what
the agent must prove.

**Verification cannot be delegated.** A finding is a claim until the main thread reads it at the
cited `file:line`. A subagent confirming another subagent's report is one more claim, not a check.

## Choosing an agent

| Agent | Tools | Use for | Do not use for |
|---|---|---|---|
| `cavecrew-builder` | Read, Edit, Write, Grep, Glob | Bounded 1-2 file edits needing no proof run: renames, typos, single-function rewrites | Anything requiring red-then-green. It has no `Bash` and will refuse, correctly |
| `general-purpose` | all | Test writing, mutation proofs, any task whose workflow includes running the suite | Broad searches where only the conclusion matters |
| `gemini-indexer` | Bash | Locating `file:line` anchors and target symbols across the tree | Settling a question that will be acted on without a read |
| `gemini-executor` | Bash | Orienting summaries and flow traces over large directories | Anything needing exact line numbers |
| `cavecrew-investigator` | Read, Grep, Glob, Bash | Read-only locating with compressed output | Suggesting fixes. It refuses by design |
| `mutation-prober` | Read, Edit, Bash, Grep, Glob | Proving a rule is unguarded, or that a new test really bites | Sharing a working tree with another agent |
| `gate-runner` | Bash, Read | Independent green verification | Writing code |
| `spec-conformance` | Read, Grep, Glob, Bash | The spec angle of an adversarial review | Landing the fixes it finds |

`cavecrew-builder` refusing an oversized or unprovable task is the tool working as designed, not a
failure to brief it. Reach for it when the edit is genuinely bounded.

## Splitting work across parallel agents

**Split by file ownership, never by workflow step.** The write-test, watch-red, fix, watch-green loop
is the unit of proof and must stay inside one agent. Split across a boundary, the handoff carries a
claim where an observation should be: the agent that writes a test must be the one that watches it
fail.

Give every parallel agent an explicit scope fence naming the files it owns and the files other
agents hold. When two agents must touch the same file, name the regions, and tell both to re-read
immediately before editing.

**Line numbers in `tasks.md` go stale the moment a neighbouring edit lands.** A task written against
`:489` pointed at `:934` by the time a parallel agent reached it. Tell agents to anchor on the
assertion or symbol text rather than the number, and run `gemini-indexer` before dispatch when the
task text is not fresh.

## Where Gemini pays

Gemini exists to read volume that would otherwise cost Claude tokens. Its wins, in order:

1. **Gathering the context a change is drafted from.** The strongest case, provided the split is
   right: send `gemini-executor` across the Swift source, the module spec in `docs/modules/` and the
   delivered Dart, then hand the briefing to an Opus agent to draft the proposal, specs and tasks.
   The drafting agent then spends its judgment on the writing rather than on the reading. Gemini
   must not write the spec itself — a spec is a checked-in contract that later work is verified
   against, so it is the artefact whose every line needs the judgment the briefing was gathered to
   inform.
2. **Phase-boundary orientation.** Before a new phase, `gemini-executor` reads the delivered tree and
   returns a briefing, and the main thread then reads only what it flags.
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
   spread across SwiftUI views, view models and helpers. Trace it once with `gemini-executor` rather
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
sanctioned deviations. Anything writing to the tree, since these agents hold `Bash` for reading and
a write from one is unreviewed.

The pattern across all of it: Gemini narrows a large tree to a short list of places worth reading.
It never settles what is true there.

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
