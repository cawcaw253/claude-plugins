# Hooks Catalog — 7 events in agentic-loop order

For each event: when it fires, whether it can block, harness role, canned
policies (these become the Stage B single-select options; previews = script
excerpts from the template), a safe test for Phase 6, and pitfalls.

Output contract shared by all events: exit 0 = success (stdout parsed as
JSON), exit 2 = block (stderr fed to Claude; not honored by non-blocking
events), other = non-blocking error. JSON alternatives: PreToolUse uses
`hookSpecificOutput.permissionDecision` (allow/deny/ask), blocking events use
top-level `{"decision": "block", "reason": ...}`, context injection uses
`hookSpecificOutput.additionalContext` — which CC 2.x silently ignores unless
wrapped with the matching `hookSpecificOutput.hookEventName`.

---

## 1. SessionStart

- **Fires:** session start/resume. **Blocks:** no (context only).
- **Role:** start every session with project state the model would otherwise
  have to rediscover: branch, dirty files, open TODOs.
- **Template:** `session-start-context.sh`. Placeholder: `{{STATE_SOURCES}}`.
- **Canned policies:**
  - (a) **Git & project status injection (Recommended)** — branch, dirty file
    count, last 3 commits.
  - (b) **Project state file injection** — cat `.claude/state/*` or TODO.md
    into context.
  - (c) **Environment warnings** — node/python version vs lockfile
    expectations.
- **Safe test:** start a new session, ask "what branch are we on?" — the
  answer should come without running git.
- **Pitfall:** bare `{additionalContext: ...}` is silently ignored — must be
  wrapped in `hookSpecificOutput` with `hookEventName: "SessionStart"`.

## 2. UserPromptSubmit

- **Fires:** every user prompt, before Claude sees it. **Blocks:** yes
  (exit 2 or `decision: block` rejects the prompt).
- **Role:** keyword → workflow steering, banned-word filter, per-prompt
  context injection.
- **Template:** `prompt-keyword-trigger.sh`. Placeholders: `{{TRIGGER_WORD}}`,
  `{{INJECTED_CONTEXT}}`.
- **Canned policies:**
  - (a) **Keyword → command suggestion (Recommended)** — word-boundary match
    (so "release" doesn't fire on "released"); inject "invoke /release-flow".
  - (b) **Banned-word blocker** — `decision: block` on configured terms.
  - (c) **Topic context injection** — keyword adds a checklist/warning.
- **Safe test:** send a prompt containing the trigger word — the response
  should reference the injected context.
- **Pitfall:** convenience feature → fail-open (jq missing → exit 0). No side
  effects (no file writes, no network) in this hook.

## 3. PermissionRequest

- **Fires:** when the permission dialog would appear. **Blocks:** yes
  (`permissionDecision` allow/deny replaces the dialog).
- **Role:** auto-approve known-safe patterns, auto-deny known-bad ones,
  without a manual prompt each time.
- **Template:** none — generate inline from the `pretooluse-guard.sh`
  scaffolding (same stdin parse, same jq decision output, event name
  `PermissionRequest`).
- **Canned policies:**
  - (a) **Auto-approve read-only git** — status/diff/log.
  - (b) **Auto-deny raw network fetch** — curl/wget (pair with the
    ask-before-network preset).
- **Safe test:** trigger a matching permission request — the dialog should
  not appear (auto-approve) or should be denied with the reason shown.
- **Pitfall:** prefer `permissions.allow`/`deny` rules when a static pattern
  suffices — use this hook only for conditions permissions can't express
  (branch-dependent, time-dependent, argument-inspection logic).

## 4. PreToolUse ✅ recommended default

- **Fires:** before every tool call. **Blocks:** YES — the only point where
  a call can be stopped before it executes.
- **Role:** THE enforcement point: protect secret files, block destructive
  commands, protect generated files.
- **Template:** `pretooluse-guard.sh` + `pretooluse-rules.json` (declarative
  ruleset — policy changes need no script edits). Placeholder: `{{RULES}}`.
- **Canned policies:**
  - (a) **Protect secret files (Recommended)** — deny Read/Edit/Write on
    `.env*`, `secrets/`, `*.pem`, kubeconfig, AND the Bash bypass paths
    (redirects, tee, cp, mv, cat). Pairs with the deny-secrets preset.
  - (b) **Block destructive git/bash** — `rm -rf`, force-push,
    `reset --hard`, `clean -fd`.
  - (c) **Protect generated files** — `build/`, `dist/`, `*.generated.*` →
    "edit the source template instead".
- **Safe test:** ask Claude to `cat .env` — expect a deny message, not file
  contents.
- **Pitfall:** blocking only Write/Edit leaves the shell bypass open
  (`echo "KEY=x" > .env`) — every file rule ships its companion Bash rule.
  Enforcement hook → fail-closed: unparsable ruleset or missing jq → `ask`,
  never silent allow. Ruleset file absent entirely → allow (absence of
  policy ≠ broken mechanism).

## 5. PostToolUse ✅ recommended default

- **Fires:** after a tool succeeds. **Blocks:** no — the call already ran.
- **Role:** audit trail the agent cannot forget to write; selective feedback
  after mutating calls.
- **Template:** `posttooluse-audit.sh`. Placeholders: `{{MUTATING_PATTERNS}}`,
  `{{AUDIT_PATH}}`.
- **Canned policies:**
  - (a) **Audit log (Recommended)** — every call classified benign/mutating,
    appended as JSONL to `.claude/audit/tool-events.jsonl`.
  - (b) **Auto-format on edit** — run the project formatter on the edited
    file; never blocking.
  - (c) **Mutating-call reminder** — `additionalContext` nudge after
    kubectl/terraform/git mutations.
- **Safe test:** have Claude edit any file, then check the audit file gained
  a line.
- **Pitfall:** guidance only — the blocking half of the same policy lives in
  PreToolUse. Design the two as a pair.

## 6. Stop + StopFailure

- **Fires:** Stop when Claude finishes a turn; StopFailure when a turn fails.
  **Blocks:** Stop yes (`decision: block` sends Claude back to work);
  StopFailure NEVER (blocking a failed turn traps the session in a loop).
- **Role:** completion gate — prevents the self-grading failure mode where
  the agent that did the work skips verification.
- **Template:** `stop-gate.sh` — ONE script registered for BOTH events,
  branching on `hook_event_name`. Placeholders: `{{GATE_COMMAND}}`,
  `{{GATE_NAME}}`.
- **Canned policies:**
  - (a) **Tests must pass (Recommended)** — run the test command; block stop
    on failure.
  - (b) **Lint must be clean** — same shape, lint command.
  - (c) **Checklist reminder only** — `systemMessage` warn, never blocks.
- **Safe test:** end a turn with a failing check present — Claude should be
  sent back once, and must NOT loop (the `stop_hook_active` guard exits on
  re-entry).
- **Pitfalls (three Stop principles):** (1) never ship without the
  `stop_hook_active` re-entry guard — deadlock; (2) StopFailure warns only;
  (3) provide a downgrade path (`GATE_MODE=warn` env var → block becomes
  systemMessage).

## 7. SessionEnd

- **Fires:** session closes. **Blocks:** no.
- **Role:** cleanup and closure: flush an audit summary line, remove temp
  files.
- **Template:** none — generate inline from `session-start-context.sh`
  scaffolding (event name `SessionEnd`; output usually a plain no-op `{}`
  after side effects).
- **Canned policies:**
  - (a) **Flush audit summary** — append a session-summary line to the audit
    log.
  - (b) **Temp cleanup** — remove `.claude/tmp/*` scratch files.
- **Safe test:** end a session, check the audit file's last line is a
  summary record.
- **Pitfall:** keep it fast and fail-open — a broken cleanup hook must never
  make closing a session painful.
