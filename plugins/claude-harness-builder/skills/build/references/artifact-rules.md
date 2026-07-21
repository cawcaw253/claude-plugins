# Artifact Generation Rules

Every generated hook script must satisfy ALL rules below. When substituting a
user's free-text policy, fill placeholders only — this scaffolding is never
removed.

> Maintenance note: this file distills the hook patterns validated in
> `harness-plugin`'s `skills/harness-hooks/examples.md`. When that knowledge
> changes (new event, new pitfall), update this file in the same commit.

## The 12 rules

1. **jq-only JSON assembly.** Tool input, file contents, and commands are
   externally influenced. Assembling JSON via shell string interpolation
   breaks on quotes/newlines and enables injection. Always `jq -n --arg`.
2. **Kill switch.** Every script starts with
   `[[ "${HARNESS_DISABLE_<HOOKNAME>:-0}" == "1" ]] && exit 0`
   (e.g. `HARNESS_DISABLE_PRETOOLUSE_GUARD`). Phase 6 lists all installed
   switches.
3. **Path resolution.** `PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"` — a hook's
   cwd is not guaranteed. All project paths route through `$PROJ_DIR`.
4. **Stop re-entry guard.** `stop_hook_active == true` on stdin → emit `{}`
   and exit 0 immediately. Blocking again in the re-run turn deadlocks the
   session. The wizard refuses to generate a Stop hook without this guard.
5. **StopFailure never blocks.** One script serves Stop and StopFailure,
   branching on `hook_event_name`; the StopFailure path may only emit
   `systemMessage`.
6. **Fail-open vs fail-closed.**

   | Hook class | Events | Missing dep (jq) / broken config |
   |---|---|---|
   | Convenience | SessionStart, UserPromptSubmit, PostToolUse, SessionEnd | `exit 0` — never block work over a missing tool |
   | Enforcement | PreToolUse guard, PermissionRequest denier | ruleset unparsable or jq missing → `permissionDecision: "ask"` with a reason (enforcement was intended; the mechanism is broken → must not silently allow) |

   Ruleset file absent entirely → allow: absence of policy ≠ broken
   mechanism. Avoid depending on external binaries beyond bash+jq+git — a
   missing binary silently fails open, fatal for a safety mechanism.
7. **Multi-event pairing.** One policy spans layers:
   `permissions.deny` (wall) + PreToolUse (block) + PostToolUse (record) +
   Stop (verify). State which pairing each generated hook belongs to and
   cross-link it in CLAUDE.md's "Harness notes".
8. **Shell-bypass coverage.** Any file-protection rule on Write/Edit MUST
   ship the companion Bash rule (redirects `>`/`>>`, `tee`, `dd`, `cp`, `mv`,
   `cat`) in the same ruleset. Blocking only Write/Edit leaves
   `echo "KEY=x" > .env` open.
9. **Registration schema.** Always wrapped in the top-level `"hooks"` key;
   command paths quoted: `"\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/<name>.sh"`;
   `timeout` set (10s guards/injectors, 30s Stop gate). Never register
   generated artifacts via `${CLAUDE_PLUGIN_ROOT}` — they must survive plugin
   uninstall.
10. **Shebang + chmod.** `#!/usr/bin/env bash` first line; `chmod +x`
    immediately after Write; verify with `ls -l`.
11. **Self-contained.** Generated scripts depend only on bash + jq + git. No
    helper files outside `.claude/hooks/`, no network.
12. **Exit-code discipline.** Block = exit 2 (stderr goes to Claude) or a
    JSON decision. `exit 1` is NOT a block — it is a non-blocking error.
    Each template's header comment documents this.

## Substitution protocol (free-text "Other" policies)

1. Map the user's natural-language policy onto the event's template by
   filling ONLY the placeholders.
2. If the policy needs more (different matcher, new rule shape): extend
   `pretooluse-rules.json` with new rule objects or adjust the matcher — then
   re-verify shell-bypass coverage (rule 8) and show the delta explicitly.
3. Enforcement red line → ALSO propose the paired `permissions.deny` entry in
   the same confirmation ("hook matching is best-effort; deny is the wall").
4. Unsafe or preset-contradicting policy → flag, never silently apply:
   "This conflicts with `<rule>` from `<preset>` (deny wins across scopes)"
   or "This weakens a red line". Then single-select: Apply anyway (scoped
   down if possible) / Rephrase / Skip.
5. Pre-confirmation checklist — re-read the generated script and verify:
   - [ ] kill switch present (rule 2)
   - [ ] `PROJ_DIR` fallback present (rule 3)
   - [ ] Stop hooks: re-entry guard present (rule 4), StopFailure branch
     warn-only (rule 5)
   - [ ] all JSON via jq (rule 1)
   - [ ] fail mode matches the hook class (rule 6)
   - [ ] file rules have Bash companions (rule 8)
   Only then show the confirmation diff.
