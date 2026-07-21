---
name: slash-commands
description: >-
  Explains how to write and place custom slash commands (= skills). Covers the
  relationship between .claude/commands and .claude/skills, frontmatter
  (description, disable-model-invocation, allowed-tools, argument-hint, model,
  etc.), arguments ($ARGUMENTS/$N), dynamic context injection (!`cmd`), and
  file locations, priority, and namespaces. Use when the user asks about
  "creating a custom command", "a command like /commit", "slash command
  frontmatter", "passing arguments to a command", and similar topics.
---

# Custom Slash Commands (= Skills)

Explains how to create custom commands like `/commit`.
Official docs: https://code.claude.com/docs/en/slash-commands , https://code.claude.com/docs/en/skills

> **Key point:** custom commands have been **merged into skills**. `.claude/commands/deploy.md`
> and `.claude/skills/deploy/SKILL.md` both create `/deploy` and behave identically.
> Existing `.claude/commands/*.md` files keep working, but the **skill format is recommended**
> (it adds supporting-file directories, automatic-invocation control, and more).
> This repo's `/commit` lives in `.claude/commands/commit.md` and works fine.

---

## 1. File locations and command names

The command name comes from the **file/directory location** (the frontmatter `name` is only a
display label).

| Location | Command name | Scope |
|------|-------------|-----------|
| `.claude/commands/deploy.md` | `/deploy` (file name) | Project (committed) |
| `.claude/skills/deploy/SKILL.md` | `/deploy` (directory name) | Project (committed) |
| `~/.claude/skills/<name>/SKILL.md` | `/<name>` | Me (all projects) |
| `<plugin>/skills/<name>/SKILL.md` | `/<plugin>:<name>` | Wherever the plugin is enabled |

- On name collisions: plugins are namespaced so they never collide; otherwise
  enterprise > personal > project. If a skill and a command share a name, the **skill wins**.
- Custom commands/skills also override bundled skills of the same name (`/code-review`, etc.).

---

## 2. Frontmatter (commonly used fields)

```yaml
---
description: What it does and when to use it (Claude uses this for auto-invocation decisions)
disable-model-invocation: true      # Only I can invoke it (no automatic invocation by Claude)
allowed-tools: Bash(git add *) Bash(git commit *)
argument-hint: "[issue-number]"
model: inherit                      # Model to use while this skill is active
context: fork                       # Run in a separate subagent context
---
```

| Field | Purpose |
|------|------|
| `description` | The only recommended field. Basis for Claude's auto-invocation decisions |
| `disable-model-invocation: true` | **Only I** can invoke (required for side-effectful `/commit`, `/deploy`) |
| `user-invocable: false` | **Only Claude** can invoke (hidden from the `/` menu, for background knowledge) |
| `allowed-tools` | Tools allowed without approval during the invoking turn (cleared on the next message) |
| `disallowed-tools` | Tools removed while this command is active |
| `argument-hint` | Autocomplete hint |
| `arguments` | Named positional arguments (`$name` substitution) |
| `model` / `effort` | Model/reasoning effort while this command is active |
| `context: fork` | Run in an isolated subagent (specify the type with `agent`) |
| `paths` | Auto-activate only when working on files matching these patterns |

> **Harness perspective:** always add `disable-model-invocation: true` to commands with side
> effects (`/commit`, `/deploy`) so Claude cannot run them arbitrarily.
> For project skills, `allowed-tools` takes effect after workspace trust is accepted —
> a skill can grant itself broad permissions, so review it before trusting.

---

## 3. Passing arguments

| Variable | Meaning |
|------|------|
| `$ARGUMENTS` | The full argument string |
| `$ARGUMENTS[N]` / `$N` | The Nth (0-based) argument. `$0`, `$1` … |
| `$name` | Named argument declared via the `arguments` frontmatter |

```yaml
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
---
Fix GitHub issue $ARGUMENTS following our coding standards.
```

`/fix-issue 123` → "Fix GitHub issue 123 …". If `$ARGUMENTS` is absent, the input is appended
as `ARGUMENTS: <value>`. Wrap multi-word arguments in quotes.

---

## 4. Dynamic context injection — `` !`command` ``

Runs a shell command **before** the skill content is delivered to Claude and substitutes its
output (preprocessing — Claude does not execute it).

```yaml
---
name: summarize-changes
description: Summarizes uncommitted changes and flags risks.
allowed-tools: Bash(git diff *)
---

## Current changes
!`git diff HEAD`

## Instructions
Summarize the changes above in 2-3 bullets and list any risks.
```

- Only `` !`...` `` at the start of a line or after whitespace is recognized
  (`KEY=!`cmd`` is a literal).
- For multiple lines, use a ` ```! ` fenced block.
- ⚠️ Policy blocking: with the setting `disableSkillShellExecution: true`, execution is replaced
  with `[shell command execution disabled by policy]` (bundled/managed skills are exempt).
  → Use this in a harness when you want to block arbitrary shell execution inside skills
  (see the `settings-scopes` skill).

---

## 5. Controlling Claude's command access (harness)

Control which skills/commands Claude may invoke via permissions (based on the `Skill` tool):

```text
# Block all (deny): Skill
# Allow only specific ones: Skill(commit)   Skill(review-pr *)
# Block specific ones:      Skill(deploy *)
```

- `Skill(name)` matches exactly, `Skill(name *)` matches by prefix.
- `disable-model-invocation: true` removes it from Claude's context entirely.
- `skillOverrides` in settings controls visibility without editing frontmatter
  (on/name-only/off, etc.).

---

## Example: upgrading this repo's `/commit` to a skill

```yaml
---
description: Commit with Conventional Commits rules (strip co-authored-by)
disable-model-invocation: true
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *) Bash(git diff *) Bash(git log *)
---
```

`disable-model-invocation` restricts execution to the user, and `allowed-tools` allows
commit-related git commands without approval. The procedure body reuses the existing
`commit.md` as-is.

---

## References

- Slash commands: https://code.claude.com/docs/en/slash-commands
- Skills: https://code.claude.com/docs/en/skills
- Related skills: `project-rules` (CLAUDE.md), `workflows`, `harness-hooks`
