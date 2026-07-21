#!/usr/bin/env bash
# PostToolUse — audit log + mutating-call feedback (convenience hook: fail-open).
# The tool already ran: this hook records and nudges, it cannot block.
# The blocking half of the same policy belongs in PreToolUse — design as a pair.
set -euo pipefail

[[ "${HARNESS_DISABLE_POSTTOOLUSE_AUDIT:-0}" == "1" ]] && exit 0
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
command -v jq >/dev/null 2>&1 || exit 0   # fail-open

INPUT="$(cat)"
TOOL="$(echo "$INPUT" | jq -r '.tool_name // ""')"
COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // ""')"

# Mutation classification — record which rule fired so the ruleset can be tuned
CLASS="benign"; RULE=""
case "$TOOL" in
  Write|Edit|NotebookEdit) CLASS="mutating"; RULE="file-write" ;;
  Bash)
    # {{MUTATING_PATTERNS}} — one elif per pattern the policy tracks, e.g.:
    if   [[ "$COMMAND" =~ git[[:space:]]+(push|reset|clean|rebase) ]]; then CLASS="mutating"; RULE="git-mutating"
    elif [[ "$COMMAND" =~ kubectl[[:space:]]+(apply|delete|patch|scale) ]]; then CLASS="mutating"; RULE="kubectl-mutating"
    fi ;;
esac

AUDIT_DIR="$PROJ_DIR/{{AUDIT_PATH}}"   # e.g. .claude/audit
mkdir -p "$AUDIT_DIR"
# Audit line via jq — tool input is externally influenced, escaping is mandatory
jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg tool "$TOOL" \
       --arg class "$CLASS" --arg rule "$RULE" --arg cmd "${COMMAND:0:512}" \
  '{ts:$ts, tool:$tool, classification:$class}
   + (if $rule != "" then {matched_rule:$rule} else {} end)
   + (if $cmd  != "" then {command_excerpt:$cmd} else {} end)' \
  >> "$AUDIT_DIR/tool-events.jsonl"

if [[ "$CLASS" == "mutating" ]]; then
  jq -n --arg ctx "[audit] Recorded state-mutating $TOOL call (rule: $RULE). Verify whether related state/docs need updating." '{
    hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: $ctx }
  }'
else
  printf '{}\n'   # valid no-op payload
fi

# Registration:
# { "hooks": { "PostToolUse": [ { "matcher": "*", "hooks": [ { "type": "command",
#   "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/posttooluse-audit.sh",
#   "timeout": 10 } ] } ] } }
