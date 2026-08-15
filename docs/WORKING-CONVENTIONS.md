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

## Phase handover docs

A phase handover doc (`docs/HANDOVER-PHASE*.md`) records only the working end state. No debugging
narrative for a tool that now works, no restating verification results that already stand unchanged,
and no restating open tasks — those live in the next change's `tasks.md`, written so each item is
self-contained without the handover's help. A task discovered while closing one change goes into the
`tasks.md` of whichever change will actually pick it up next, not left behind in the closed change
because that is where it surfaced. Handover docs stay untracked — skip `git add -N` for them, unlike
every other file an agent creates.

## Verifying subagent work

Treat every finding as unverified until read at the cited `file:line`. A subagent may cite a user
instruction that is absent from your transcript and still be right — the user intervenes in running
subagents directly.

This includes a subagent's own "still open" or "incomplete" claims about a task — the flag can be
honest while the stated reason for it is wrong, so check why a task is marked incomplete, not just
that it is. And it includes your own retelling of a subagent's finding: summarizing it in different
words is a new claim, not a repeat of a verified one, and needs the same re-derivation from source
before it is presented as fact.
