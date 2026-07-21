# Hooks Real-World Example Collection

These are hooks patterns validated in a real harness setup. Each example covers
"what it enforces/injects", "which output method it uses", and "pitfalls that are
easy to fall into".
(Source: plugin-bundled hooks from a production agentic-development harness)

## Per-event roles at a glance

| Event | Role | Can block? | Example |
|--------|------|:---:|------|
| `SessionStart` | Inject state at session start | No | Active mode, project memory, command catalog |
| `UserPromptSubmit` | Inspect/inject on every prompt | Yes | Keyword → slash command suggestion, budget warning |
| `PreToolUse` | Enforce policy **before** tool execution | Yes | Block secret file writes |
| `PostToolUse` | Record/feedback **after** tool success | No | Audit log (JSON-L) + mutating-call reminder |
| `Stop` | Prevent turn from ending | Yes | Block stopping when a phase gate has not passed |
| `StopFailure` | Notify on a failed turn | No (forbidden) | Warn only — blocking traps the session in a loop |

---

## Example 1: SessionStart — inject project state as context

When a session starts, read the project's state files and inject them via
`additionalContext`. The model starts every session knowing "the current active
mode, open incidents, and budget status".

```bash
#!/usr/bin/env bash
set -euo pipefail

# Kill switch — always provide a way to turn a harness hook off
[[ "${MY_DISABLE_HOOK:-0}" == "1" ]] && exit 0

# CLAUDE_PROJECT_DIR is injected by Claude Code. A fallback enables local testing too
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

CTX=""
if [[ -f "$PROJ_DIR/.state/active-mode" ]]; then
  CTX+="Active mode: $(cat "$PROJ_DIR/.state/active-mode")"$'\n'
fi

# Key point: file contents go into the context, so always use a real JSON encoder.
# Assembling JSON via shell string interpolation lets files containing quotes/newlines
# break the JSON, and a tampered state file could inject arbitrary keys.
jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
```

**Pitfall**: in CC 2.x, emitting only `{additionalContext: "..."}` is silently ignored.
Always wrap it in the form that includes `hookSpecificOutput.hookEventName`.

---

## Example 2: UserPromptSubmit — steer workflows with keyword triggers

Inspect every prompt, and when a keyword from a catalog (`triggers.json`) appears,
suggest the related slash command as context. Even if the user does not know the
command name, typing "run a release" leads the model to find and invoke
`/release-flow`.

```bash
#!/usr/bin/env bash
set -euo pipefail
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

INPUT=$(cat)                                   # stdin: {"prompt": "...", ...}
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' | tr '[:upper:]' '[:lower:]')

# Word-boundary matching — so "release" does not fire on "released" or "prerelease"
if echo "$PROMPT" | grep -qw "release"; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: "Trigger detected: release\nSuggested command: /release-flow\nInvoke this command for the user request."
    }
  }'
  exit 0
fi
exit 0   # No match → inject nothing
```

Applied pattern (a priority chain in the same hook, firing at most one):
1. Keyword trigger match → suggest a command
2. State file check (e.g., budget over 80%) → inject a warning
3. Config drift detection (overlay file mtime > settings.json mtime) → suggest reinstall

**Design principle**: this hook has no side effects (no file writes, no network). If
`jq` is missing, it just leaves a warning and passes through (graceful degradation) —
context injection is a convenience feature, not a safety mechanism, so fail-open is
the right choice.

---

## Example 3: PreToolUse — block dangerous operations with a declarative ruleset

Because it inspects **before** the tool runs, this is the only point where "real
enforcement" is possible. Denied calls never execute. Instead of hardcoding rules in
the script, split them into a JSON ruleset so policy changes require no code changes.

`hooks.json` registration (plugin bundle):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          { "type": "command",
            "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/enforce.py\"" }
        ]
      }
    ]
  }
}
```

Ruleset (`harness-rules.json`) — a three-piece set protecting secret files:

```json
{
  "rules": [
    { "id": "deny-secret-file-write",
      "tool": "Write",
      "deny_if": { "file_path_matches": "(^|/)\\.env(\\.|$)|(^|/)secrets?/|\\.pem$|(^|/)kubeconfig$" },
      "decision": "deny",
      "reason": "Writing secret files is blocked. Use a secrets manager." },
    { "id": "deny-secret-file-edit",
      "tool": "Edit",
      "deny_if": { "file_path_matches": "(^|/)\\.env(\\.|$)|(^|/)secrets?/|\\.pem$|(^|/)kubeconfig$" },
      "decision": "deny",
      "reason": "Editing secret files is blocked." },
    { "id": "deny-secret-file-shell-redirect",
      "tool": "Bash",
      "deny_if": { "command_matches": "(>>?|tee\\b|dd\\b|cp\\b|mv\\b)[^|;&]*(\\.env(\\.|\\b)|secrets?/|\\.pem\\b|kubeconfig\\b)" },
      "decision": "deny",
      "reason": "Writing secret files via shell redirects is blocked as well." }
  ]
}
```

> The third rule is the key one. Blocking only Write/Edit leaves a **shell bypass
> path** open, like `echo "KEY=x" > .env`. The same policy must always block every
> bypass path together.

The enforcer's verdict output:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Writing secret files is blocked."
  }
}
```

**Distinguishing fail-open vs fail-closed** (the core of safety-mechanism design):

| Situation | Verdict | Reason |
|------|------|------|
| Ruleset file does not exist at all | allow | Absence of policy ≠ absence of enforcement. Plugins that want enforcement ship a ruleset |
| Ruleset exists but fails to parse | **ask (fail-closed)** | Enforcement was intended but the mechanism is broken → must not silently allow |
| Depending on external binaries (OPA, etc.) | avoid | If the binary is missing, it silently fails open — fatal for a safety mechanism |

---

## Example 4: PostToolUse — audit log + mutating-call feedback

The tool has already run, so **blocking is impossible**. Instead, it is well suited
to two things:

1. **Audit trail**: append every tool call as JSON-L. Rather than "the agent
   remembering to record", the harness records automatically, making omissions
   structurally impossible.
2. **Selective feedback**: for mutating calls only, remind about follow-up actions
   via `additionalContext`.

```bash
#!/usr/bin/env bash
set -euo pipefail
INPUT="$(cat)"
TOOL="$(echo "$INPUT" | jq -r '.tool_name // ""')"
COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // ""')"
FILE="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')"

# Mutation classification — record which rule fired so it can be tuned later
CLASS="benign"; RULE=""
case "$TOOL" in
  Write|Edit|NotebookEdit) CLASS="mutating"; RULE="file-write" ;;
  Bash)
    if   [[ "$COMMAND" =~ kubectl[[:space:]]+(apply|delete|patch|scale) ]]; then CLASS="mutating"; RULE="kubectl-mutating"
    elif [[ "$COMMAND" =~ terraform[[:space:]]+(apply|destroy) ]];            then CLASS="mutating"; RULE="terraform-mutating"
    elif [[ "$COMMAND" =~ git[[:space:]]+(push|reset|clean|rebase) ]];        then CLASS="mutating"; RULE="git-mutating"
    fi ;;
esac

# Append the audit line (built with jq — tool input is externally influenced, so escaping is mandatory)
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
mkdir -p "$PROJ_DIR/.audit"
jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg tool "$TOOL" \
       --arg class "$CLASS" --arg rule "$RULE" --arg cmd "${COMMAND:0:512}" \
  '{ts:$ts, tool:$tool, classification:$class}
   + (if $rule != "" then {matched_rule:$rule} else {} end)
   + (if $cmd  != "" then {command_excerpt:$cmd} else {} end)' \
  >> "$PROJ_DIR/.audit/tool-events.jsonl"

# Inject feedback for mutating calls only
if [[ "$CLASS" == "mutating" ]]; then
  jq -n --arg ctx "[audit] Recorded state-mutating $TOOL call (rule: $RULE). Verify whether the related state files need updating." '{
    hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: $ctx }
  }'
else
  printf '{}\n'   # Valid no-op payload
fi
```

**Division of roles**: PostToolUse feedback is guidance only. Policies that need hard
blocking must live in PreToolUse (Example 3) — design the two hooks as a pair.

---

## Example 5: Stop / StopFailure — turn-end gate

Enforces "the turn cannot end until the gate passes". It is the mechanism that
prevents the **self-grading failure mode** where the agent that did the work skips
verification on its own. Register one script for both events and branch on
`hook_event_name`.

```bash
#!/usr/bin/env bash
set -euo pipefail
INPUT="$(cat)"
EVENT="$(echo "$INPUT" | jq -r '.hook_event_name // ""')"
STOP_ACTIVE="$(echo "$INPUT" | jq -r '.stop_hook_active // false')"

# 1) Re-entry guard (mandatory!) — blocking again in the turn re-run after a block causes deadlock
[[ "$STOP_ACTIVE" == "true" ]] && { printf '{}\n'; exit 0; }

# Check the gate verdict files (only trust the verdict recorded by the verification skill)
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
BLOCKED=$(jq -r 'select(.status == "blocked") | .phase' \
  "$PROJ_DIR"/.state/gates/*.json 2>/dev/null || true)
[[ -z "$BLOCKED" ]] && { printf '{}\n'; exit 0; }

# 2) Never block StopFailure — blocking a failed turn traps the session in a loop
if [[ "$EVENT" == "StopFailure" ]]; then
  jq -n --arg msg "Gate ($BLOCKED) is in blocked state. Resolve it and re-run verification." \
    '{systemMessage: $msg}'
  exit 0
fi

# 3) Stop: gate is blocked → block ending the turn
jq -n --arg reason "Cannot end the turn: gate ($BLOCKED) is in blocked state. Resolve the blocker and re-run verification." \
  '{decision: "block", reason: $reason}'
```

Registering both events:

```json
{
  "hooks": {
    "Stop":        [ { "hooks": [ { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/stop-gate.sh\"" } ] } ],
    "StopFailure": [ { "hooks": [ { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/stop-gate.sh\"" } ] } ]
  }
}
```

**The three Stop-hook principles**:
1. Never ship without the `stop_hook_active` re-entry guard (deadlock).
2. StopFailure warns only — blocking is forbidden.
3. Provide a downgrade path (e.g., a `GATE_MODE=warn` env var switching block → systemMessage).

---

## Pitfall: plugin hooks.json must be wrapped in a top-level "hooks" key

Starting with CC 2.1.x, putting event names at the top level of a plugin's
`hooks/hooks.json` makes loading **fail silently** with
`"Failed to load hooks ... expected record, received undefined"`. It must be wrapped
in a `"hooks"` key, same as settings.json.

```json
// ❌ Fails to load (old format)
{ "SessionStart": [ ... ], "PreToolUse": [ ... ] }

// ✅ CC 2.x format
{ "hooks": { "SessionStart": [ ... ], "PreToolUse": [ ... ] } }
```

If a hook does not fire and no error appears, suspect this format first.

---

## Common design principles (patterns repeated across every example)

1. **Always encode JSON with jq/python** — values a hook handles (file contents,
   commands, tool input) are externally influenced, so assembling JSON via shell
   interpolation breaks or gets injected.
2. **Kill-switch env var** — give every hook an `X_DISABLE_*=1` escape hatch.
3. **`CLAUDE_PROJECT_DIR` + `$PWD` fallback** — a hook's cwd is not guaranteed.
   Route all paths through this variable. Plugin-bundled scripts use `${CLAUDE_PLUGIN_ROOT}`.
4. **Decide fail-open/fail-closed deliberately** — convenience features (context
   injection) are fail-open; safety mechanisms (policy enforcement) are fail-closed.
   Always specify the behavior when a dependency (jq) is missing.
5. **Self-contained scripts** — hooks distributed via a plugin must not depend on
   other files in the repo root. They must work as-is from the installed copy.
6. **Divide blocking and guidance** — enforcement in PreToolUse/Stop, recording and
   feedback in PostToolUse, injection in SessionStart/UserPromptSubmit. Design one
   policy across multiple events (e.g., PreToolUse blocks, PostToolUse records,
   Stop verifies).
