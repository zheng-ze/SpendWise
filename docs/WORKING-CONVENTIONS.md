# Working conventions

Detail behind `CLAUDE.md`'s terse rules on comments, commits, handovers and verification.

## Comments

Comment only tricky nuance, deliberate spec deviations, or ordering constraints a reader would
otherwise break. Never restate what the code says. No Swift references and no spec citations in
source; no em dashes, semicolons or colon splices in comment prose. Tests are held to the same
budget — the test name carries the intent.

**Every comment must be standalone.** A reader with only this one file open must be able to fully
understand it, unaided. This is a broader bar than "no doc/task references" — a comment also fails
if it leans on another function or file to make its point ("same as X", "mirrors Y's behavior")
without stating what X or Y actually does, or if it assumes context from a different part of the
codebase that isn't restated locally. Naming a sibling process to justify local behavior ("purge
pins the parent", "matches updateAccount's clearing rule") is the most common way this fails — state
the local reason in local terms instead.

Write the comment last, and only after asking what a reader would get wrong without it. Comments get
written by default and trimmed on request, when the default should be silence. A name that carries
the behaviour retires the comment that explained it — prefer renaming to annotating
(`monthWithDayUtc` needed a comment; `shiftMonthThenClampDayUtc` needed none).

**At most two wrapped lines, no examples.** A comment runs at most two lines at the file's normal
wrap width (~100 chars/line) — not one line crammed past that width, and not a paragraph explaining
the mechanism the code below already shows. No made-up dates or ids, no step-by-step trace, and no
`(e.g. X)` naming a real symbol the surrounding code already names. A real name in an aside is still
an example: it restates what the next line already says instead of explaining why. The test right
below the comment is already the concrete case; a comment that re-walks it in prose is restating,
not explaining. If the why does not fit two lines, the code needs a better name, not a longer
comment.

**`///` is for the API's caller, `//` is for its implementer.** A doc comment (`///`) belongs only on
a public member whose behavior a caller genuinely needs and the signature does not already convey —
a non-obvious precondition, a surprising return, a real contract detail. It is never the place for
why the body is written the way it is; that is an implementation detail and takes a `//` comment
inside the body instead, private members included. Most members need neither: a well-named public
function with an unsurprising contract gets no doc comment at all, and most bodies get no inline
comment at all.

**A `///` states behavior, never rationale.** If a doc comment is genuinely needed, it says what the
member does or guarantees, not why it is built that way. The why is an implementation concern; when
worth keeping at all, it goes in a `//` inside the body, never in the doc comment above it.

**Place the comment on the line it explains.** A `//` sits directly against the specific statement
it justifies, not stacked once above a whole function to cover several lines below — pin it to the
line, not the block, so a reader never carries it past code it does not apply to.

**Comment discipline is a write-time and verify-time responsibility, not a later sweep.** A
dispatched agent should not write a redundant or non-standalone comment in the first place, and
whoever verifies that agent's work before marking a task complete must check for and remove any that
slipped through then — not defer it to a separate cleanup pass. Every implementation brief should
carry this section's rules, not just point at this file.

## Staging and commits

**When asked to stage uncommitted work, split it into logical chunks and stage one at a time.**
Group by task/change, not by file type or directory. Suggest a one-line commit message per chunk but
do not commit it — the user commits. Wait for an explicit go-ahead before staging the next chunk; a
short reply like "next" or "yes" means continue the pattern, not a request to compress reporting
further.

## Handover docs

A handover doc (`docs/HANDOVER.md`) records only the working end state. No debugging narrative for a
tool that now works, no restating verification results that already stand unchanged, and no
restating open tasks — those live in the next change's `tasks.md`, written so each item is
self-contained without the handover's help. A task discovered while closing one change goes into the
`tasks.md` of whichever change will actually pick it up next, not left behind in the closed change
because that is where it surfaced. The doc is overwritten each session rather than accumulating —
one file, current state only, no numbering. Handover docs stay untracked.

## Verifying subagent work

Treat every finding as unverified until read at the cited `file:line`. A subagent may cite a user
instruction that is absent from your transcript and still be right — the user intervenes in running
subagents directly.

This includes a subagent's own "still open" or "incomplete" claims about a task — the flag can be
honest while the stated reason for it is wrong, so check why a task is marked incomplete, not just
that it is. And it includes your own retelling of a subagent's finding: summarizing it in different
words is a new claim, not a repeat of a verified one, and needs the same re-derivation from source
before it is presented as fact.
