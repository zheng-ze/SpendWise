#!/usr/bin/env bash
# Ask the local Qwen2.5-Coder instance a question about one or more files.
#
#   scripts/qwen.sh "<question>" <file> [<file> ...]
#
# Files are sent with 1-based line numbers prepended so the model can cite anchors. Ask about one
# symbol per call: four in a single query placed none of them correctly, where one at a time placed
# half exactly. Payload size is not the problem, the number of questions is.
#
# LM Studio on the host server loads a model on demand when a request names one that is not
# resident, so the first call after an idle host pays the load before any tokens are produced. The
# preflight below reports that wait rather than letting it look like a hang, and it catches a
# misspelled model id up front, where the server would otherwise load nothing and return a 404.
#
# The ceiling is whatever window the named build was given, and the server rejects an oversized
# request with HTTP 400 rather than truncating, so an over-budget call fails loudly.
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 \"<question>\" <file> [<file> ...]" >&2
  exit 2
fi

: "${SUBAGENT_API_BASE:?SUBAGENT_API_BASE is not set}"
MODEL="${SUBAGENT_MODEL:-qwen2.5.1-coder-7b-instruct}"

QUESTION="$1"
shift

python3 - "$SUBAGENT_API_BASE" "$MODEL" "$QUESTION" "$@" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base, model, question, *paths = sys.argv[1:]
root = base.rstrip("/").removesuffix("/v1")


def preflight(model):
    """Report the model's residency and window, or None when the catalog is unreachable.

    A wrong id is worth catching here: LM Studio answers it with a 404 after the caller has already
    waited, and the message does not say which ids exist.
    """
    try:
        with urllib.request.urlopen(root + "/api/v0/models", timeout=15) as response:
            catalog = json.loads(response.read().decode(), strict=False)
    except (urllib.error.URLError, TimeoutError, ValueError):
        return None

    entries = {m["id"]: m for m in catalog.get("data", []) if m.get("type") == "llm"}
    entry = entries.get(model)
    if entry is None:
        print(
            f"qwen.sh: no model {model!r} on {root}. Installed: {', '.join(sorted(entries)) or 'none'}",
            file=sys.stderr,
        )
        sys.exit(1)

    if entry.get("state") != "loaded":
        print(
            f"qwen.sh: {model} is not resident, LM Studio will load it first. Expect a slow first call.",
            file=sys.stderr,
        )
    return entry


entry = preflight(model)
ceiling = (entry or {}).get("max_context_length")

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
        limit = f"{ceiling}-token" if ceiling else "context"
        print(f"qwen.sh: payload over the {limit} ceiling, send fewer files", file=sys.stderr)
    sys.exit(1)
except (urllib.error.URLError, TimeoutError) as error:
    print(f"qwen.sh: cannot reach {root}: {error}", file=sys.stderr)
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
