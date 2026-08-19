---
name: chunk-commit
description: Stage uncommitted work one logical chunk at a time, suggesting a one-line commit message per chunk, pausing for go-ahead before each. Use when the user asks to stage/commit uncommitted work, or says "let's commit this", "stage in chunks", "chunk by chunk".
disable-model-invocation: false
allowed-tools: [Bash, Read]
---

# Skill: Chunk Commit

Never run `git commit` — the user commits themself. This skill only stages and suggests messages.

1. Run `git status --short` and `git diff` (plus `git diff --staged` if anything is already staged)
   to see the full set of uncommitted work.
2. Group the changes into logical chunks by task/change, not by file type or directory. A chunk is
   the smallest set of files that tells one coherent story (one fix, one feature slice, one doc
   update). Untracked files you created yourself this session that are meant to stay untracked
   (scratch, generated) are not a chunk — leave them alone unless the user's instructions say
   otherwise.

   **Docs and task files never share a chunk with code.** `docs/`, `openspec/**/tasks.md`, and any
   other planning/spec/task file get their own chunk(s), separate from `.dart`, `.swift`, and other
   source changes — even when they describe the same piece of work. A code chunk may still depend on
   a docs chunk landing first (or vice versa); note that ordering when presenting the plan, but keep
   them as distinct chunks with distinct commit messages.
3. Present the planned chunk breakdown before touching anything: list each chunk's files and a
   one-line commit message for it. Wait for confirmation on the plan itself if the grouping is not
   obvious.
4. For each chunk, in order:
   - `git add <specific paths>` — never `git add -A` or `git add .`.
   - Show `git status --short` scoped to what just got staged, and the one-line commit message
     suggestion for this chunk.
   - Stop and wait for an explicit go-ahead before staging the next chunk. A short reply like
     "next" or "yes" means continue to the next chunk with the same level of detail — it is not a
     request to compress or skip the per-chunk pause.
5. If the user says a suggested message is wrong, revise just that line and re-show it — do not
   restage.
6. After the last chunk is staged and confirmed, stop. Do not commit, push, or suggest a PR unless
   asked.

If a file's content looks like it might contain secrets (`.env`, credentials, keys) even under an
innocuous name, flag it and ask before staging it in any chunk.
