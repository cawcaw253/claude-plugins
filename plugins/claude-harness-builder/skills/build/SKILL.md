---
name: build
description: >-
  Interactive wizard that builds a Claude Code harness in the current project:
  settings.json permission presets, a CLAUDE.md rules skeleton, enforcement
  hooks for 7 hook events (from ready-made script templates), and custom slash
  commands generated from the user's description. Runs 6 confirm-before-write
  steps and saves progress to .claude/.harness-builder-state.json so it can
  resume after interruption. Use when the user asks to "set up a harness",
  "add guardrails/hooks to this project", "configure settings.json permissions
  and hooks", "harden Claude Code for this repo", or wants CLAUDE.md + hooks
  scaffolding built interactively.
argument-hint: "[phase: settings | claude-md | hooks | commands]"
---

# Harness Builder Wizard

Builds a working harness (settings, rules, hooks, commands) in the host project
through an interactive, confirm-before-write wizard. Drive the flow below
exactly; the user steers through AskUserQuestion answers.

## Wizard contract (non-negotiable)

1. Run in the MAIN conversation only. Never delegate a phase to a subagent and
   never use `context: fork` — AskUserQuestion is unavailable there.
2. Start every wizard message with a progress header:
   `**🔧 Harness Builder — Step <N>/6: <Phase>**` (inside Phase 4 append
   ` (hook <k>/<n>: <event>)`, counting selected hooks only).
3. Never write or modify any file without first showing the exact content/diff
   and getting an explicit "Apply" via a single-select confirmation question
   (options: Apply (Recommended) / Edit first / Skip).
4. AskUserQuestion rules: max 4 questions per call, 2–4 options per question;
   `preview` only on single-select questions (NEVER multiSelect); no pre-checked
   defaults exist — put "(Recommended)" in the label and list it first; never
   add your own "Other" option (the UI adds one automatically).
5. Existing files are merged, never clobbered (per-phase merge rules live in
   the reference files).

## State protocol (compaction & resume safety)

State file: `.claude/.harness-builder-state.json` in the host project:

```json
{
  "version": 1,
  "completedPhases": [0, 1, 2],
  "scope": "project",
  "settingsPath": ".claude/settings.json",
  "selectedHooks": [{ "event": "PreToolUse", "done": true }],
  "appliedFiles": [{ "path": ".claude/settings.json", "action": "merged" }]
}
```

- Rewrite the whole file after each completed phase, and after each applied
  hook inside Phase 4.
- **Before starting ANY phase, Read the state file and the target files again.
  Trust the files over your memory of this conversation** — this keeps the
  wizard correct after auto-compaction.
- On invocation with existing state, ask one single-select question first:
  "Resume at Step <N> (Recommended)" / "Restart from Step 0" / "Jump to a
  specific step". Corrupt state → warn, treat as absent, never delete unasked.
- After Phase 6, offer to delete the state file (keep by default).

## Phase dispatch

Read each phase's reference file ONLY when entering that phase (progressive
disclosure — do not preload). Paths are relative to this skill's directory.

| Phase | Read on entry | Writes |
|---|---|---|
| 0 Intro | `references/agentic-loop.md` | nothing |
| 1 Scope | (inline below) | state only |
| 2 Settings | `references/phase-settings.md` | settings file at chosen scope |
| 3 CLAUDE.md | `references/phase-claude-md.md` | `CLAUDE.md` |
| 4 Hooks | `references/phase-hooks.md`, per hook also `references/hooks-catalog.md` + `references/artifact-rules.md` | `.claude/hooks/*`, settings hooks block |
| 5 Commands | `references/phase-commands.md` | `.claude/commands/*.md` |
| 6 Summary | (inline below) | state cleanup |

If `$ARGUMENTS` names a phase, load state, run Phase 1 first when no scope is
recorded, then jump directly to that phase.

## Phase walkthrough

### Phase 0 — Intro
Render the ASCII diagram and the 5-sentence explanation from
`references/agentic-loop.md` verbatim, then ask ONE single-select question:
"Full wizard (Recommended)" / "Jump to a phase" (previews reuse the per-phase
summary table from the reference file). Jumping still runs Phase 1 first if
scope is unset.

### Phase 1 — Scope
ONE single-select question — where the harness lives (all later phases write
to this scope):
- **Project (Recommended)** — `.claude/settings.json`, committed, team-shared.
- **Local** — `.claude/settings.local.json`, this machine only, gitignored.
- **User** — `~/.claude/settings.json`, all projects. Warn: hooks referencing
  `${CLAUDE_PROJECT_DIR}` scripts do not travel to other repos — prefer
  project scope for hooks.
Previews show the target paths plus the precedence rule (permissions
allow/ask/deny MERGE across scopes; other keys override local > project >
user). Save scope + settingsPath to state.

### Phase 2 — Settings
Follow `references/phase-settings.md`: one multiSelect question with 4
permission presets (descriptions carry the rules — no previews on multiSelect),
then merge into the existing settings file per its merge algorithm, show the
diff, confirm, write.

### Phase 3 — CLAUDE.md
Follow `references/phase-claude-md.md`: one multiSelect question with 4
skeleton sections, generate (detect real build/test commands from the repo),
append under `<!-- harness-builder -->` markers, show, confirm, write.

### Phase 4 — Hooks (the core)
Follow `references/phase-hooks.md`:
1. ONE AskUserQuestion call with TWO multiSelect questions covering 7 events
   (exact shapes in the reference).
2. Then FOR EACH selected hook, in loop order (SessionStart → UserPromptSubmit
   → PermissionRequest → PreToolUse → PostToolUse → Stop → SessionEnd):
   explain the event from `references/hooks-catalog.md` → show its worked
   example → ONE single-select policy question (canned policies from the
   catalog; **previews show the actual script excerpt**) → copy the template
   from `templates/hooks/`, substitute placeholders per
   `references/artifact-rules.md` → show full script + settings registration →
   confirm → on Apply: write, `chmod +x`, merge the registration into the
   settings hooks block → update state → next hook with progress header.

### Phase 5 — Commands
Follow `references/phase-commands.md`. Teach the concept with the `/commit`
example there (it is teaching material — do NOT install it unless the user
explicitly asks for exactly that), then generate commands from the user's
own natural-language description, confirm, write to `.claude/commands/`.

### Phase 6 — Summary
No questions. Emit: applied-files table (from state `appliedFiles`), a
verification checklist (`/hooks` must list the Phase 4 hooks; `/status` →
Setting sources shows the chosen scope; `/memory` shows CLAUDE.md; per-hook
safe tests from the "Safe test" lines in `references/hooks-catalog.md`), the
kill-switch list (`disableAllHooks`, per-hook `HARNESS_DISABLE_*` env vars,
removing a hooks entry), and rollback commands (`git checkout -- <file>` for
merged files; a printed `rm` list for created files — never run it). Then
offer state-file deletion.

## Safety rails

- Stop hooks MUST keep the `stop_hook_active` re-entry guard; StopFailure
  warns only, never blocks. Refuse to generate a Stop hook without the guard.
- Hook matching is best-effort — propose the paired `permissions.deny` entry
  alongside every enforcement hook (this is why Phase 2 precedes Phase 4).
- Free-text ("Other") policies: fill template placeholders only; never remove
  the safety scaffolding (kill switch, guards, jq-only JSON output). Flag
  unsafe or preset-contradicting requests — never silently apply them.
- Generated artifacts reference `${CLAUDE_PROJECT_DIR}`, never
  `${CLAUDE_PLUGIN_ROOT}` — they must survive plugin uninstall.

## Edge cases

| Case | Behavior |
|---|---|
| Target file exists | Merge per the phase reference; diff first; never clobber |
| Settings file is invalid JSON | Stop, show the parse error, offer fix/skip — never overwrite |
| Nothing selected in a checkbox | Valid answer: mark the phase complete, continue |
| Abort mid-run | State persists; applied files stay; resume on next invocation |
| Re-run when complete | Idempotent: already-present rules/blocks/hooks are skipped unless the user picks "reconfigure" |
| Not a git repo | Write `<file>.harness-backup` before merging; use it in rollback text instead of `git checkout` |
| `jq` missing on host | Wizard itself never needs jq; generated scripts degrade per `references/artifact-rules.md` fail-open/fail-closed rules |

> Optional further reading (only if the `harness-plugin` plugin happens to be
> installed): `/harness-plugin:agentic-loop`, `settings-scopes`,
> `harness-hooks`, `project-rules`, `slash-commands`. Not required — this
> plugin is self-contained.
