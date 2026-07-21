#!/usr/bin/env bash
# UserPromptSubmit — keyword trigger / context injection (convenience hook: fail-open).
# Exit codes: 0 = success; 2 = block the prompt (only the banned-word variant uses it).
set -euo pipefail

[[ "${HARNESS_DISABLE_PROMPT_TRIGGER:-0}" == "1" ]] && exit 0
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
command -v jq >/dev/null 2>&1 || exit 0   # fail-open

INPUT=$(cat)   # stdin: {"prompt": "...", ...}
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' | tr '[:upper:]' '[:lower:]')

# Word-boundary match — "{{TRIGGER_WORD}}" must not fire on substrings
# (e.g. "release" must not match "released" or "prerelease").
if echo "$PROMPT" | grep -qw "{{TRIGGER_WORD}}"; then
  jq -n --arg ctx "{{INJECTED_CONTEXT}}" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $ctx
    }
  }'
  exit 0
fi

# Banned-word variant (replaces the block above):
# if echo "$PROMPT" | grep -qwE "{{BANNED_WORDS}}"; then
#   jq -n '{decision: "block", reason: "This prompt matches a banned term. Rephrase it."}'
#   exit 0
# fi

exit 0   # no match → inject nothing. This hook has no side effects.

# Registration:
# { "hooks": { "UserPromptSubmit": [ { "hooks": [ { "type": "command",
#   "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/prompt-keyword-trigger.sh",
#   "timeout": 10 } ] } ] } }
