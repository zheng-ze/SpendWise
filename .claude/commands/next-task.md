---
description: Show the next unticked tasks in the open change and what they depend on
---

Read `openspec/changes/add-domain-accounting/tasks.md` — or the open change named in `$ARGUMENTS` if
one is given — and report:

1. The next unticked task, quoted in full.
2. Any other unticked tasks in the same group, since a group is usually worked together.
3. Whether the groups it depends on are really complete: check that the ticked items above it name
   files that exist and hold what the task says they hold. A tick is a record of what was verified,
   but confirm before building on it.
4. Whether it is a test task, a source fix, or both.

Then stop and wait. Do not start the work, and do not edit `tasks.md` — the queue is the main
thread's to tick, and only after verifying the work at its cited `file:line`.
