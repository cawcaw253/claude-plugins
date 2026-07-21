---
description: Perform a git commit that follows this repo's commit rules (Conventional Commits, no co-authored-by)
---

# /commit — Rule-compliant commit

Commit while enforcing this repo's **commit rules**. Follow the procedure below exactly.

## 1. Review the changes

First, check the current state in parallel.

- `git status`
- `git diff` (staged + unstaged) — also check already-staged changes with `git diff --staged`
- `git log --oneline -10` — reference this repo's message style

If no files are staged, `git add` the relevant changed files according to intent.
Do not mix unrelated changes into a single commit.

## 2. Commit message rules (required)

### Conventional Commits format

```
<type>(<optional scope>): <description>

[optional body]

[optional footer]
```

- **type** must be one of the following only:
  `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- **description** starts lowercase, uses imperative present tense, and has no trailing period.
- Breaking changes use `type!:` or a `BREAKING CHANGE:` footer.
- The subject (first line) should be at most 72 characters.
- Write the subject/body in the repo's primary language (English).

**Good examples**

```
feat(commit): add conventional commit command
fix(hooks): correct matcher regex for edit tool
docs: update README installation steps
```

### Remove co-authored-by and other trailers (required)

**Never include** any of the following in commit messages:

- Any co-author trailer such as `Co-Authored-By:` / `Co-authored-by:`
- Tool signatures or auto-generated phrases such as `Generated with ...` or `🤖 ...`

> This rule is the default for this repo and **takes precedence** over any global
> co-authored-by trailer requirement.

## 3. Commit

Commit with the `-m` flag using a message that follows the rules above.
Even when using a HEREDOC, do not add co-author/signature trailers.

```bash
git commit -m "<type>(<scope>): <description>"
```

## 4. Verify

After committing, check the actual message with `git log -1 --format='%B'` to confirm

- the Conventional Commits format was followed
- there is no co-authored-by trailer or tool signature

If a violation is found, fix it immediately with `git commit --amend`.

Do not `git push` unless explicitly requested.
