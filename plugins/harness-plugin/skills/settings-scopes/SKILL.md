---
name: settings-scopes
description: >-
  Guides you through the scopes, precedence, file locations, and key options of
  Claude Code settings (settings.json). Helps you decide which scope harness
  policies (permissions, hooks, env) should live in. The Managed (organization-level)
  scope is out of scope for this repo's harness configuration and is ignored.
  Use when the user asks "where should settings.json go", "settings precedence",
  "user/project/local scopes", "share permissions with the team", "settings scopes", etc.
---

# Claude Code Settings Scopes

Helps you decide **which file/scope** harness policies (permissions, hooks, env, etc.) should live in.
Official docs: https://code.claude.com/docs/en/settings

> ⚠️ **The Managed (organization-level) scope is not covered by this skill.**
> Managed scope is enterprise configuration that IT/DevOps force-deploys across the
> organization via MDM, registry, or server; it is beyond the scope of a harness that an
> individual developer configures on a repo/machine. The "Managed scope — ignore" section
> below records its existence only; in practice use **only the user/project/local scopes**.

---

## 1. The Three Scopes Used in Practice

| Scope | Location | Affects | Shared with team |
|------|------|-----------|:-------:|
| **User** | `~/.claude/settings.json` | Me, all projects | No (my machine) |
| **Project** | `.claude/settings.json` | All collaborators on this repo | Yes (committed) |
| **Local** | `.claude/settings.local.json` | Me, only in this repo | No (auto-gitignored) |

### When to use which scope

- **User** — personal preferences (theme, editor), tools common to all projects, authentication.
- **Project** — team-shared policy (permissions, hooks, MCP servers), standard tools. **The default location for harness policy.**
- **Local** — personal overrides for a specific project, experiments before sharing, machine-specific settings.
  "Don't ask again" permanent permission approvals are also stored here.

> **Harness recommendation:** put rules the team must share (commit-policy hooks,
> blocking dangerous commands) in **Project (`.claude/settings.json`)** and commit them.
> Keep personal experiments in Local.

---

## 2. Precedence (When the Same Setting Exists in Multiple Scopes)

Highest → lowest:

1. **Managed** (top, cannot be overridden) — *outside this repo's scope, ignore*
2. **Command-line arguments** — temporary session override
3. **Local** — overrides project and user
4. **Project** — overrides user
5. **User** (lowest) — applies when nothing else specifies it

> Example: if user sets `spinnerTipsEnabled: true` and project sets `false`, the project value applies.

### ⚠️ Important exception: permissions are merged

The `allow`/`ask`/`deny` rules under `permissions` are **merged across all scopes**, not overridden.
That means a project's `deny` and a local `allow` work together. This is key when designing harness policy.

---

## 3. File Locations by Feature (user/project/local)

| Feature | User | Project | Local |
|------|------|---------|-------|
| Settings | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| Subagents | `~/.claude/agents/` | `.claude/agents/` | None |
| MCP servers | `~/.claude.json` | `.mcp.json` | `~/.claude.json` (per project) |
| Plugins | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| CLAUDE.md | `~/.claude/CLAUDE.md` | `CLAUDE.md` or `.claude/CLAUDE.md` | `CLAUDE.local.md` |

> On Windows, `~/.claude` resolves to `%USERPROFILE%\.claude`.
> `settings.local.json` is read and written at the git repo root (worktree-aware), so a
> single file covers all subdirectories and worktrees.

---

## 4. Example settings.json and Key Options

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": ["Bash(npm run lint)", "Bash(npm run test *)", "Read(~/.zshrc)"],
    "deny": ["Bash(curl *)", "Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)"]
  },
  "env": { "CLAUDE_CODE_ENABLE_TELEMETRY": "1" }
}
```

- `$schema` — enables editor autocomplete and validation (the schema may lag the latest CLI).
- `permissions` — control tool access with `allow`/`ask`/`deny`. **Merged across scopes.**
- `env` — environment variables applied to every session and child process. Use `""` to nullify a shell export.
- `hooks` — register lifecycle hooks (→ the `harness-hooks` skill).

Options especially relevant to a harness (all usable in user/project/local):

| Option | Purpose |
|------|------|
| `permissions.deny` | Hard-block dangerous commands/files |
| `disableAllHooks` | Disable all hooks and the custom status line |
| `disableSkillShellExecution` | Block inline shell execution inside skills/commands |
| `enableAllProjectMcpServers` | Auto-approve MCP servers in the project's `.mcp.json` |
| `enabledMcpjsonServers` / `disabledMcpjsonServers` | Approve/deny individual `.mcp.json` servers |

### When changes take effect

- Most settings (`permissions`, `hooks`, `env`, etc.) apply on file save **without a restart**.
- Read once at session start: `model` (use `/model` mid-session), `outputStyle` (on `/clear` or restart).
- Use `/config` for the settings UI; check loaded sources under `Setting sources` in `/status`.

---

## 5. Managed Scope — Ignore (Record Only)

> The following is **for reference only**. It is **not covered** in this repo's harness configuration.

- **Definition:** organization/enterprise-level settings. **Highest precedence**; user/project/local/command line cannot override it.
- **Deployment paths:** server-managed (claude.ai admin/gateway), MDM/OS policy (macOS plist,
  Windows registry), files (`managed-settings.json` + `managed-settings.d/`).
- **Examples of Managed-only options:** `allowedMcpServers`, `deniedMcpServers`,
  `allowManagedPermissionRulesOnly`, `blockedMarketplaces`, `claudeMd`, etc.
  → These are ignored if written in user/project/local, so this repo's skills do not use them.

**Conclusion:** configure harness policy using only the **user / project / local** scopes.
If organization-wide enforcement is needed, that is for IT to deploy via Managed and is outside this plugin's scope.

---

## Flow Toward Harness Configuration

1. `agentic-loop` skill — where can you intervene?
2. **This skill** — *which scope* do policies live in? (user/project/local)
3. `harness-hooks` skill — *how* are policies enforced?

---

## Reference Links

- Settings: https://code.claude.com/docs/en/settings
- Permissions: https://code.claude.com/docs/en/permissions
- Hooks: https://code.claude.com/docs/en/hooks
