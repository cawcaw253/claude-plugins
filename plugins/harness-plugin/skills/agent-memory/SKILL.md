---
name: agent-memory
description: >-
  Guides you through Claude Code's auto memory and MEMORY.md. Covers how it differs
  from CLAUDE.md, storage location (~/.claude/projects/<project>/memory/), load rules
  (200 lines/25KB), enabling/disabling, auditing/editing (/memory), and the
  autoMemoryDirectory/autoMemoryEnabled settings. Use when the user asks about
  "auto memory", "MEMORY.md", "what Claude remembers", "turn off memory",
  "check/edit what it remembered", "auto memory location", etc.
---

# Auto Memory (Auto Memory & MEMORY.md)

Guides you through **auto memory**, where Claude accumulates its own learnings across sessions.
Official docs: https://code.claude.com/docs/en/memory

> Each session starts with fresh context. Two mechanisms carry knowledge across sessions:
> **CLAUDE.md** (instructions written by the user → the `project-rules` skill) and
> **auto memory** (learning notes Claude writes itself — this skill).

---

## 1. CLAUDE.md vs Auto Memory

Both are loaded at the start of every conversation, and both are **context, not enforcement**.

| | CLAUDE.md | Auto memory |
|---|---|---|
| Author | User | Claude |
| Content | Instructions and rules | Learnings and patterns |
| Scope | Project/user/organization | Per repository (shared across worktrees) |
| Loading | Every session (entire file) | Every session (first 200 lines/25KB of MEMORY.md) |
| Purpose | Coding standards, workflows, architecture | Build commands, debugging insights, discovered preferences |

> If you need to block actions, use neither — use a **PreToolUse hook** (the `harness-hooks` skill).
> Subagents can also have their own auto memory (subagent configuration).

---

## 2. Storage Location

Each project has a `~/.claude/projects/<project>/memory/` directory.
`<project>` is derived from the git repository → all worktrees and subdirectories of the
same repository **share** it. Auto memory is **machine-local** and is not shared across
machines or the cloud.

```text
~/.claude/projects/<project>/memory/
├── MEMORY.md          # concise index, loaded every session
├── debugging.md       # topic file (loaded on demand)
├── api-conventions.md
└── ...
```

To store it elsewhere, set `autoMemoryDirectory` in `settings.json` (absolute path or `~/`):

```json
{ "autoMemoryDirectory": "~/my-custom-memory-dir" }
```

> When specified in project/local settings, it only applies **after workspace trust is
> accepted** (the same gate as hooks).

---

## 3. How It Works

- Only the **first 200 lines or 25KB of MEMORY.md** (whichever comes first) is loaded at
  the start of every conversation. Anything beyond that is not loaded.
  → Claude moves detailed notes into topic files to keep MEMORY.md concise.
- This limit applies **only to MEMORY.md** (CLAUDE.md is loaded in full regardless of
  length, though shorter means better adherence).
- Topic files such as `debugging.md` are not loaded at startup → Claude reads them with
  file tools when needed.
- If you see "Writing memory"/"Recalled memory" in the UI, Claude is reading/writing the
  memory directory.

---

## 4. Enabling/Disabling (Harness)

**On** by default. To toggle:

| Method | Effect |
|------|------|
| Auto memory toggle in `/memory` | On/off for the session |
| `"autoMemoryEnabled": false` in `settings.json` | Disable |
| Environment variable `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` | Disable |

> **Harness perspective:** if you are concerned about sensitive information lingering in
> auto memory, turn it off with `autoMemoryEnabled: false` or control its location with
> `autoMemoryDirectory`. Auto memory is context, not enforcement, so it plays no role in
> policy enforcement.

---

## 5. Auditing & Editing

- Auto memory files are plain markdown that can be edited or deleted at any time.
- `/memory` — shows the loaded CLAUDE.md, CLAUDE.local.md, and rules; toggles auto memory
  on/off; opens the memory folder. Selecting a file opens it in the editor.
- If you say "remember X", Claude saves it to **auto memory**. To put it in CLAUDE.md
  instead, say explicitly "add this to CLAUDE.md" or edit it directly via `/memory`.
- If you're unsure what's stored, use `/memory` → check the auto memory folder.

---

## 6. Actual Usage in This Plugin Repository

This repo has auto memory at `~/.claude/projects/-...-claude-plugins/memory/`.
When configuring a harness, distinguish "what to remember" from "what to enforce as a CLAUDE.md rule":

- **Auto memory** — build commands and preferences Claude discovered (mutable learnings).
- **CLAUDE.md** — rules the team must follow (e.g., this repo's commit rules) → the `project-rules` skill.
- **hook** — when even rules must be made mandatory → the `harness-hooks` skill.

---

## Reference Links

- Memory: https://code.claude.com/docs/en/memory
- Related skills: `project-rules` (CLAUDE.md), `settings-scopes`, `harness-hooks`
