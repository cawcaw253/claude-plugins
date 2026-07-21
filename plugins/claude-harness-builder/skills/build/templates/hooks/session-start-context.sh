#!/usr/bin/env bash
# SessionStart — inject project state as context (convenience hook: fail-open).
# Exit codes: 0 = success (stdout parsed as JSON). This hook cannot block.
set -euo pipefail

# Kill switch — always provide a way to turn a harness hook off
[[ "${HARNESS_DISABLE_SESSION_START:-0}" == "1" ]] && exit 0

# cwd is not guaranteed; route all paths through PROJ_DIR
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Fail-open: context injection is convenience, not safety
command -v jq >/dev/null 2>&1 || exit 0

CTX=""
# {{STATE_SOURCES}} — one block per source the policy gathers, e.g.:
# CTX+="Branch: $(git -C "$PROJ_DIR" branch --show-current 2>/dev/null)"$'\n'
# CTX+="Dirty files: $(git -C "$PROJ_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"$'\n'
# CTX+="Recent commits:"$'\n'"$(git -C "$PROJ_DIR" log --oneline -3 2>/dev/null)"$'\n'

[[ -z "$CTX" ]] && { printf '{}\n'; exit 0; }

# Always assemble JSON with jq — file contents can contain quotes/newlines.
# CC 2.x ignores bare additionalContext; the hookSpecificOutput wrapper is required.
jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'

# Registration (merge into the settings file chosen in Phase 1):
# { "hooks": { "SessionStart": [ { "hooks": [ { "type": "command",
#   "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/session-start-context.sh",
#   "timeout": 10 } ] } ] } }
