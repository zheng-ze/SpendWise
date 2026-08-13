#!/usr/bin/env bash
# Ask the local Qwen2.5-Coder instance a question about one or more files.
#
#   scripts/qwen.sh "<question>" <file> [<file> ...]
#
# Files are sent with 1-based line numbers prepended so the model can cite anchors. Ask about one
# symbol per call: four in a single query placed none of them correctly, where one at a time placed
# half exactly. Payload size is not the problem, the number of questions is.
# The ceiling is whatever window the loaded build was given, and the server rejects an oversized
# request with HTTP 400 rather than truncating, so an over-budget call fails loudly.
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 \"<question>\" <file> [<file> ...]" >&2
  exit 2
fi

: "${SUBAGENT_API_BASE:?SUBAGENT_API_BASE is not set}"
MODEL="${SUBAGENT_MODEL:-qwen2.5-coder-14b-instruct}"

QUESTION="$1"
shift

python3 - "$SUBAGENT_API_BASE" "$MODEL" "$QUESTION" "$@" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base, model, question, *paths = sys.argv[1:]

blocks = []
for path in paths:
    with open(path) as handle:
        body = "".join(f"{n}: {line}" for n, line in enumerate(handle, 1))
    blocks.append(f"=== {path} ===\n{body}")

prompt = (
    f"{question}\n\n"
    "Cite every claim as path:line using the line numbers shown. Say NOT PRESENT rather than "
    "guessing. No prose beyond what was asked.\n\n" + "\n".join(blocks)
)

payload = json.dumps(
    {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0,
        "max_tokens": 1200,
    }
).encode()

request = urllib.request.Request(
    base.rstrip("/") + "/chat/completions",
    data=payload,
    headers={"Content-Type": "application/json"},
)

try:
    with urllib.request.urlopen(request, timeout=900) as response:
        raw = response.read().decode()
except urllib.error.HTTPError as error:
    detail = error.read().decode()
    print(f"qwen.sh: HTTP {error.code}: {detail}", file=sys.stderr)
    if "exceed_context_size_error" in detail:
        print("qwen.sh: payload over the 24576-token ceiling, send fewer files", file=sys.stderr)
    sys.exit(1)

# LM Studio emits literal newlines inside JSON strings, which strict parsing rejects.
answer = json.loads(raw, strict=False)
usage = answer["usage"]
print(answer["choices"][0]["message"]["content"].strip())
print(
    f"\n[prompt_tokens={usage['prompt_tokens']} "
    f"completion_tokens={usage['completion_tokens']} "
    f"finish={answer['choices'][0]['finish_reason']}]",
    file=sys.stderr,
)
PY
