# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: record any major decision on the issue itself before opening the PR — a correction to
  the issue's original text, a design choice made during implementation, a scope change — so the
  ticket carries that context whether or not anyone reads the PR later. The PR body then references
  each resolved issue with `Closes #<n>`, and GitHub closes them automatically on merge. Don't
  reserve decision commentary for a close-time step; write it when the decision is made.

Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number> --comments` and `gh pr diff <number>` for the diff.
- **List external PRs for triage**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments` then keep only `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` (drop `OWNER`/`MEMBER`/`COLLABORATOR`).
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either — resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Recon operations

Used by the `recon` skill. The **work map** is a GitHub Project (v2), not an issue.

- **Canonical Project**: [SpendWise Work Map](https://github.com/users/zheng-ze/projects/1). Discover it with `gh project list --owner zheng-ze` when the URL is not already known; do not create a second one.
- **Fields**: built-in `Labels` (carries `type:decision`/`type:research`/`type:task` and `mode:hitl`/`mode:afk`), built-in `Parent issue` and `Sub-issues progress` (native hierarchy), plus custom fields `Feature` (single select), `Claim` (text, opaque session token), and `Claimed at` (date). List field/option IDs with `gh project field-list <number> --owner zheng-ze --format json`.
- **Registering an issue**: `gh project item-add <number> --owner zheng-ze --url <issue-url>`. Adding an issue that has native GitHub sub-issues also adds its sub-issues automatically.
- **Setting a field**: `gh project item-edit --id <item-id> --field-id <field-id> --project-id <project-id> --single-select-option-id <option-id>` (single select) or `--text <value>` (text/date fields).
- **Claiming**: read the item's `Claim` field immediately before writing (`fieldValueByName` on the `ProjectV2Item` via `gh api graphql`), write this session's token only if empty (`updateProjectV2ItemFieldValue` with a `text` value), then re-read to confirm the write held. Release with `clearProjectV2ItemFieldValue`. This is a check-then-set, not an atomic compare-and-swap — a race window exists between the read and the write.
- **Hierarchy**: `gh api repos/<owner>/<repo>/issues/<n>/sub_issues` lists native children; add one with `gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues -f sub_issue_id=<child-database-id>`.
- **Blocking**: same native-dependency mechanism as Wayfinding below — `issue_dependencies_summary.blocked_by` on `gh api repos/<owner>/<repo>/issues/<n>`, with the `Blocked by: #<n>` body-line fallback only when unavailable.
- **Frontier query**: every Project item that is an open issue, has `issue_dependencies_summary.blocked_by == 0`, and has an empty `Claim` (or a `Claim` equal to this session's token).
- **Markdown fallback**: `docs/map.md`, used only if the Project becomes unavailable; none exists today because the Project backend is available.

The retired `recon:map` issue-only work map (a single issue such as the closed #70) is not the canonical index. Historical `recon:map`-labeled issues are kept only as historical record.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (`gh api` on the sub-issues endpoint). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitHub's **native issue dependencies** — the canonical, UI-visible representation. Add an edge with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only — the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me` — the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.
