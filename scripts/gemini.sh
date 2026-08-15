#!/usr/bin/env bash
# Ask Gemini a question about this repository.
#
#   scripts/gemini.sh "<question>"
#
# Gemini is agentic and reaches its own files through run_shell_command, read_file and grep_search,
# so the caller sends one broad question rather than a pre-narrowed file list. Merge separable
# questions into one call with numbered sections instead of dispatching more than once: the quota is
# per call, not per token, so a narrow question spends the same budget as a broad one.
#
# --skip-trust is required because this repo is not a Gemini trusted folder; without it the command
# hangs or exits with no output.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 \"<question>\"" >&2
  exit 2
fi

QUESTION="$1"
MODEL="${GEMINI_MODEL:-gemini-3.6-flash}"

PROMPT="${QUESTION}

Use run_shell_command with rg -n, or ast-grep through a rule file, to locate anchors, and open each
line you are about to cite to confirm it before citing it. Summarize succinctly. Highlight core
architectural relationships, key logic flows and edge cases. Keep code snippets under 5 lines. Cite
a file path and line number for every claim."

START=$(date +%s)
OUTPUT=$(gemini --skip-trust --model "$MODEL" -p "$PROMPT")
ELAPSED=$(( $(date +%s) - START ))

echo "$OUTPUT"
echo
echo "[gemini.sh: model=$MODEL elapsed=${ELAPSED}s]" >&2
