#!/bin/bash
# Formats a single Dart file after Claude edits it. Reads the hook payload on
# stdin and exits quietly for every non-Dart path, so editing docs or JSON does
# not invoke the formatter.
set -uo pipefail

payload=$(cat)
file=$(printf '%s' "$payload" | /usr/bin/python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))
except Exception:
    print("")')

[[ "$file" == *.dart ]] || exit 0
[[ -f "$file" ]] || exit 0

dart format "$file" >/dev/null 2>&1 || exit 0
