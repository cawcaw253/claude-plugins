---
name: harness-hooks
description: >-
  Helps configure a harness that constrains AI work scope using Claude Code hooks.
  Guides hook lifecycle events, matcher/if condition setup, exit code and JSON output
  control, and the settings.json schema, and writes actual hook scripts. Use when the
  user asks for things like "block a specific command with a hook", "run a hook only
  when a specific file is modified", "validate before commit/push", "hook lifecycle",
  or "harness restrictions".
---

# Harness Hooks Configuration Guide

Configure a harness that constrains AI work scope using Claude Code **hooks**.
Official docs: https://code.claude.com/docs/en/hooks

Hooks run scripts at specific points in the session flow to **inspect, block, or modify**
tool calls. Use them to enforce conditional policies in code that are hard to express
with permissions (specific subcommands, specific file extensions, branch conditions, etc.).

> **Prerequisite skills:** Intervention points (loop stages and tools) are covered by the
> `agentic-loop` skill, and where to place policies (user/project/local) is covered by the
> `settings-scopes` skill. This skill builds on those and covers *how to enforce* policies.

---

## Step 1: Decide when to intervene (lifecycle events)

Hooks fire on three cadences.

- **Once per session:** `SessionStart`, `SessionEnd`
- **Once per turn:** `UserPromptSubmit`, `Stop`, `StopFailure`
- **On every tool call:** `PreToolUse`, `PostToolUse`

The events most often used for a harness (work-scope restriction):

| Event | When it fires | Block with exit 2? | Primary use |
|--------|-----------|:--------------:|---------|
| `PreToolUse` | **Before** tool execution | Yes (blocks the tool) | Block dangerous commands/file edits |
| `PostToolUse` | **After** tool success | No (stderr fed back to Claude) | Formatting, post-validation, feedback |
| `UserPromptSubmit` | On prompt submission | Yes (blocks the prompt) | Banned-word filter, context injection |
| `PermissionRequest` | When the permission dialog appears | Yes (denies permission) | Auto approve/deny policies |
| `Stop` | When Claude finishes responding | Yes (prevents stopping) | "Do not stop until tests pass" |
| `SessionStart` | On session start/resume | No (context only) | Inject branch/issue info |

> For the full event list, see the "Hook Lifecycle Events" table in the docs:
> https://code.claude.com/docs/en/hooks

---

## Step 2: Narrow the target (matcher + if)

Narrow the hook's execution target in two stages.

### matcher — filter by tool name

| matcher value | Interpretation | Example |
|------------|------|------|
| `"*"`, `""`, omitted | Match everything | All tools |
| Only letters/digits/`_`/`-`/spaces/`,`/`\|` | Exact string or list | `Bash`, `Edit\|Write` |
| Any other characters | JavaScript regex (unanchored) | `^Notebook`, `mcp__memory__.*` |

- Regexes match **partially**. `Edit.*` matches both `Edit` and `NotebookEdit`.
  For an exact match, use anchors like `^Edit$`.
- MCP tools use the `mcp__<server>__<tool>` format. Example: `mcp__memory__.*` (`.*` required).

### if — also filter by tool arguments (the key piece)

The `if` field uses **permission rule syntax** to check the tool name plus its arguments.
It is only evaluated on `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, and `PermissionDenied`.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git push *)",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/check-push.sh"
          }
        ]
      }
    ]
  }
}
```

- `"Bash(git *)"` — run only for `git` subcommands
- `"Edit(*.ts)"` — run only when editing TypeScript files
- Put **exactly one** rule in `if` (no `&&`/`||`). For multiple conditions, split into separate handlers.
- Bash `if` strips leading `VAR=value` assignments and also inspects subcommands inside `$()` and backticks.
- `if` is best-effort (passes through on parse failure). **For hard blocking, pair it with permissions.**

This is how you "run a hook only for a subset of requests to a specific command using If".

---

## Step 3: Read the input (stdin JSON)

Hooks receive JSON on stdin. Some common fields:

| Field | Description |
|------|------|
| `session_id` | Session identifier |
| `cwd` | Current working directory |
| `permission_mode` | `default`/`plan`/`acceptEdits`/`auto`/`bypassPermissions`, etc. |
| `hook_event_name` | Name of the event that fired |
| `tool_name` | (Tool events) Tool name |
| `tool_input` | (Tool events) Tool argument object |

Key `tool_input` fields (PreToolUse):

- **Bash:** `command`, `description`, `timeout`, `run_in_background`
- **Write:** `file_path`, `content`
- **Edit:** `file_path`, `old_string`, `new_string`, `replace_all`
- **Read:** `file_path`, `offset`, `limit`

Extracting with `jq` in a script:

```bash
command=$(jq -r '.tool_input.command' < /dev/stdin)
file=$(jq -r '.tool_input.file_path' < /dev/stdin)
```

---

## Step 4: Return a result (exit code or JSON)

**Use either the exit-code approach or the JSON approach in a single hook, not both**
(JSON is ignored when exiting with code 2).

### Method A — exit codes (simple, recommended starting point)

| Exit code | Meaning |
|:---------:|------|
| `0` | Success. stdout is parsed as JSON output |
| `2` | **Block**. stdout is ignored, **stderr is passed to Claude as an error** |
| Other | Non-blocking error. Execution continues, only the first line of stderr is shown |

> Caution: `exit 1` is non-blocking. Policy enforcement must use `exit 2`.

```bash
#!/usr/bin/env bash
command=$(jq -r '.tool_input.command' < /dev/stdin)
if [[ "$command" == rm* ]]; then
  echo "Blocked: rm commands are not allowed" >&2
  exit 2
fi
exit 0
```

### Method B — JSON output (fine-grained control)

**Common fields (all events):**

| Field | Description |
|------|------|
| `continue` | If `false`, halts Claude entirely (takes precedence over event-specific decisions) |
| `stopReason` | Shown to the user when `continue:false` |
| `systemMessage` | Shows a warning to the user |
| `suppressOutput` | Hides stdout from debug logs |

**PreToolUse only — permissionDecision:**

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Database writes are not allowed"
  }
}
```

`permissionDecision`: `allow` / `deny` / `ask` / `defer`.
You can also rewrite the tool input with `updatedInput`.

**Top-level decision — block (UserPromptSubmit, PostToolUse, Stop, etc.):**

```json
{ "decision": "block", "reason": "Proceed after the tests pass" }
```

**Context injection (not blocking) — additionalContext:**

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "This file is auto-generated. Edit src/schema.ts instead."
  }
}
```

---

## Step 5: Register and verify

Register hooks in a settings file (per-scope locations):

| Location | Scope | Shared |
|------|------|------|
| `~/.claude/settings.json` | All projects | No (my machine) |
| `.claude/settings.json` | Single project | Yes (committed) |
| `.claude/settings.local.json` | Single project | No (gitignored) |
| Managed policy | Whole organization | Yes (admin-enforced) |

- Path placeholders: use `${CLAUDE_PROJECT_DIR}` for scripts in the project's `.claude/hooks/`,
  and `${CLAUDE_PLUGIN_ROOT}` when distributing via a plugin.
- Make scripts executable: `chmod +x`.
- Inspect registered hooks with the `/hooks` command (read-only).
- Temporarily disable everything: `"disableAllHooks": true`.

---

## Handler types

Besides `command`, the following exist (all support the common `type`, `if`, `timeout`, `once`):

- **`command`** — shell command (stdin JSON, result via exit code/stdout)
- **`http`** — POST JSON to a URL
- **`mcp_tool`** — invoke an MCP server tool
- **`prompt`** — single-turn prompt to a Claude model (yes/no decision)
- **`agent`** — spawn a subagent (experimental)

Specifying `args` switches to **exec form** (runs without a shell), avoiding shell
tokenization and injection:

```json
{ "type": "command", "command": "node", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/lint.js"] }
```

---

## Harness recipes (frequently used patterns)

1. **Block only a specific subcommand** — `matcher: "Bash"` + `if: "Bash(git push *)"` + PreToolUse exit 2
2. **Validate edits to specific extensions** — `matcher: "Edit|Write"` + `if: "Edit(*.ts)"` + lint script
3. **Protect auto-generated files** — check the path in PreToolUse, then `permissionDecision: "deny"`
4. **Auto-format after commit/save** — PostToolUse + `if: "Edit(*)"` (not blocking, format only)
5. **Prevent stopping before tests pass** — Stop event + `decision: "block"`
6. **Inject branch info at session start** — SessionStart + `additionalContext`
7. **Prompt banned-word filter** — UserPromptSubmit + `decision: "block"`

> `if` is fail-open, so pair absolute red lines with `deny` in permissions.

**Real-world examples**: for complete per-event scripts validated in a real production
harness (SessionStart state injection, UserPromptSubmit keyword triggers, a PreToolUse
ruleset enforcer, PostToolUse audit logging, Stop/StopFailure gates, and the plugin
hooks.json format pitfall), read this skill's [examples.md](examples.md).

---

## Reference links

- Official hooks docs: https://code.claude.com/docs/en/hooks
- Plugin/marketplace docs: https://code.claude.com/docs/en/plugins ,
  https://code.claude.com/docs/en/plugin-marketplaces
- Related skills: foundations `agentic-loop` and `settings-scopes`, extension layers
  `project-rules` (rules are not enforcement → enforce with hooks), `slash-commands`,
  `workflows`, `agent-memory`
