# Search and reading tools

Which tool answers which question, how to invoke it, and where each one lies. `docs/SUBAGENTS.md`
covers dispatch; this file covers the tools an agent reaches for directly.

The rule none of these change: **a hit is a claim until it is read at its cited `file:line`.** These
tools shorten the search. They do not shorten the reading, and reading is what verification is made
of.

**Locate before you open.** `Read` on a file you have not located is the most expensive move
available, and the cost lands on the context the rest of the task has to fit inside. Every one of
these tools exists to turn "which file is this in" into a line number, so the read that follows is a
region rather than a file. Opening a file to discover whether it matters is the waste; opening it
once you know it does is the work.

Two cases justify reading a file whole: it is short enough that locating costs more than reading, or
it is a checked-in contract whose every line has to hold — a spec, a task file. Everything else gets
narrowed first, and volume reading goes to `qwen-local` or `gemini-executor` rather than being paid
for in Claude tokens.

## Which tool for which question

1. **`rg`** for anything textual, and as the ground truth for every other tool's zero.
2. **`ast-grep` through a rule file** for structural sweeps a regex cannot express.
3. **The graph** for what calls what, blast radius, dead code, orientation over code you inherited.
4. **`qwen-local`** for pre-narrowed reading inside 20k tokens, and whenever Gemini is throttled.
5. **`gemini-executor`** when the window is the point — the frozen Swift app, cross-repo sweeps.

## ripgrep

`rg` 15.2.0, on the allow list. The default sweep, and **the only one of these that never reports a
false zero.** Every empty result from the other tools is checked against it.

## ast-grep

`ast-grep` 0.45.1, reached as `ast-grep` or `sg`.

**A bare `-p` pattern silently matches nothing on Dart.** The pattern is parsed with no surrounding
code, so the grammar assigns it the wrong node kind and it matches nothing whatever the tree
contains. `-p 'return $X;'` returns zero against 154 real returns. Empty output means "no match **or**
my pattern does not fit the grammar", and the two are indistinguishable.

**Use a rule file that supplies context and names the node to select:**

```yaml
id: assert-closure
language: dart
rule:
  pattern:
    context: "void f() { assert($$$A); }"
    selector: assert_statement
```

```sh
ast-grep scan -r assert-closure.yml packages/domain/lib app/lib
```

Wrapped this way it is exact — the two sweeps tried both matched `rg`'s count precisely. A wrong
selector is rejected at parse time with `Rule contains invalid pattern matcher`, which is the good
failure.

Where it earns its call over `rg`: the convention audits `CLAUDE.md` demands. `double` in the domain,
`DateTime` constructions that are not `startOfDayUtc`, `raw…ID` parameters reaching a map lookup
without `normalizedID`, `enum.index` where a pinned `code` is required.

**Never conclude "zero occurrences" from an empty `ast-grep` result.** Validate every pattern against
a case you know matches first.

## code-review-graph

Version 3.4.7, as the `mcp__code-review-graph__*` MCP tools or the `code-review-graph` CLI. Both
return the same payloads. The MCP tool list binds at session start, so a session that began before
the server was reachable needs restarting.

**Discovery is git-tracked files only.** An untracked file is invisible however often the graph is
rebuilt. `git add -N <path>` registers the path without staging content and is enough to make it
indexable — agents run this on files they create, and `.claude/hooks/graph-rebuild.sh` handles the
rebuild. `docs/SUBAGENTS.md` has the rule.

**Use `build --skip-flows`, not `update`.** `update` diffs commits and will report `0 files updated`
for a file that visibly changed on disk. A full build is 1.2 s here.

`search` returns `file_path`, `line_start`, `line_end` and `params`. `line_end` equals `line_start`
because it points at the declaration rather than the body, so it is an anchor to open, not a range to
trust. Every response carries a `_graph` block with `built_at_sha` and `head_matches_build` — the
cheapest staleness check available.

`detect_changes_tool` and `get_affected_flows_tool`, which the generated `review-changes` skill opens
with, analyse commits rather than the working tree. **Do not use that skill as a pre-commit review
here.**

Semantic search runs on embeddings computed locally, reachable only through the MCP tool with
`provider="openai"` and `model="text-embedding-nomic-embed-text-v1.5"`; without those arguments it
falls back to keyword matching. It retrieves what keyword search cannot — "half-open date window
filter" finds `accounting.dart::filtered` and `DateRange.contains`, which share no token with the
query. Re-run `code-review-graph embed` after work that adds nodes.

## qwen-local

Qwen2.5-Coder-Instruct 7B, served by LM Studio on the user's PC over the LAN. Unmetered, so it takes
the high-frequency lookups that were exhausting Gemini's quota.

```sh
scripts/qwen.sh "<question>" <file> [<file> ...]
```

The wrapper prepends 1-based line numbers so the model can cite anchors.

**LM Studio on the host server loads the build on demand**, so the model named in `SUBAGENT_MODEL`
does not have to be resident first. Only HTTP reaches that host from here, which is why the wrapper
checks `/api/v0/models` rather than shelling out to `lms`: that endpoint is LM Studio's own and the
only one carrying `state` and `max_context_length`. A wrong model id fails there immediately with the
installed ids listed. A cold load costs seconds — a 7B answered a trivial prompt in 10 seconds with
the load included — so a call running for minutes is the memory-spill case, not a load.

**An exhaustive sweep is the wrong job for it.** Asked to list every comment across five files, it
returned `NOT PRESENT` for one holding four and found five of eight in another. It answers "where is
X" well and "list all X" badly, so an inventory that must be complete is `rg`'s job. This is the
false-zero rule with a second source: ground-truth every empty answer it gives.

**The window belongs to the build and the ceiling is hard.** `qwen2.5.1-coder-7b-instruct` holds
32768 and `qwen2.5-coder-7b-instruct-128k` holds 131072. Over-budget requests return HTTP 400
`exceed_context_size_error`, never a silent truncation, so the confident-answer-over-truncated-input
failure is not available to it. Tasks arrive pre-narrowed: this file, these functions, this diff.
`packages/domain/lib` plus `app/lib` is 23.5k tokens. A working budget is about 20k, and it is the
model's accuracy that sets it rather than the window: quality collapses well before 32768, which is
why the 128k build's larger window is not a reason to reach for it.

Speed is not the constraint — the seven `ledger_state` part files answer in 4 seconds.

**Names are reliable, line numbers drift.** It found 22 of 22 target symbols across seven files and
invented none, but only 17 of 23 anchors were exact and the rest were off by 1 to 12 lines. It also
answers `NOT PRESENT` rather than inventing an anchor for a symbol that does not exist, so a negative
from it is worth something.

**It cannot verify.** Same rule as Gemini, held tighter. It narrows; the main thread reads and
decides.
