# Manual-only skills

A skill with `disable-model-invocation: true` in its frontmatter is deliberately excluded from the
model's own skill listing — it never auto-triggers and won't appear in a session's discovered-skills
reminder. It still exists and still runs once invoked by its exact name, so a search for it by
filename/grep is the fix, not a report that it's missing. Two review skills in this repo's set work
this way and are easy to forget:

- **`thermo-nuclear-code-quality-review`** (`.claude/skills/`) — an unusually strict maintainability
  review: pushes for "code judo" restructurings, flags any file crossing 1000 lines, and treats
  scattered ad-hoc branching as a design defect rather than a style nit. Invoke by exact name for a
  harsher pass than the default `code-review` skill.
- **`mattpocock-skills:improve-codebase-architecture`** (plugin skill) — scans for shallow-module
  "deepening opportunities" using the `codebase-design` vocabulary (module, interface, depth, seam,
  adapter, leverage, locality) and writes a visual HTML report to a temp file rather than editing
  code directly. Several sibling `mattpocock-skills` are also manual-only for the same reason:
  `ask-matt`, `grill-with-docs`, `implement`, `setup-matt-pocock-skills`, `to-spec`, `to-tickets`,
  `triage`, `wayfinder`.
