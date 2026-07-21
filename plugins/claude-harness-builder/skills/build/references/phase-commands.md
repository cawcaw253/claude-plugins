# Phase 5 — Custom commands (Step 5/6)

This phase does NOT install prebuilt commands. It teaches the concept with an
example, then generates commands from the user's own description.

Written to `.claude/commands/` (project/local scope) or `~/.claude/commands/`
(user scope). Note for the user: commands and skills are merged — each
`.claude/commands/<name>.md` file creates `/<name>`; plugin commands never
collide (they are namespaced).

## Stage A — Teach with an example

Explain in the Step 5/6 message, using `/commit` as the worked example
(teaching material — do NOT write this file unless the user explicitly asks
for exactly this):

````markdown
---
description: Commit staged/unstaged work following Conventional Commits
disable-model-invocation: true
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status) Bash(git diff *) Bash(git log *)
argument-hint: "[optional scope or message hint]"
---

## Current state
!`git status --short && git diff --stat HEAD`

## Procedure
1. Review the changes above and group them into one logical commit.
2. Stage explicitly with `git add <paths>` — never `git add -A`.
3. Compose `<type>(<scope>): <description>` (imperative, lowercase, no period).
4. Commit, then verify with `git log -1 --format='%B'`.
````

Walk through what each piece does:

- **`description`** — what Claude uses to decide auto-invocation.
- **`disable-model-invocation: true`** — side-effectful commands (commit,
  deploy, publish) get this so only the USER can trigger them; Claude cannot
  fire them on its own. Read-only helpers (review checklists, summaries)
  leave it off on purpose so Claude can use them too.
- **`allowed-tools`** — pre-approves exactly the tools the procedure needs
  during the invoking turn, no more.
- **`argument-hint`** — autocomplete hint; `$ARGUMENTS`/`$1` receive what the
  user types after the command.
- **`` !`command` ``** — dynamic context injection: runs BEFORE the content
  reaches Claude and substitutes its output (preprocessing, not something
  Claude executes).
- **Body** — a numbered procedure written like instructions to a colleague.

## Stage B — Capture what the user wants

ONE single-select question — "Want me to create custom commands for this
project?" — header `Commands`:

| # | Label | Description | Preview |
|---|-------|-------------|---------|
| 1 | Yes, I'll describe them (Recommended) | Describe each command in your own words (e.g. "a /deploy-check that verifies the build and lists changed migrations"); I'll turn each into a command file. | The /commit example above, annotated |
| 2 | Suggest some for this repo | I'll inspect the repo (scripts, CI config, conventions) and propose 2-3 commands tailored to it — you pick which to generate. | One-line sketches of what suggestion output looks like |
| 3 | Skip commands | Move on to the summary. You can rerun this phase anytime. | — |

- **Option 1:** for each described command, draft the full `.md` file
  following the generation rules below, show it, confirm, write.
- **Option 2:** Read package.json scripts / Makefile / CI config, propose
  2–3 tailored commands via one multiSelect question (label = `/name`,
  description = what it does), then draft/confirm/write each selected one.
- The automatic "Other" free-text answer is treated like option 1 input.

## Generation rules (every generated command)

1. Side-effectful (writes, commits, pushes, deploys, deletes) →
   `disable-model-invocation: true`, mandatory.
2. `allowed-tools` scoped to exactly the commands the procedure needs —
   never a bare `Bash`.
3. `description` states what it does AND when to use it.
4. Body is a numbered, verifiable procedure; use `` !`...` `` injection for
   state the procedure always needs (status, diff).
5. If the host CLAUDE.md defines related conventions (e.g. commit rules),
   the generated command must follow them — read CLAUDE.md before drafting.
6. Command name = file name; check `.claude/commands/<name>.md` for
   collisions first.

## Write procedure (per command)

1. Name collision → single-select: "Skip (Recommended)" / "Overwrite" /
   "Write as <name>-2.md". Show the existing file's first lines for
   comparison.
2. Show the full file content, confirm Apply / Edit first / Skip, write,
   record in state `appliedFiles`.
3. After all commands: remind the user that new commands appear in the `/`
   menu immediately, and that `disable-model-invocation: true` ones are
   invisible to Claude by design.
