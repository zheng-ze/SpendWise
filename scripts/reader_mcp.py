#!/usr/bin/env python3
"""MCP server wrapping scripts/gemini.sh and scripts/qwen.sh as callable tools.

Runs over stdio. Each tool call shells out to the existing script unchanged, so the
quota/context rules documented in those scripts' own headers still apply — this file only
gives them a tool name an MCP client can call directly instead of going through Bash.
"""

import os
import subprocess
from pathlib import Path

from mcp.server.fastmcp import FastMCP

REPO_ROOT = Path(__file__).resolve().parent.parent
GEMINI_SCRIPT = REPO_ROOT / "scripts" / "gemini.sh"
QWEN_SCRIPT = REPO_ROOT / "scripts" / "qwen.sh"
DEFAULT_QWEN_MODEL = "qwen2.5.1-coder-7b-instruct"

mcp = FastMCP("reader-models")


@mcp.tool()
def ask_gemini(question: str) -> str:
    """Ask Gemini one broad question about this repository.

    Gemini is agentic and reaches its own files via its own shell/read/grep tools, so send one
    broad question rather than a pre-narrowed file list, and merge separable questions into a
    single call with numbered sections instead of calling this more than once.
    """
    result = subprocess.run(
        [str(GEMINI_SCRIPT), question],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=600,
    )
    if result.returncode != 0:
        return f"gemini.sh failed (exit {result.returncode}):\n{result.stderr}"
    return result.stdout + (f"\n\n[stderr]\n{result.stderr}" if result.stderr else "")


@mcp.tool()
def ask_qwen(
    question: str,
    files: list[str],
    model: str = DEFAULT_QWEN_MODEL,
) -> str:
    """Ask a local Qwen2.5-Coder instance a question about one or more files.

    Pass model to pick a different LM Studio model id than the default
    (qwen2.5.1-coder-7b-instruct) — needed whenever the default is not the one loaded on the
    host. A failed call's error message lists every model id actually installed there; retry
    with one of those in model rather than guessing.

    Ask about one symbol per call: sending several questions in one call places them worse than
    calling once per question. Paths are relative to the repository root.
    """
    resolved = [str(REPO_ROOT / f) for f in files]
    env = {**os.environ, "SUBAGENT_MODEL": model}
    result = subprocess.run(
        [str(QWEN_SCRIPT), question, *resolved],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=900,
        env=env,
    )
    if result.returncode != 0:
        return f"qwen.sh failed (exit {result.returncode}):\n{result.stderr}"
    return result.stdout + (f"\n\n[stderr]\n{result.stderr}" if result.stderr else "")


if __name__ == "__main__":
    mcp.run(transport="stdio")
