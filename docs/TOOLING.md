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
narrowed first, and volume reading goes to the `pal` MCP server's `chat` tool rather than being paid
for in Claude tokens.

## Which tool for which question

1. **`rg`** for anything textual, and as the ground truth for every other tool's zero.
2. **`ast-grep` through a rule file** for structural sweeps a regex cannot express.
3. **The graph** for what calls what, blast radius, dead code, orientation over code you inherited.
4. **`pal`'s `chat` with a Custom/local model** for pre-narrowed reading, and whenever the Gemini
   provider is throttled or unavailable.
5. **`pal`'s `chat` with a Gemini model** when the window is the point — the frozen Swift app,
   cross-repo sweeps.

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

## pal

MCP server (`BeehiveInnovations/pal-mcp-server`), configured in `.mcp.json` as `pal`, run via
`uvx --with 'mcp<2.0.0' --from /Users/macbook/pal-mcp-server pal-mcp-server` — a local clone, not
the GitHub URL directly, because `clink`'s Gemini CLI config needed patching (see the `clink`
subsection below). **Pulling upstream changes into that clone will overwrite the patch** —
re-apply `conf/cli_clients/gemini.json`'s `additional_args` after any `git pull` in
`~/pal-mcp-server`. Exposes collaboration tools (`chat`, `thinkdeep`, `planner`, `consensus`,
`clink`), code-analysis tools (`debug`, `precommit`, `codereview`, `analyze`), development tools
(`refactor`, `testgen`, `secaudit`, `docgen`) and utilities (`apilookup`, `challenge`, `tracer`).
For the volume reading `gemini`/`qwen` used to serve, `chat` is the tool:

```
chat(prompt="<question>", model="<model id or alias>")
```

Every tool call takes `model`. Call `listmodels` first to see the live catalogue when the brief does
not already name one — do not guess an id.

Two providers are configured, each with its own model-catalogue file:

- **Gemini**, via `GEMINI_API_KEY`. Model ids and aliases come from `.pal/gemini_models.json`.
  Reserved for jobs where the large window is the point: the frozen Swift app, a whole module doc,
  cross-repo sweeps. Each model draws from its own rate-limit pool on the account's quota dashboard
  (RPM / TPM / RPD, as of 2026-08-19):

  | Model | alias | RPM | TPM | RPD |
  |---|---|---|---|---|
  | `gemini-3.7-flash` | `flash3.7` | 5 | 250K | 20 |
  | `gemini-3.6-flash` | `flash` | 5 | 250K | 20 |
  | `gemini-3.5-flash`\* | `flash3.5` | 5-6 | 178-250K | 20 |
  | `gemini-3.5-flash-lite` | `flashlite` | 15 | 250K | 500 |
  | `gemini-3.1-flash-lite` | `flash-lite-3.1` | 15 | 250K | 500 |
  | `gemma-4-26b-a4b-it` | `gemma` | 30 | 16K | 14.4K |
  | `gemma-4-31b-it` | `gemma-31b` | 30 | 16K | 14.4K |

  \* `gemini-3.5-flash`'s daily quota (20 RPD) was already spent for the day on the account's
  dashboard, so the id in `.pal/gemini_models.json` is unverified against pal's own allow-list this
  session — it follows the same naming pattern as the confirmed-live `3.6`/`3.7` siblings and the
  dashboard shows prior real usage against it, but confirm with a live `chat` call once quota resets
  before trusting it fully.

  The lite variants trade nothing for their 500 RPD ceiling — same 250K TPM as the full flash
  models, just a smaller model. Gemma trades the opposite way: far higher RPM/RPD than any flash
  model, but its 16K TPM caps what a single call can carry, so it suits many small calls rather
  than one large one.
- **OpenRouter** (free tier), via `OPENROUTER_API_KEY`. Model ids and aliases come from
  `.pal/openrouter_models.json`. pal's built-in OpenRouter catalogue is paid models only (Claude
  Opus, GPT-5, Grok-4), so this override keeps just the `:free`-suffixed ones this account can
  actually call. 4 models, confirmed live 2026-08-19:

  | Model | alias |
  |---|---|
  | `z-ai/glm-5.2:free` | `glm`, `glm5.2` |
  | `poolside/laguna-xs-2.1:free` | `laguna`, `laguna-xs` |
  | `nvidia/nemotron-3-nano-30b-a3b:free` | `nemotron`, `nemotron-nano` |
  | `openai/gpt-oss-20b:free` | `gpt-oss`, `oss20b` |

  `google/gemma-4-26b-a4b:free` and `google/gemma-4-31b:free` were tried and dropped — OpenRouter
  rejected both as "not a valid model ID", so Gemma's real OpenRouter slug is not the naming pattern
  the other providers use. The direct-Gemini-key `gemma-4-26b-a4b-it`/`gemma-4-31b-it` above are a
  separate rate-limit pool and unaffected. `z-ai/glm-5.2:free` also hit a transient 429
  (`temporarily rate-limited upstream`, shared free pool) on first test — a real, valid id, just
  retry rather than treat as dead.

  **`OPENROUTER_API_KEY` did not reach pal until Claude Code's own process was fully relaunched.**
  It was added to `~/.zshrc` after Claude Code had already started, and `bash -c` (pal's launcher in
  `.mcp.json`) is a plain non-login shell that never reads `.zshrc` anyway — `GEMINI_API_KEY` and
  `CUSTOM_API_KEY` never depended on shell sourcing either, they reach pal because they were already
  present in Claude Code's own environment at launch. A session restart reloads the conversation, not
  that outer process; only a full quit-and-reopen of the app picks up a `.zshrc` change.
- **OpenRouter** (free tier), via `OPENROUTER_API_KEY`. Model ids and aliases come from
  `.pal/openrouter_models.json`. pal's built-in OpenRouter catalogue is paid models only (Claude
  Opus, GPT-5, Grok-4), so this override keeps just the `:free`-suffixed ones this account can
  actually call. 16 models, all confirmed live 2026-08-19:

  | Model | alias | notes |
  |---|---|---|
  | `z-ai/glm-5.2:free` | `glm` | 1M ctx, strongest of the set for long-horizon coding |
  | `poolside/laguna-s-2.1:free` | `laguna-s` | 118B/8B active, coding agent |
  | `poolside/laguna-xs-2.1:free` | `laguna` | compact coding agent |
  | `cohere/north-mini-code:free` | `north-mini` | agentic coding, low latency |
  | `nvidia/nemotron-3.5-lightning:free` | `nemotron-lightning` | high-throughput agentic |
  | `nvidia/nemotron-3.5-content-safety:free` | `nemotron-safety` | guardrail/moderation only, not general chat |
  | `nvidia/nemotron-3-ultra-550b-a55b:free` | `nemotron-ultra` | 550B/55B active, frontier reasoning |
  | `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` | `nemotron-omni` | multimodal (text/image/video/audio) |
  | `nvidia/nemotron-3-super-120b-a12b:free` | `nemotron-super` | 120B/12B active, multi-agent |
  | `nvidia/nemotron-3-nano-30b-a3b:free` | `nemotron`, `nemotron-nano` | agentic focus |
  | `nvidia/nemotron-nano-9b-v2:free` | `nemotron-9b` | toggleable reasoning trace |
  | `google/gemma-4-26b-a4b-it:free` | `gemma-or`, `gemma-26b-or` | same model as `gemma-4-26b-a4b-it` below, separate quota pool |
  | `google/gemma-4-31b-it:free` | `gemma-31b-or` | same model as `gemma-4-31b-it` below, separate quota pool |
  | `openai/gpt-oss-20b:free` | `gpt-oss`, `oss20b` | function calling, agentic |
  | `liquid/lfm-2.5-2.6b:free` | `lfm`, `lfm2.5` | compact, not recommended for agentic coding |
  | `dots-studio/dots-3-note-preview:free` | `dots3`, `dots-note` | 280B/16B active, long-context, multimodal |

  All 16 slugs needed live testing to get right — `google/gemma-4-26b-a4b:free` (missing `-it`),
  `nvidia/nemotron-3-ultra:free` (missing `-550b-a55b`), `nvidia/nemotron-3-nano-omni:free` (missing
  `-30b-a3b-reasoning`), `nvidia/nemotron-3-super:free` (missing `-120b-a12b`), `liquid/lfm2.5-2.6b:free`
  (missing hyphen before `2.5`) and `dots-studio/dots3-note-preview:free` (missing hyphen in `dots-3`)
  all failed with "not a valid model ID" on the pattern guessed from the display name — OpenRouter's
  real slug is not reliably derivable from the model's marketing name, only from its actual URL/API
  id. `nvidia/nemotron-nano-12b-2-vl:free` (image/video model, dashboard flagged "going away
  2026-08-24") was deliberately left out of the catalogue.

  `z-ai/glm-5.2:free` and `google/gemma-4-31b-it:free` each returned a transient 429
  (`temporarily rate-limited upstream`, shared free pool) on first test — real, valid ids, just
  retry rather than treat as dead.
- **Custom** (local), via `CUSTOM_API_URL`/`CUSTOM_API_KEY` pointing at LM Studio on
  `192.168.1.150:1234`. Model ids and aliases come from `.pal/custom_models.json` (
  `qwen2.5.1-coder-7b-instruct`, aliases `qwen`/`local`, 32768-token window;
  `qwen2.5-coder-7b-instruct-128k`, alias `qwen-128k`, 131072-token window). Unmetered, LAN-only,
  nothing leaving the network — the fallback for narrower, higher-frequency lookups or when the
  Gemini provider is throttled.

**The Gemini model catalogue needed a client-side override.** `.pal/gemini_models.json` exists
because pal's own built-in Gemini catalogue was stale — it still listed 2.5/2.0 model ids that Google
had retired. `GEMINI_MODELS_CONFIG_PATH` in `.mcp.json` points pal at the override file instead, kept
current against the account's actual quota dashboard.

**`mcp` had to be pinned below 2.0.0.** Unpinned (`mcp>=2.0.0`), pal-mcp-server's own code breaks
with `AttributeError: 'Server' object has no attribute 'list_tools'`. The `--with 'mcp<2.0.0'` flag
on the `uvx` invocation in `.mcp.json` is what pins it; dropping that flag reintroduces the crash.

**It cannot verify.** `chat` (and every other pal tool) returns a claim, and the main thread (or the
agent that called the tool) still has to open the cited lines before acting on any of it.

**`clink` is a different capability from `chat` and carries a different risk.** `chat` calls an API
and returns text — it cannot act. `clink` shells out to a real CLI binary (`gemini`, installed
separately via `npm install -g @google/gemini-cli`) and lets it run autonomously with its own tools:
read files, run shell commands, and — with the CLI's shipped defaults — write files too, since
pal's stock `conf/cli_clients/gemini.json` passes `--yolo` (auto-approve every action). That
default is patched out in `~/pal-mcp-server`'s clone: `additional_args` is
`["--approval-mode", "plan", "--skip-trust"]` instead. `plan` mode (an option on the underlying
`gemini` CLI, not a pal invention) keeps every read/investigate tool live — grep, read, run
non-mutating shell commands — while refusing anything that would write a file or run a mutating
command, confirmed against a live call. `--skip-trust` is required alongside it: without that flag
the CLI silently falls back to its interactive default mode instead of `plan` (SpendWise is not a
trusted Gemini workspace), which would be less safe than doing nothing, not more.

```
clink(prompt="<question>", cli_name="gemini", role="planner")
```

`role` picks the system prompt (`default`, `planner`, `codereviewer`) but does not change the
`--approval-mode`/`--skip-trust` flags — all three roles run in the same read-only mode under this
patch. Use it for planning and code-review tasks that benefit from an independent model actually
walking the codebase with its own tools, not just answering from what's pasted into the prompt —
`chat` is still the right tool for a bounded question over specific files. `clink`'s Gemini calls go
through the standalone `gemini` CLI's own model routing and auth, separate from the `GEMINI_API_KEY`
path `chat` uses — the two do not share quota.

**Performance characteristics for pal itself — call latency, per-provider quota, comparative
accuracy between the Gemini and Custom providers — have not been measured since the migration.**
`docs/LOCAL-MODEL-BENCHMARKS.md` holds real measurements, but they describe the retired qwen.sh
setup talking to LM Studio directly, not pal's Custom provider, so treat them as historical
background rather than as claims about pal.
