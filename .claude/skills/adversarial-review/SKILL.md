---
name: adversarial-review
description: Run a multi-angle adversarial review of delivered SpendWise code at a phase boundary, consolidate the confirmed findings, and file them into the open change's tasks.md. Use when the user asks for an adversarial review, a review before starting the next phase or the UI, or asks to audit what has been delivered so far.
---

# Adversarial review

Used at a phase boundary, before the next change starts. The output is **numbered tasks in
`tasks.md`**, not edits. Nothing is fixed during the review.

## 1. Fix the target

Establish what "delivered so far" means before spawning anything: the change under review, the
groups its `tasks.md` marks complete, and the current test count and analyzer state.

```sh
cd packages/domain && dart analyze && dart test 2>&1 | tail -3
```

Record the baseline count. Every agent reports against it.

## 2. Spawn the angles

Run agents in parallel, one angle each, **read-only unless the angle needs to mutate**. Give every
agent `Bash` — an agent that cannot run `dart test` can only speculate. Typical angles:

- **Spec conformance.** Read `lib/` line by line against the change's `specs/` and the module spec
  in `docs/modules/`. Report where code and spec disagree, and say which one is wrong.
- **Correctness and robustness.** Dart-level defects: null-versus-false comparisons, order
  dependence, unguarded public parameters, mutation through an escaping reference.
- **Test rigor by mutation.** Mutate each guard and cascade in turn, run the suite, and report every
  mutant that survives. A surviving mutant names an untested rule. Restore by file copy, never with
  git.
- **Invariants and illegal states.** Try to reach a state a clause forbids using only the public
  API. Anything reachable is a guard gap, not an invariant gap.

Tell each agent: report `path:line: severity: problem. fix.`, no praise, no scope creep, and to
state plainly when a check could not be run.

## 3. Verify before you believe

Every finding is a claim until read at the cited `file:line`.

- Check the authority a finding claims to contradict. An audit once reported as CRITICAL a behavior
  the spec explicitly requires, and three dependent findings collapsed with it.
- Where two agents disagree, that disagreement is the signal — resolve it against the spec.
- Drop findings that restate a deliberate decision recorded in `design.md`.

Say plainly which findings did not survive verification and why.

## 4. Consolidate into tasks.md

Merge duplicates across agents, order by severity, and append to the open change's `tasks.md`.

- Renumber the items below the insertion point, or append at the end. Never leave two 10.1s.
- One task per confirmed finding, naming the file and the fix.
- Every scenario an agent probed to prove a finding becomes a test task, including probes that
  turned out to pin correct-but-surprising behavior.
- A finding that needs a spec change is a spec task first, then a code task.

Report the consolidated list, the baseline versus final test count, and what was rejected. Do not
commit.
