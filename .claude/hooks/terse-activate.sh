#!/bin/bash
# Injects the terse skill's ruleset as SessionStart context, so response
# style survives a session start without depending on the model noticing
# the skill file on its own or remembering CLAUDE.md's pointer to it.
set -uo pipefail

skill_path="$CLAUDE_PROJECT_DIR/.claude/skills/terse/SKILL.md"
[[ -f "$skill_path" ]] || exit 0

body=$(awk 'BEGIN{d=0} /^---$/{d++; next} d!=1{print}' "$skill_path")
printf 'TERSE MODE ACTIVE — see .claude/skills/terse/SKILL.md.\n\n%s' "$body"
