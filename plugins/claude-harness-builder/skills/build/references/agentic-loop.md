# Phase 0 — The Agentic Loop (Step 0/6)

Render this diagram verbatim in the Step 0/6 message (fits an 80-col terminal):

```
                  ┌────────────────────────────────────────────────┐
 SessionStart ──▶ │ SESSION starts (CLAUDE.md + memory loaded)     │
                  └────────────────────────────────────────────────┘
 UserPromptSubmit ──▶ your prompt enters the loop
                                   │
      ┌────────────────────────────▼────────────────────────────┐
      │                      AGENTIC LOOP                       │
      │                                                         │
      │  ┌────────────────┐   ┌─────────────┐   ┌────────────┐  │
      │  │ GATHER CONTEXT │──▶│ TAKE ACTION │──▶│   VERIFY   │  │
      │  └────────────────┘   └─────────────┘   └────────────┘  │
      │        ▲        every tool call passes through:   │     │
      │        │   PermissionRequest ▸ PreToolUse ▸       │     │
      │        │      [tool executes] ▸ PostToolUse       │     │
      │        └──────────────── repeat ──────────────────┘     │
      └────────────────────────────┬────────────────────────────┘
                                   ▼
           Stop / StopFailure ─── turn ends (gate: really done?)
                                   │
           SessionEnd ─────────── session closes (cleanup/log)

  Cross-cutting layers (always active, not events):
    permissions.allow/ask/deny ── hard fail-safe wall under every hook
    CLAUDE.md rules ──────────── steer the model BEFORE hooks must act
```

Follow it with exactly this explanation (adapt language to the user, keep the
content):

> Claude Code repeats three phases — gather context, take action, verify
> results — until your task is done, and every step in that cycle is a tool
> call. A harness is the set of controls wrapped around this loop: hooks fire
> at fixed events, permissions form a hard wall, and CLAUDE.md rules steer
> decisions. SessionStart and UserPromptSubmit let you inject context before
> the loop runs; PermissionRequest, PreToolUse, and PostToolUse let you
> inspect, block, or audit every tool call inside it. Stop and StopFailure
> gate the end of a turn ("did tests actually pass?"), and SessionEnd handles
> cleanup. This wizard builds each layer in that order — scope, permissions,
> rules, hooks, commands — in 6 steps.

## Three layers of intervention

- **CLAUDE.md rules — guide.** Delivered as context; Claude reads and tries to
  follow them, but nothing enforces them. Cheap, expressive, and the right
  place for conventions. (Phase 3)
- **Permissions — gate.** `allow`/`ask`/`deny` rules evaluated by the harness
  itself, not the model. Deny rules are the hard wall that holds even when a
  hook is buggy or disabled. Merged across scopes. (Phase 2)
- **Hooks — enforce.** Deterministic scripts at the events in the diagram.
  The only layer that can inspect tool *arguments*, inject context, or gate
  the end of a turn. Best-effort at the edges (matchers, `if`), which is why
  red lines are always paired with a deny rule. (Phase 4)

## Why this phase order

Scope first (every later write needs a target file); permissions before hooks
(deny rules are the fail-safe that hooks pair with); CLAUDE.md before hooks
(rules guide, hooks enforce — the generated "Harness notes" section
cross-links the two); commands last (they build on the rules and settings
already in place).

## Per-phase summaries (reuse as previews in the Phase 0 question)

| Step | Phase | Outcome | Files |
|---|---|---|---|
| 1 | Scope | Where the harness lives | state only |
| 2 | Settings | Permission wall (deny/allow/ask presets) | settings.json at scope |
| 3 | CLAUDE.md | Project rules skeleton | CLAUDE.md |
| 4 | Hooks | Enforcement scripts for up to 7 events | .claude/hooks/*, settings hooks block |
| 5 | Commands | Custom slash commands from your description | .claude/commands/*.md |
| 6 | Summary | Verification checklist + rollback | nothing new |

Jumping never deletes existing config; every phase merges.
