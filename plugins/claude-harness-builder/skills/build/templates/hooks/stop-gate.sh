#!/usr/bin/env bash
# Stop + StopFailure — turn-end gate. ONE script for BOTH events, branching on
# hook_event_name. Prevents the self-grading failure mode (agent skips its own
# verification). Three Stop principles baked in:
#   1. stop_hook_active re-entry guard (removing it deadlocks the session)
#   2. StopFailure NEVER blocks (blocking a failed turn traps the session in a loop)
#   3. GATE_MODE=warn downgrade path (block becomes a warning)
set -euo pipefail

[[ "${HARNESS_DISABLE_STOP_GATE:-0}" == "1" ]] && exit 0
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
command -v jq >/dev/null 2>&1 || exit 0   # gate can't run without jq → warn-free pass

INPUT="$(cat)"
EVENT="$(echo "$INPUT" | jq -r '.hook_event_name // ""')"
STOP_ACTIVE="$(echo "$INPUT" | jq -r '.stop_hook_active // false')"

# 1) Re-entry guard (MANDATORY — do not remove)
[[ "$STOP_ACTIVE" == "true" ]] && { printf '{}\n'; exit 0; }

# Run the gate. {{GATE_COMMAND}} e.g.: npm test --silent / cargo test / make lint
if (cd "$PROJ_DIR" && {{GATE_COMMAND}}) >/dev/null 2>&1; then
  printf '{}\n'; exit 0
fi

MSG="Gate '{{GATE_NAME}}' failed ({{GATE_COMMAND}}). Fix the failures and verify before ending the turn."

# 2) StopFailure: warn only — never block a failed turn
if [[ "$EVENT" == "StopFailure" ]]; then
  jq -n --arg msg "$MSG" '{systemMessage: $msg}'
  exit 0
fi

# 3) Downgrade path: GATE_MODE=warn turns the block into a visible warning
if [[ "${GATE_MODE:-block}" == "warn" ]]; then
  jq -n --arg msg "$MSG" '{systemMessage: $msg}'
  exit 0
fi

# Stop: gate failed → block ending the turn
jq -n --arg reason "$MSG" '{decision: "block", reason: $reason}'

# Registration — BOTH events point at this one script:
# { "hooks": {
#   "Stop":        [ { "hooks": [ { "type": "command",
#     "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/stop-gate.sh", "timeout": 30 } ] } ],
#   "StopFailure": [ { "hooks": [ { "type": "command",
#     "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/stop-gate.sh", "timeout": 30 } ] } ]
# } }
