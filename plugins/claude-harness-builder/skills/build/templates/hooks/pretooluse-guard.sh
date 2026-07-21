#!/usr/bin/env bash
# PreToolUse — declarative ruleset guard (ENFORCEMENT hook: fail-closed).
# Denied calls never execute. Rules live in pretooluse-rules.json next to this
# script — policy changes need no script edits.
# Exit codes: 0 = verdict on stdout as JSON. exit 1 would NOT block (never rely on it).
set -euo pipefail

[[ "${HARNESS_DISABLE_PRETOOLUSE_GUARD:-0}" == "1" ]] && exit 0
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
RULES="$PROJ_DIR/.claude/hooks/pretooluse-rules.json"

ask() {  # fail-closed verdict: enforcement intended but mechanism broken
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

# Enforcement + jq missing → fail-closed (a guard that silently passes is a hole)
command -v jq >/dev/null 2>&1 || ask "pretooluse-guard: jq not found — install jq or remove this hook"

# Ruleset absent → allow (absence of policy is not a broken mechanism)
[[ -f "$RULES" ]] || exit 0
# Ruleset present but unparsable → fail-closed
jq empty "$RULES" 2>/dev/null || ask "pretooluse-guard: pretooluse-rules.json is invalid JSON — fix or remove it"

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
# Both the file path (Read/Edit/Write) and the command (Bash) are inspected
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.command // ""')

while IFS=$'\t' read -r rule_tool pattern reason; do
  [[ "$TOOL" == "$rule_tool" ]] || continue
  if echo "$TARGET" | grep -qE "$pattern"; then
    jq -n --arg r "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $r
      }
    }'
    exit 0
  fi
done < <(jq -r '.rules[] | [.tool, .pattern, .reason] | @tsv' "$RULES")

exit 0

# Registration (widen matcher to include Read if the ruleset protects reads):
# { "hooks": { "PreToolUse": [ { "matcher": "Bash|Edit|Write",
#   "hooks": [ { "type": "command",
#     "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/pretooluse-guard.sh",
#     "timeout": 10 } ] } ] } }
#
# Pair every red line here with a permissions.deny entry — hook matching is
# best-effort; deny is the wall.
