# Search tools

Relevant whenever locating code, reviewing a large surface, or deciding whether to dispatch a
subagent. Not needed for a small, already-located edit.

**Narrow before you read.** Context is the scarce resource, and a `Read` on a file you have not
located spends it faster than anything else. Find the lines first — `rg` for text, `ast-grep` through
a rule file for structure — then read the region those return. Reading
a whole file to find out whether it is relevant is the thing to avoid; reading it once you know it is
relevant is the job. This binds subagents too, so briefs must not hand over a file path and leave the
narrowing implied.

## Which tool for which question

1. **`rg`** for anything textual, and as the ground truth for every other tool's zero.
2. **`ast-grep` through a rule file** for structural sweeps a regex cannot express.
3. **`pal`'s `chat` with a Custom/local model** for pre-narrowed reading, and whenever the Gemini
   provider is throttled or unavailable.
4. **`pal`'s `chat` with a Gemini model** when the window is the point — the frozen Swift app,
   cross-repo sweeps.

**Send the volume reading to another model.** Call the `pal` MCP server's `chat` tool for anything
where the large window is the point (a whole module doc, cross-repo sweeps), passing a `model` from
`.pal/gemini_models.json` or `.pal/custom_models.json` — ask `listmodels` first if none is named. Ask
it which files cover a concern and where to look next, never for a line number — `rg -n` answers that
exactly and for free. It returns an answer to act on only after you verify it, never a conclusion to
act on directly. `docs/SUBAGENTS.md` has the dispatch detail, and its "Beyond `chat`" section has the
per-tool call: `consensus` (multi-model debate, free across `.pal/openrouter_models.json`'s 16
models, for a genuinely contested design decision), `thinkdeep` (one model's second opinion on a hard
tradeoff), `debug` (hypothesis-driven investigation given concrete failure evidence), `codereview`
(an independent second reviewer with none of this repo's conventions baked in, fed those conventions
explicitly), `secaudit` (OWASP-based audit — narrow surface today, on-disk storage and import/export
paths are what it can usefully check now, real value once sync/auth or monetisation land) and
`challenge` (offloading pushback to a model with no stake in the answer) are all adopted.
`precommit`/`analyze` stay redundant with `/code-review`, `refactor`/`testgen`/`docgen`
a poor fit for this repo's conventions. `docs/TOOLING.md` has the full model catalogue.

**Delegating is the default, and it fails by being forgotten rather than by being rejected.** Knowing
the rule does not fire it: it has been broken twice in one session by an agent that had just written
it down, once reading a 573-line doc directly and once hand-filtering a file already earmarked for
`pal`. Three moments are the trigger, and each is a hard stop, not a preference:

- About to `Read` a file over ~300 lines, or the third file in a row on one question. Dispatch instead.
- About to write a second shell command that filters, greps or reshapes the same data. The first is
  narrowing; the second means the analysis itself is the job, and the job belongs to a reader model.
- Already decided a file goes to `pal`. Then it goes now, unfiltered. Preparing it by hand spends
  the tokens the dispatch existed to save.

**`docs/TOOLING.md` has the measured behavior** of `rg`, `ast-grep` and `pal`, and which to reach
for. One rule from it that is never worth rediscovering:

- **`rg` never reports a false zero, and everything else can.** A bare `ast-grep -p` pattern matches
  nothing on Dart whatever the code contains, because the pattern parses without surrounding context.
  Ground-truth every empty result with `rg`.
