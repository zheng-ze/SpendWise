# Local model benchmarks

**Superseded.** These measurements are for the retired `scripts/qwen.sh`, which called LM Studio on
the LAN host directly. That path is gone — reading now goes through the `pal` MCP server's `chat`
tool, using its Custom provider for the same host (see `docs/TOOLING.md`'s `## pal` section). The
numbers below describe the old direct-call path, not pal's. Kept as historical record rather than
deleted; do not read them as claims about pal's behavior.

Measured on the LAN host at `192.168.1.150:1234`, on this repo, against anchors verified with `rg`
before use. Everything at `temperature 0`, so a repeated run returns the same answer.

The conclusions these support live in `docs/SUBAGENTS.md` and `scripts/qwen.sh`. This file is the
evidence, kept out of the files loaded every session.

Only two builds survived the comparison and are installed: `qwen2.5.1-coder-7b-instruct` at 32768,
and `qwen2.5-coder-7b-instruct-128k` at 131072 with a `Q8_0` cache. Every other id below was measured
and then deleted, and the `@q6_k` and `@q8_0` suffixes belonged to a period when several quants of
one model sat side by side.

## The short version

- **It cannot find line numbers.** One target of three, at every size and setting. `rg -n` is the
  tool for this.
- **It can say which file covers what.** That still worked at 70k tokens.
- Payload size, quantization and KV cache precision barely move either result.
- The builds with 128k windows are weaker than the 32k builds, including on small payloads.

## Anchor recall

Ten anchors across eight files, one call per file, `Q6_K` unless noted. `exact` is the line number
matching; `pathed` is the answer naming the file at all, without which an anchor cannot be resolved.

| Build | Window | KV | exact | pathed | wall |
|---|---|---|---|---|---|
| `qwen2.5.1-coder-7b-instruct@q6_k` | 32768 | F16 | 7/10 | 10/10 | 6s |
| `qwen2.5-coder-7b-instruct@q6_k` | 32768 | Q8_0 | 7/10 | 10/10 | 6s |
| `qwen2.5.1-coder-7b-instruct@q8_0` | 32768 | F16 | 6/10 | 10/10 | 6s |
| `qwen2.5.1-coder-7b-instruct@q8_0` | 32768 | Q8_0 | 5/10 | 10/10 | 6s |
| `qwen2.5-coder-7b-instruct@q8_0` | 32768 | F16 | 6/10 | 8/10 | 6s |
| `qwen2.5-coder-7b-instruct-128k@q6_k` | 131072 | Q8_0 | 6/10 | 9/10 | 6s |
| `qwen2.5-coder-7b-instruct-128k@q4_k_m` | 32768 | Q8_0 | 6/10 | 9/10 | 5s |
| `qwen2.5-coder-14b-instruct` | 24576 | — | 8/10 | 5/10 | 155s |

**These numbers are flattering and should not be quoted as capability.** Six of the ten targets sit
on lines 1, 3, 4, 9, 37 and 51 of their files. A symbol near the top is found; the harder probe below
shows what happens otherwise.

## The probe that corrected the above

Three targets in one file, spread through it: `flushNow` at 108, `_saveCycle` at 168, `_coalesce` at
230. One symbol per call, filler prepended so the target always sits at the end of the prompt.

| Build | 4k | 10k | 20k | 30k | 50k | 70k | 95k |
|---|---|---|---|---|---|---|---|
| `qwen2.5.1-coder-7b-instruct@q6_k` | 1/3 | 1/3 | 1/3 | 1/3 | — | — | — |
| `qwen2.5.1-coder-7b-instruct@q8_0` | 1/3 | 1/3 | 1/3 | 1/3 | — | — | — |
| `qwen2.5-coder-7b-instruct-128k@q6_k` | — | 0/3 | 0/3 | — | 1/3 | 0/3 | 1/3 |

`flushNow` is the one it finds, at every size, because it is the only `Future<void> flushNow()` in
the file. `_saveCycle` and `_coalesce` were missed by every build at every size, and `_saveCycle` was
usually answered `108`, which is `flushNow`'s line.

Asked to quote the line defining `_coalesce` rather than number it, the answer was:

```
208:       _report(SaveBannerState.clear);
```

A real line, correctly numbered, and not the one asked for. The failure is not a drifting anchor, it
is pairing a plausible line with its true number.

## Question count

Same file, same 3.8k payload, `qwen2.5.1-coder-7b-instruct@q6_k`:

| Query | exact |
|---|---|
| four symbols in one call | 0/4 |
| one symbol per call | 2/4 |

Batching also loses the paths on most builds. Splitting is worth doing when something must be asked,
but it does not lift the ceiling above.

## Orientation

`qwen2.5-coder-7b-instruct-128k@q6_k`, asked which files define table schemas or map rows.

At 38k it named `drift_ledger_store.dart`, `ledger_database.dart` and `mappers.dart` correctly, and
listed `persistence_processor.dart` under the domain. That file is in `app/lib/` and was not in the
payload at all, so file lists need checking against the tree.

At 70k, where anchor recall had already collapsed, it named `tables.dart` and `mappers.dart`
correctly, described `accountToRow` and `entryFromRow` accurately, and when there was no genuine
third it offered `calendar_day.dart` while saying plainly that it defines no schema. Hedging rather
than inventing.

This is the one task that survives a large payload. A line number is a single token that has to be
exactly right; "this file handles persistence" is carried by hundreds of tokens across the file, so
most can be lost and the answer still holds.

## Windows and memory

Nothing about accuracy changes with the window: 32768, 65536, 98304 and 131072 all returned the same
score on the same build. What the window changes is whether the model fits on the card.

| Build | Window | KV | wall on a 38k prompt |
|---|---|---|---|
| `128k@q6_k` | 131072 | F16 | 335s |
| `128k@q6_k` | 131072 | Q8_0 | 20s |
| `128k@q8_0` | 65536 | F16 | 112s |
| `128k@q8_0` | 65536 | Q8_0 | 20s |
| `128k@q8_0` | 98304 | Q8_0 | 20s |

Each slow row is the KV cache spilling to system memory, at identical accuracy. `128k@q8_0` at
131072 does not load at all. So a slow answer means something stopped fitting, and the fix is a
smaller cache or a smaller window, never a different prompt.

## Reproducing

Scripts live in the session scratchpad rather than the repo, since they pin anchors that move
whenever the source does. They read `SUBAGENT_API_BASE` and take a model id:

- `bench_single.py` — one symbol per call across payload sizes. The probe that matters.
- `bench_qwen.py` — ten anchors, three payload tiers, batched.
- `bench_split.py` — the same ten, one call per file.
- `bench_window.py` — eight anchors at payloads sized to fill a large window.
- `run_matrix.sh <model> <label>` — both protocols against one loaded build.

Re-verify every anchor with `rg -n` before trusting a re-run. The line numbers in this file were true
when written and the source moves.
