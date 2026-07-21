---
name: project-rules
description: >-
  Explains how to configure project rules and instructions with CLAUDE.md and
  .claude/rules/. Covers file locations and load order, path-specific rules
  (paths frontmatter), @import, writing effective instructions, the limitation
  that "rules are context, not enforcement", and pairing rules with hooks. Use
  when the user asks about "writing CLAUDE.md", "project rules",
  ".claude/rules", "applying rules to specific files only", "Claude ignores my
  instructions", "enforcing commit rules", and similar topics.
---

# Project Rules (CLAUDE.md & .claude/rules/)

Explains how to give Claude persistent instructions.
Official docs: https://code.claude.com/docs/en/memory

> ⚠️ **Key limitation:** CLAUDE.md and rules are delivered as **context**, not as the system prompt.
> Claude reads them and tries to follow them, but they are **not enforced.** Policies that must
> always run — such as pre-commit checks or post-edit steps — should be enforced with `PreToolUse`
> hooks from the `harness-hooks` skill. Rules guide, hooks enforce — use both together.

---

## 1. CLAUDE.md locations and load order

CLAUDE.md can live in multiple locations and loads **broad scope → narrow scope**, so later
files sit closer to the conversation. (They do not override each other — all are **concatenated**
into context.)

| Scope | Location | Shared with |
|------|------|:----:|
| User | `~/.claude/CLAUDE.md` | Me (all projects) |
| Project | `./CLAUDE.md` or `./.claude/CLAUDE.md` | Team (committed) |
| Local | `./CLAUDE.local.md` | Me (this project, gitignored) |

- CLAUDE.md files **above** the working directory are fully loaded at startup. Files in
  subdirectories below are loaded when Claude reads files in that directory.
- The project root CLAUDE.md is re-read from disk and **re-injected** after `/compact`
  (nested subdirectory CLAUDE.md files are not automatically re-injected).
- Use `/init` to auto-generate a starter CLAUDE.md, and `/memory` to view and edit loaded files.

> **Harness perspective:** commit team-shared rules (commit conventions, etc.) into the
> **project CLAUDE.md**. This repo keeping its commit rules in `CLAUDE.md` is an example.

---

## 2. Writing effective instructions

Instructions consume context and affect compliance, so write them to be **specific, concise,
and structured**.

- **Size:** aim for 200 lines or fewer per file. Longer files consume more context and lower compliance.
- **Structure:** group with markdown headers and bullets.
- **Specificity:** make instructions verifiable. "Format properly" ❌ → "Use 2-space indentation" ✅ /
  "Run tests" ❌ → "Run `npm test` before committing" ✅
- **Consistency:** if rules conflict, Claude picks arbitrarily. Clean up periodically.
- HTML comments (`<!-- ... -->`) are stripped before context injection and consume no tokens
  (useful for maintenance notes).

---

## 3. `.claude/rules/` — split rules into files

In large projects, split instructions into topic-specific files. The modular layout makes team
maintenance easier.

```text
.claude/
├── CLAUDE.md          # Main instructions
└── rules/
    ├── code-style.md
    ├── testing.md
    └── security.md
```

- Rules **without** a `paths` frontmatter → loaded at startup with the same priority as `.claude/CLAUDE.md`.
- `~/.claude/rules/` is user-level (all projects) and loads before project rules.
- Symbolic links allow sharing across projects.

### Path-specific rules

Use `paths` to load a rule only when working on matching files → less noise, saves context.

```markdown
---
paths:
  - "src/api/**/*.{ts,tsx}"
  - "lib/**/*.ts"
---

# API development rules
- Every endpoint includes input validation
- Use the standard error response format
```

| Pattern | Matches |
|------|------|
| `**/*.ts` | All TS files |
| `src/**/*` | Everything under `src/` |
| `*.md` | md files in root |

> Path-specific rules trigger **when files are read** (not on every tool use).
> For task-specific procedures that are not always needed, a **skill** (see the
> `slash-commands` skill) is a better fit than a rule.

---

## 4. Importing files with @import

CLAUDE.md can inline other files with the `@path/to/file` syntax (up to 4 hops of recursion).

```text
See @README for project overview and @package.json for npm commands.

# Additional instructions
- git workflow @docs/git-instructions.md
- personal instructions @~/.claude/my-project-instructions.md
```

- Relative paths are resolved **relative to the importing file**.
- `@` inside code spans/fences is ignored (`` `@README` `` is a literal).
- ⚠️ Imported files are also **loaded into context at startup**, so imports do not reduce tokens.
  If saving tokens is the goal, use path-specific rules or skills.
- Claude does not read `AGENTS.md` directly → import it with `@AGENTS.md` or use a symlink.

---

## 5. Troubleshooting "Claude ignores my rules"

1. Check with `/memory` that the file is actually **loaded** (if it is not in the list, Claude never saw it).
2. Make the instructions more **specific**.
3. Remove **conflicts** between files.
4. If it must always be followed → **enforce with a hook** (`harness-hooks` skill).
   `--append-system-prompt` suits scripts/automation.

> Rules (CLAUDE.md/rules) = shape behavior, hooks = hard enforcement,
> settings (`permissions.deny`) = block tools. Use the three layers according to purpose.

---

## Managed (organization level) — out of scope

> Organizations can force-deploy org-wide instructions via a CLAUDE.md in the managed policy
> location or the `claudeMd` key in `managed-settings.json`. **This is outside the harness scope
> of this repo, so it is not covered.** Individual developers use only user/project/local CLAUDE.md.

---

## References

- Memory: https://code.claude.com/docs/en/memory
- Hooks: https://code.claude.com/docs/en/hooks
- Related skills: `agent-memory` (automatic memory), `slash-commands`, `harness-hooks`
