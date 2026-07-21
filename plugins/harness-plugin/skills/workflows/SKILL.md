---
name: workflows
description: >-
  Explains Claude Code's dynamic workflows (orchestrating many subagents with a
  script). Covers when to use a workflow (compared to subagents/skills/agent
  teams), how to run and approve them, the ultracode keyword, storage locations
  (.claude/workflows), script structure (meta, agent, pipeline), execution
  constraints, and settings to disable them. Use when the user asks about
  "workflow", "orchestrating multiple agents", "large-scale migration/audit",
  "ultracode", "deep-research", and similar topics.
---

# Dynamic Workflows (subagent orchestration)

Explains dynamic workflows, which coordinate many subagents with a **script**.
Official docs: https://code.claude.com/docs/en/workflows

> A dynamic workflow is a JavaScript script that Claude writes and the runtime executes in the
> background. Use it for work at a scale a single conversation struggles to coordinate
> (tens to hundreds of agents), or when you want the orchestration itself preserved as a
> readable, re-runnable script. Requires Claude Code v2.1.154+ and a paid plan.

---

## 1. When to use a workflow (vs. subagents/skills/agent teams)

The key difference is **who holds the plan**.

| | Subagents | Skills | Agent teams | **Workflows** |
|---|---|---|---|---|
| What it is | Workers Claude spawns | Instructions Claude follows | Sessions supervised by a lead | **A script the runtime executes** |
| Decides what runs next | Claude (per turn) | Claude (per the prompt) | Lead (per turn) | **The script** |
| Intermediate results stored in | Claude context | Claude context | Shared task list | **Script variables** |
| What gets reused | Worker definitions | Instructions | Team definitions | **The orchestration itself** |
| Scale | A few per turn | Same | A few, long-running | **Tens to hundreds per run** |

Workflows move the plan into code, enabling **repeatable quality patterns** (adversarial
cross-checking between agents, drafting from multiple angles and comparing, etc.).
Intermediate results stay in script variables; only the final answer lands in Claude's context.

**Good fits:** codebase-wide bug sweeps, 500-file migrations, cross-verified research,
hard planning problems drafted from multiple angles and compared.

---

## 2. How to run

- **Bundled workflow:** `/deep-research <question>` — web searches from multiple angles,
  cross-verification, then a cited report.
- **Direct request:** include the `ultracode` keyword in your prompt or ask to "use a workflow" →
  Claude writes a script for that task. (This is opt-in and only triggers from prompts I type;
  it does not trigger via `-p`, schedules, or webhook paths.)
- **ultracode mode:** `/effort ultracode` → plans a workflow for every substantive task in the
  session. Increases tokens and time. Resets in a new session.
- Check progress (stages, agent count, tokens, time) with `/workflows`; run saved ones with `/<name>`.

### Approval (by permission mode)

| Mode | When prompted |
|------|--------------|
| Default / accept edits | Every run (skipped if you choose "Don't ask again for this workflow") |
| Auto | First run only (skipped when ultracode is on) |
| Bypass / `-p` / SDK | None (starts immediately) |

> **Harness perspective:** the launch prompt only gates the start. Subagents spawned by a
> workflow always run in **`acceptEdits` mode** regardless of the session mode and **inherit the
> tool allowlist**. File edits are auto-approved. Shell/web/MCP calls not on the allowlist may
> prompt mid-run — add the needed commands to the allowlist before a long run.

---

## 3. Storage locations and reuse

In `/workflows`, select a run and press `s` to save the script as a command.

| Location | Shared with |
|------|------|
| `.claude/workflows/` (project) | Team (committed) |
| `~/.claude/workflows/` (home) | Me (all projects) |

- After saving, run with `/<name>`. On name collisions the project one wins.
- Pass inputs via `args` (read as the global `args` in the script) — research questions,
  path lists, etc.

---

## 4. Saved script structure

A `meta` block plus a body (plain JavaScript with top-level await). You usually never need to
edit it by hand.

```javascript
export const meta = {
  name: 'audit-routes',
  description: 'Audit every route handler for missing auth checks',
}

const found = await agent('List every .ts file under src/routes/.', {
  schema: { type: 'object', required: ['files'],
    properties: { files: { type: 'array', items: { type: 'string' } } } },
})

const audits = await pipeline(found.files, file =>
  agent(`Audit ${file} for missing authentication checks.`, { label: file }),
)

return audits.filter(Boolean)
```

- `agent(prompt, opts)` — run one subagent (`schema` for structured output).
- `pipeline(items, ...stages)` — run the stage chain per item (no barrier between stages).
- `parallel(thunks)` — barrier. Waits until all complete.

---

## 5. Execution constraints

| Constraint | Reason |
|------|------|
| No user input mid-run | Only agent permission prompts can pause (for step-by-step approval, make each step its own workflow) |
| The script itself cannot touch files or the shell | Agents do the work; the script only coordinates |
| Max 16 concurrent agents (fewer on low-core machines) | Local resource limits |
| 1,000 agents total per run | Runaway prevention |

- **Resumable** within the same session (completed agents return cached results). Starts fresh
  if Claude Code exits.
- Large-run warning: over 25 agents or an estimated 1.5M tokens triggers a `Large workflow`
  warning (advisory).
- Cost: spawning many agents uses more tokens than a conversation. For big jobs, gauge with a
  subset (one directory) first.

---

## 6. Disabling (harness)

| Method | Scope |
|------|------|
| Dynamic workflows toggle in `/config` | Persists across sessions |
| `"disableWorkflows": true` in `settings.json` | Persists across sessions |
| Environment variable `CLAUDE_CODE_DISABLE_WORKFLOWS=1` | At startup |

When disabled, bundled workflow commands disappear and the `ultracode` keyword no longer
triggers. **Dynamic workflow size** in `/config` can also limit the scale of scripts Claude
writes (small<5 / medium<15 / large<50 agents, advisory).

> Org-wide disabling is a managed-settings matter → outside this repo's scope (ignore).

---

## References

- Workflows: https://code.claude.com/docs/en/workflows
- Related skills: `slash-commands` (saved workflow = command), `settings-scopes`, `agentic-loop`
