---
name: agentic-loop
description: >-
  Explains how Claude Code works internally (agentic loop, tools, context window,
  sessions, checkpoints/permissions). A foundational skill that helps you understand
  "where you can intervene" before building a harness. Use when the user asks about
  "how Claude Code works", "agent loop", "agentic loop", "context management",
  "how Claude does its work", "what the harness wraps", etc.
---

# How Claude Code Works (Agentic Loop)

Explains how Claude Code works internally. To design a harness (constraining the
scope of work), you first need to know **where you can intervene**.
Official docs: https://code.claude.com/docs/en/how-claude-code-works

> Claude Code is an **agentic harness** wrapping the Claude model. It provides tools,
> context management, and an execution environment that turn a language model into a
> capable coding agent. Configuring a harness means constraining what this harness
> provides through policy.

---

## 1. Agentic Loop — Three Phases

Given a task, Claude repeats three phases. The phases are not sharply separated and blend together.

| Phase | What it does | Example tools |
|------|---------|-----------|
| **Gather context** | Understand code and state | File search, Read, git status |
| **Take action** | Make changes | Edit/Write, Bash execution |
| **Verify results** | Validate the outcome | Run tests, re-search |

- The loop adapts to the request. A simple question only gathers context; a bug fix
  cycles through all three phases multiple times.
- Each tool call result feeds back into the next decision ("fix the failing tests" → run tests
  → read errors → search source → fix → re-run).
- The user can interrupt at any time with `Esc` or add instructions to change direction.

> **Harness perspective:** each of these three phases consists of tool calls, so the
> `PreToolUse`/`PostToolUse` hooks are the intervention points. Blocking risky tools in the
> "action" phase (destructive Bash, edits to protected files) is the core of a harness.
> → See the `harness-hooks` skill.

---

## 2. The Two Axes of the Loop: Model and Tools

### Model (reasoning)

- The Claude model understands code and reasons about the task. "Claude decides" means the model's reasoning.
- Switch mid-session with `/model` or start with `claude --model <name>`.
  (Sonnet excels at most coding; Opus at complex design reasoning.)

### Tools (action)

Without tools, Claude only returns text. Tools are what let it **act**.
Built-in tools fall into five categories.

| Category | What Claude can do |
|------|------------------------|
| **File operations** | Read, edit, create, rename/restructure |
| **Search** | Find files by pattern, regex content search, explore the codebase |
| **Execution** | Shell commands, start servers, tests, git |
| **Web** | Web search, fetch docs, look up errors |
| **Code intelligence** | Check type errors/warnings after edits, go to definition, find references (requires plugin) |

Beyond these there are orchestration tools such as spawning subagents and asking questions.

> **Extension layers:** built-in tools are the foundation. On top sit skills (→ the
> `slash-commands` skill), MCP, hooks (→ the `harness-hooks` skill), subagents, and
> workflows (→ the `workflows` skill). **A harness constrains this tool usage mostly at
> the hooks and permissions layers.**

---

## 3. What Claude Has Access To

When you run `claude` in a directory, its access scope:

- **Project** — the current directory and files below it (anything else requires permission)
- **Terminal** — every command the user can run (builds, git, package managers, scripts)
- **git state** — current branch, uncommitted changes, recent commit history
- **CLAUDE.md** — project instructions loaded every session
- **Auto memory** — automatically saved learnings (the beginning of MEMORY.md is loaded)
- **Configured extensions** — MCP servers, skills, subagents, etc.

> This access scope is exactly the "attack surface" a harness must constrain. In
> particular, the **terminal (Bash)** and **file edits (Edit/Write)** are the widest and
> are the first targets for control.

---

## 4. Context Window (Important for Harness Design)

The context window holds conversation history, file contents, command output, CLAUDE.md,
auto memory, loaded skills, and system instructions. When it fills up, Claude automatically compacts it.

- **Early instructions can be lost during auto-compaction.** → Put permanent rules in
  **CLAUDE.md**, not in the conversation. (This is why things like commit rules are
  enforced through CLAUDE.md.)
- Compaction order: oldest tool output is removed first → conversation is summarized if
  needed. The request and key code are preserved.
- Check usage with `/context`; specify what to preserve with `/compact focus on ...`.
- **Skills load on demand** — only descriptions at session start, full content when used.
  Descriptions can also be hidden via `disable-model-invocation: true` / `skillOverrides` in settings.
- **Subagents get a separate context** — they return only a summary without polluting the main conversation.

---

## 5. Sessions and Safeguards

### Sessions

- Conversations are stored as JSONL under `~/.claude/projects/` → rewind/resume/fork are possible.
- **Sessions are independent.** A new session starts with fresh context (no prior conversation).
  → Persist information via auto memory (→ the `agent-memory` skill) or CLAUDE.md (→ the `project-rules` skill).
- `--continue`/`--resume` append to the same session ID; `--fork-session`/`/branch` clone it.

### Checkpoints & Permissions (the Safety Axis of a Harness)

- **Every file edit can be undone** — a snapshot is taken before each edit; press `Esc`
  twice to rewind. This covers file changes only. **Remote side effects (DB, API,
  deployments) cannot be undone**, so Claude asks for confirmation before executing them.
  → These are what a harness should hard-block.
- **Permission modes** (cycle with `Shift+Tab`):

  | Mode | Behavior |
  |------|------|
  | Manual | Always ask before file edits and shell commands |
  | Accept edits | No prompt for edits and common filesystem commands; ask for the rest |
  | Plan | Explore and plan only, no source modification |
  | Auto | Evaluate every action with background safety checks |

- `.claude/settings.json` can pre-allow/deny specific commands (org → personal scopes).
  → See the `settings-scopes` skill for details and the `harness-hooks` skill for hard policies.

---

## Flow Toward Harness Configuration

**Foundation**
1. **This skill** — where can you intervene? (understand loop phases, tools, access scope)
2. **`settings-scopes` skill** — *where* do policies live? (user/project/local)
3. **`harness-hooks` skill** — *how* are policies enforced? (inspect/block/modify with hooks)

**Extension layers (what to constrain and configure)**
- **`project-rules` skill** — organize instructions with CLAUDE.md and `.claude/rules/`
- **`slash-commands` skill** — write custom commands (= skills) and control access
- **`workflows` skill** — orchestrate and disable multiple subagents
- **`agent-memory` skill** — control auto memory

---

## Reference Links

- How it works: https://code.claude.com/docs/en/how-claude-code-works
- Settings: https://code.claude.com/docs/en/settings
- Hooks: https://code.claude.com/docs/en/hooks
