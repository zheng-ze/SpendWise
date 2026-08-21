---
name: tech-writer
description: Write/edit comments, docstrings, READMEs, API docs, or prose docs per Google Developer Documentation Style Guide, with SpendWise's own comment rules layered on top. Use when user asks to document code, write a docstring, write/fix comments, draft a README or design doc, or says "google style", "tech writing", "/tech-writer".
disable-model-invocation: false
---

# Skill: Technical Writing (Google Dev Doc Style + SpendWise rules)

Google guide not one flat rule set — target differs by artifact. Pick track first.

## Track pick

- **Comment** (inline `//` or `#`): explain WHY only, non-obvious. Never restate code. SpendWise
  rules below govern this track — they are stricter than generic Google style and win on conflict.
- **Docstring** (`///`, JSDoc, Python docstring): describe WHAT for a caller — params, return, throws,
  preconditions. Not implementation rationale.
- **Prose doc** (README, guide, design doc, tutorial): full Google guide applies — headings, voice,
  lists, structure below.

Wrong track = wrong output. A docstring padded with rationale, or a comment restating the signature,
fails even if grammar perfect.

## Core rules (all tracks)

- Second person, active voice, present tense: "The function returns X" not "X is returned" / "X will
  return". Imperative for instructions: "Click Save", not "You should click Save."
- Present tense over future: system behaves NOW, not "will do."
- One idea per sentence. No stacked subordinate clauses.
- Terms: use one term per concept, consistently. Don't vary vocabulary for style ("elegant variation"
  is a fiction-writing habit; docs need repetition for scanability).
- Define a term or acronym on first use if not obvious to target reader; don't redefine every doc.
- Numbers: numerals for 10+, and always for units/versions/counts a reader might scan for (e.g. "3
  retries", not "three retries").
- Lists: use for 3+ parallel items or sequential steps. Parallel grammatical form across items
  (all imperative, or all noun phrases — don't mix). Prose for anything with connecting logic a
  bullet would flatten.
- Headings: sentence case ("Configure the client", not "Configure The Client"), descriptive not
  clever, front-loaded with the key term (readers scan first word).
- Directional language ("see below", "as shown above") is fine in prose docs where structure aids
  navigation — Google's own guide uses it. Avoid it only in short-form output (docstrings, comments,
  chat replies) where there's no "below" to point to.
- Hedging ("generally", "usually", "in most cases") is a content signal, not filler, when the claim
  really is conditional — cutting it makes an accurate statement false. Cut it only when the claim is
  actually unconditional and the hedge is reflexive throat-clearing.
- Second-person "you" for docs addressing a reader performing steps; omit the addressee entirely in
  comments/docstrings (no "you" in a docstring — describe the API, not a reader).

## Track: comment — SpendWise rules (govern over generic Google style)

**Say the why, never the what.** Comment only tricky nuance a reader would otherwise get wrong. Never
restate what the code already says.

**Standalone.** Understandable with only this one file open. Never lean on another function, file, or
doc without restating its point locally — no "see X", no assuming the reader has another file open.

**At most two wrapped lines**, at the file's normal wrap width (~100 chars/line). Not one line crammed
past that width, not a paragraph. If the why doesn't fit two lines, the code needs a better name, not
a longer comment.

**No:**
- made-up dates or ids
- step-by-step trace of what the code below does
- `(e.g. X)` naming a real symbol the surrounding code already names
- restating the mechanism the code below already shows
- Swift references or spec citations in source
- em dashes, semicolons, or colon splices

**Plain language.** Say what a thing does in ordinary words, not jargon or borrowed vocabulary. A
function called `monthWithDayUtc` needs a comment explaining it shifts the month before clamping the
day; `shiftMonthThenClampDayUtc` needs none.

**Sits on the line it explains, not above the block.** Put the comment right against the specific
statement it justifies, not once at the top of a function covering several lines below it.

**Write-time and verify-time discipline.** Write the comment last, after the code is settled — not
drafted early and left stale. Whoever verifies the work checks the comment against these rules before
marking the task complete; this is never a later sweep.

**`///` doc comments are for API callers, not implementers.** Write one only when a public member has
behavior a caller must know and the signature doesn't already say it — non-obvious precondition,
surprising return value, contract detail. A private member or an implementation detail takes a `//`
comment instead, never `///`. **A `///` states behavior only, never rationale** — why the member is
built that way belongs in a `//` inside the body, if it's worth keeping at all, never in the doc
comment above it.

**Punctuation and capitalization (Google Python style, applies to any language here).** A comment long
enough to be a sentence gets normal sentence capitalization and a period. A short end-of-line fragment
can skip both, but stay consistent within one file — don't mix capitalized-with-period and
lowercase-no-period comments in the same file.

**TODO format, when a TODO is actually warranted.** `// TODO: <bug or issue link> - <what and why>`.
Never a bare `// TODO(username)` with no link, never a TODO with no link at all, never vague enough
that a future reader can't tell what finishes it. If SpendWise has no issue tracker link to give,
say so rather than inventing one — a made-up id fails the "no made-up dates or ids" rule above.

## Track: docstring

- First line: one-sentence summary of behavior, third person indicative ("Returns the parsed
  config." not "This function returns…" — drop the throat-clearing subject).
- State preconditions, param contracts, return contract, and thrown/raised errors only if
  non-obvious from the signature and type.
- Never include rationale, history, or "why built this way" — that's a body comment, not doc comment.
- No usage examples unless the API's calling convention is genuinely non-obvious from signature
  alone (e.g. requires a specific call order).
- In this repo, apply the SpendWise `///` rule above: behavior only, never rationale.

## Track: prose doc

Structure:
1. Lead with outcome/purpose in the first sentence or first paragraph — what the reader will be able
   to do, not a throat-clearing intro ("This document describes...").
2. One H1 (title), H2 for major sections, H3 sparingly. Never skip a level.
3. Prerequisites/assumptions stated before instructions, not interleaved.
4. Numbered list for sequential steps the reader must do in order. Bulleted list for unordered
   facts/options. Never number a non-sequential list.
5. Code samples: minimal, runnable, no unrelated context. Label the language. Comment inside the
   sample follows the comment track rules above.
6. Warnings/notes: call out only real risk (data loss, breaking change, security). Format as a
   labeled block (`**Warning:**`, `**Note:**`), not buried in prose.
7. No unearned superlatives ("simply", "just", "easy") — a step that's not simple for the reader
   reads as condescending when labeled simple.

## What NOT to do (common failure against this guide)

- Do not compress into caveman/telegraphic style for prose docs — Google style is concise but
  grammatically complete; dropped articles and fragments are a different register, not this one.
- Do not force every explanation into bullets — a bulleted list of causally-connected sentences loses
  the connection; that's prose's job.
- Do not strip all hedging reflexively — check whether the underlying claim is actually unconditional
  first.
- Do not add a docstring to a private/internal function whose name and signature already say
  everything a caller needs — an empty-content docstring is worse than none.
- Do not cite Swift source or a `docs/specs/` passage inside a code comment — the SpendWise rule
  above bans it even when it would explain the why accurately.

## Output

Docstring/comment requests: output the exact text to insert, in the surrounding language's comment
syntax, no wrapper prose.
Prose doc requests: output the doc body directly (or write to the target file if the user named one).
Question about the guide itself: direct answer, cite the specific rule invoked.
