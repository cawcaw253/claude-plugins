# Phase 4 — Hooks (Step 4/6)

The core phase. Two stages: (A) one checkbox call selecting events, (B) a
step-by-step loop over the selected events. Read
`references/hooks-catalog.md` for per-event content and
`references/artifact-rules.md` before generating any script.

## Stage A — Hook selection (ONE AskUserQuestion call, TWO multiSelect questions)

Both questions in the SAME call, so the user sees one checkbox page. No
previews (multiSelect); descriptions carry the explanation. Do NOT add an
"Other" option.

**Question 1** — "Loop hooks — fire on every tool call inside the agentic
loop. Which do you want?" — header `Loop hooks`, multiSelect: true.

| # | Label | Description |
|---|-------|-------------|
| 1 | PreToolUse (Recommended) | Inspect/block a tool call before it runs. The core guard: protect secrets, block destructive bash. Can hard-block. |
| 2 | PostToolUse (Recommended) | React after a tool ran: audit-log edits, formatter/linter feedback. Cannot undo, can flag. |
| 3 | UserPromptSubmit | Runs on every prompt you send: inject context or trigger suggestions on keywords. Can block a prompt. |
| 4 | PermissionRequest | Fires when Claude asks permission: auto-approve known-safe patterns or force-deny known-bad ones. |

**Question 2** — "Session & turn hooks — fire at session/turn boundaries.
Which do you want?" — header `Turn hooks`, multiSelect: true.

| # | Label | Description |
|---|-------|-------------|
| 1 | SessionStart | Injects context when a session starts: git status, project state, environment warnings. Cannot block. |
| 2 | Stop + StopFailure gate | When Claude thinks it is done, verify (tests pass?) and send it back if not. StopFailure only warns, never blocks. |
| 3 | SessionEnd | Cleanup when the session closes: flush audit summary, remove temp files. Cannot block. |

Nothing selected in both → "Skipping hooks — nothing selected.", mark phase
complete, continue to Phase 5.

## Stage B — Per-hook loop

Walk selected hooks in loop order:
**SessionStart → UserPromptSubmit → PermissionRequest → PreToolUse →
PostToolUse → Stop → SessionEnd.**

Progress header for every message:
`**🔧 Harness Builder — Step 4/6: Hooks (hook <k>/<n>: <event>)**`.

For EACH hook:

1. **Explain** — from `hooks-catalog.md`: when it fires, whether it can
   block, its harness role, and the worked-example commentary.
2. **Policy question** — ONE single-select AskUserQuestion with the event's
   2–3 canned policies from the catalog. **Each option's `preview` shows the
   actual script excerpt that would be installed** (single-select, so
   previews are legal — this is where the user compares real code). The UI's
   automatic "Other" covers free-text policies; handle those per
   `artifact-rules.md` §Substitution.
3. **Generate** — copy the event's template from `templates/hooks/`,
   substitute `{{PLACEHOLDER}}` values for the chosen policy. Never touch the
   fixed scaffolding (kill switch, guards, jq-only output).
4. **Confirm** — show the full script, the target path
   (`.claude/hooks/<name>.sh`), and the settings.json registration snippet.
   Single-select: "Apply (Recommended)" (preview = registration snippet) /
   "Edit first" / "Skip".
5. **Apply** — Write the script (and companion files like
   `pretooluse-rules.json`), `chmod +x`, verify with `ls -l`, merge the
   registration into the settings file's `hooks` block (same merge discipline
   as Phase 2: append matcher groups, never remove existing ones). For
   enforcement hooks, also propose the paired `permissions.deny` entry if
   Phase 2 didn't already add it. If CLAUDE.md has a "Harness notes" section,
   append the pairing line.
6. **Advance** — update state (`selectedHooks[k].done = true`, extend
   `appliedFiles`), announce
   `hook <k>/<n> done — next: <event>`, continue.

## Registration reference

Always wrapped in the top-level `"hooks"` key of the settings file; command
paths use `${CLAUDE_PROJECT_DIR}`, quoted:

```json
{ "hooks": { "PreToolUse": [ { "matcher": "Bash|Edit|Write",
  "hooks": [ { "type": "command",
    "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/pretooluse-guard.sh",
    "timeout": 10 } ] } ] } }
```

Matchers per event: SessionStart / UserPromptSubmit / Stop / StopFailure /
SessionEnd → omit `matcher` (fires on all); PreToolUse guard →
`Bash|Edit|Write` (widen to include `Read` if the policy protects reads);
PostToolUse audit → `*`; PermissionRequest → the tool the policy targets.
Stop and StopFailure both register `stop-gate.sh` (one script branching on
`hook_event_name`).

Timeouts: 10s for guards/injectors, 30s for the Stop gate (it may run tests).
