# Tooling measurements, 11 Aug 2026

Evidence behind `docs/TOOLING.md`, plus the host settings for the local model. Every number was
reproduced at the command line in one session. Kept because several of these tools behave differently
from their own documentation, and the checks are cheaper to repeat than to re-derive.

Nothing routes an agent here. `TOOLING.md` carries the conclusions; this file carries the proof.

## ast-grep parses Dart patterns out of context

Of ten ordinary patterns tried as bare `-p` against `packages/domain/lib`, one matched:

| Pattern | Hits | Ground truth |
|---|---|---|
| `double $X` | 1 | correct |
| `assert($$$)` | 0 | 4 exist |
| `return $X;` | 0 | 154 exist |
| `if ($C) { $$$ }` | 0 | many |
| `DateTime($$$)` | 0 | many |
| `$X.toUtc()` | 0 | — |
| `throw $X` | 0 | 69 exist |
| `final $X = $Y;` | 0 | 161 exist |
| `$X.index` | 0 | — |
| `List<LedgerChange> $F($$$) { $$$ }` | 0 | 22 exist |

`--debug-query=ast` explains it. `return $X;` parses as a `top_level_variable_declaration`, which no
statement position can match. `double $X` parses to an `ERROR` node and matches anyway — luck, not
support.

Wrapped in a rule file with `context:` and `selector:`, both sweeps tried matched `rg` exactly:
`assert_statement` 4 against `rg`'s 4, `return_statement` 154 against `rg`'s 154.

## The graph indexes tracked files, and `update` is commit-driven

Isolated in a scratch git repo, one file at a time:

| Step | `update` | `build` |
|---|---|---|
| Untracked new file | 0 nodes | 0 nodes — invisible to both |
| New file after `git add -N` | 0 nodes | 3 nodes, visible |
| Later edit to that registered path | 0 nodes | 1 node, visible |
| Uncommitted edit to a tracked file | 0 nodes | visible |
| Same edit after committing | 2 files updated | visible |

`update` reported `Incremental: 0 files updated` on a file edited one second earlier, then picked up
the same change once committed. So it diffs commits, not mtimes.

A full `build` over a scratch repo holding one tracked and one untracked Dart file reports
`Full build: 1 files`.

`git add -N` is sufficient and content staging is never needed. Verified end to end on this repo: a
probe file went 422 → 425 nodes, was found at its correct `file:line`, and returned to 422 on
deletion.

Timing: full build 1.2 s, 104 files. Five concurrent builds completed in 3.8 s with the database
intact afterwards.

`build`'s summary line and `status` report different figures — `Full build: 104 files ... 7480 edges`
against a stored 88 files and 7165 edges. The first counts what was scanned and derived, the second
what survived deduplication. They are expected to differ; a mismatch is not corruption.

## Local semantic search

334 nodes embedded in 2.9 s against the LAN endpoint. Scored directly against the stored vectors, on
phrasings sharing no token with the answer:

| Query | Top hits | Cosine |
|---|---|---|
| half-open date window filter | `accounting.dart::filtered`, `DateRange.contains` | 0.67, 0.61 |
| recurring plan occurrence generation | `RecurringPlan.occurrences`, `nextOccurrence` | 0.83, 0.79 |
| debug-only invariant sweep | `_assertChecked`, `LedgerState._checkedResolution` | 0.56, 0.56 |
| undo a deletion | `DeleteEntry`, `deleteEntry`, `deleteAccount` | 0.63, 0.59 |

All return zero under keyword search. The `search` CLI subcommand ignores the provider environment
and stays on keyword matching, so only the MCP tool reaches the embeddings.

**The `score` the MCP tool returns is not that cosine.** It is a reciprocal rank — 1/61, 1/62, 1/63
down the list, identical for every query — so it encodes position and nothing else. Two results
scoring 0.0164 and 0.0159 are first and third, not near-equal matches. The cosines above were read
from the stored vectors directly and are the only figures here that measure similarity. Rank order
is the usable signal from the tool; the number beside it is not.

Re-run on the same baseline query after the Phase 3 files entered the graph returned `filtered` first
and `DateRange.contains` third, so retrieval itself held. But a query describing `AnalysisCache`'s
stale-result guard did not surface `refresh`, which implements it. Semantic search finds neighbourhoods,
not definitions. `rg` and the graph's own structural queries stay the locators.

### Three embedding models, same corpus

`nomic-embed-text-v1.5` against `Qwen3-Embedding-0.6B` at F16, the latter in both its original GGUF
and a community rebuild fixing the missing EOS token. Rank of the correct answer, three queries:

| Query | nomic-v1.5 | Qwen3, broken EOS | Qwen3, fixed EOS |
|---|---|---|---|
| half-open date window filter | `filtered` 1st, `contains` 3rd | `DateRange` 1st, `contains` 2nd | identical to broken |
| stale-result discard | `syncComputeRunner` 2nd, no `refresh` | `syncComputeRunner` 5th, no `refresh` | identical to broken |
| undo a deletion | delete family only, no `restore*` | delete family only, no `restore*` | identical to broken |

The two Qwen builds returned byte-identical rankings, so **the EOS fix changed nothing measurable**.
The original GGUF omits `tokenizer.ggml.add_eos_token` and LM Studio warns on every request, which is
a real defect, but EOS affects pooling over a sequence and these inputs are one to three tokens. There
is no sequence to pool.

Nomic and Qwen traded wins, one query each, one tie. **Nomic is kept on size**: 137M parameters
against 600M, roughly 300 MB against 1.2 GB, and 768 dimensions against 1024. Embedding here is
bursty, so most calls pay a cold load, and the smaller vectors are cheaper to store and compare
forever. Nothing in the quality measurements argues against it.

The finding that outlives the model choice: **all three miss the same two queries.** The graph embeds
node names and signatures, not bodies, so the vector for `refresh` is built from the token `refresh`
and cannot carry "recompute under a generation guard". No embedder recovers what the corpus never
encoded. Model choice is not the lever here; what gets embedded is.

A model name with no stored vectors returns `search_mode: "none"` and zero results rather than falling
back to keyword search, which is the check that proves a comparison is really running on the model
named. Switching models re-embeds every node and migrates dimensions cleanly in both directions.

Env note: `.mcp.json` cannot expand `${SUBAGENT_API_BASE}` — Claude Code launches MCP servers from
its own environment rather than a login shell, so the variable arrives empty and the provider fails
with a missing-variable error. The base URL is hardcoded there and needs editing if the PC's LAN
address changes.

## The local model

| Probe | Result |
|---|---|
| Generation | ~36 tokens/s warm, TTFT 0.07 s over the LAN |
| Prompt processing | ~2900 tokens/s; 7 `ledger_state` files (7.1k tokens) in 4.0 s |
| Context ceiling | 24576, hard; HTTP 400 `exceed_context_size_error` |
| Format adherence | 3/3 exact on `file:line: name`, no prose |
| Fabrication | 4/4 `NOT PRESENT` for `restoreEntry`, which does not exist |
| Symbol recall | 22/22 public mutators across 7 files, zero invented |
| Line accuracy | 17/23 exact, rest off by 1 to 12 |

LM Studio ignores the `model` field and serves whatever is loaded — a request naming
`unsloth/Qwen2.5-Coder-14B-Instruct-GGUF` was answered by `qwen2.5-coder-14b-instruct`. A working
completion is not proof the id is right.

Superseded on 14 Aug 2026: the host now honours the field and loads the named build on demand, and an
id it does not have is a 404 rather than a silent substitution. `scripts/qwen.sh` checks the id
against `/api/v0/models` before sending, so the misdirection this row describes is caught rather than
guessed at. `docs/TOOLING.md` carries the current behaviour.

One recall failure worth noting: asked for public methods returning `List<LedgerChange>`, it included
`_willOutliveParentAccount` (private, returns `bool`) and `resolvePlans` (returns `PlanResolution`).
The return-type filter leaks; the names themselves were never invented.

## Host settings

State on the user's PC, not in this repo, so none of it is verifiable from a checkout. RTX 4070,
12 GB. Qwen2.5-Coder-Instruct 14B at Q4_K_M, roughly 9 GB of weights, served on port 1234.

| Setting | Value | Why |
|---|---|---|
| Context length | 24576 | See below. Raising it is not free. |
| Limit offload to dedicated GPU memory | on | Makes over-allocation fail loudly instead of degrading silently. |
| GPU offload | 48 layers | All of them. |
| K and V cache quantization | Q8_0 | Halves KV against fp16, which keeps the cache resident. |
| Flash attention | on | What makes the Q8 cache cheap. |
| Max concurrent predictions | 1 | Concurrent slots split the window between callers. |

Server-side sampling values barely matter: `scripts/qwen.sh` sends `temperature: 0` per request, which
overrides them. They apply only to queries typed into the LM Studio UI.

### Do not raise the context length

Tried at 32768. Prompt processing collapsed from ~2900 tokens/s to ~65:

| Payload | 24576 | 32768 |
|---|---|---|
| 6k tokens | 2.1 s | 93 s |
| 7.1k tokens (7 `ledger_state` files) | 4.0 s | 124 s |
| 23.6k tokens | HTTP 400 | 1139 s |

Generation was unaffected at both settings, ~26 to 36 tokens/s. That split is the signature: weights
stay on the GPU so generation is fine, while the KV cache stops being resident and every prefill
token crosses PCIe.

It matters because **prefill is the entire workload**. Every call sends a file and asks a short
question, so the prompt is large and the answer is a few lines. A 7k lookup at 4 s is worth making;
at 124 s it is slower than reading the seven files directly, which is the bar the model must clear to
be worth calling.

The 32768 setting does let a 23.6k payload through where 24576 returns HTTP 400. That is not a gain.
Nineteen minutes for one answer is not a usable call, and the hard 400 is a feature — it forces a task
to be pre-narrowed instead of quietly becoming unusable.

If the larger window is ever genuinely needed, the lever is dropping GPU offload from 48 to about 44
layers so the KV cache fits in VRAM alongside fewer weights. That trades generation speed for prefill
speed and was not tested. Every use case measured so far fits inside 20k tokens.
