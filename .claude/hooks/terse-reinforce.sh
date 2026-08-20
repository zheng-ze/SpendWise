#!/bin/bash
# Per-turn reminder so terse style stays visible in the model's attention
# even after a long session or a context compaction prunes the SessionStart
# injection away. Emits a short line, not the full ruleset — SessionStart
# already paid that cost once.
set -uo pipefail

cat >/dev/null

printf '{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "TERSE MODE ACTIVE — session ruleset applies (see .claude/skills/terse/SKILL.md)."}}'
