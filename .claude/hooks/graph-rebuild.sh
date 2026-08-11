#!/usr/bin/env bash
# Keep the knowledge graph current with the working tree.
#
# `code-review-graph update` is commit-driven: it diffs commits and reports "0 files updated" for a
# file that visibly changed on disk. Only a full `build` re-parses the working tree, and at ~1.2s on
# this repo it is cheap enough to run after every edit.
#
# Discovery is git-tracked files only, so a newly created file stays invisible until its path is
# registered. `git add -N` is enough — it records the path without staging content — and agents are
# expected to run it when they create a file. This hook does not stage anything itself.
set -uo pipefail

cat >/dev/null || true

command -v code-review-graph >/dev/null 2>&1 || exit 0
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# No extension filter. The parser covers 60+ languages and the list moves between releases; letting
# build decide what it can parse costs less than maintaining a copy of that list here.
code-review-graph build --skip-flows --repo "$ROOT" >/dev/null 2>&1 || true

exit 0
