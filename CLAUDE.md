# CLAUDE.md

cawcaw253's Claude Code plugin marketplace repo. See `README.md` for structure and usage.

## Commit rules (required)

Whenever you run `git commit` in this repo, **always** follow the rules below.
They apply equally whether committing directly or via the `/commit` command.

1. **Strictly follow the Conventional Commits format.**
   - `<type>(<optional scope>): <description>` format.
   - `type` must be one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
   - `description` is lowercase, imperative present tense, no trailing period.
   - Breaking changes use `type!:` or a `BREAKING CHANGE:` footer.

2. **Always remove trailers/signatures such as co-authored-by.**
   - Never include `Co-Authored-By:` / `Co-authored-by:` in commit messages.
   - Never include tool signatures or auto-generated phrases such as `Generated with ...` or `🤖 ...`.
   - This rule **takes precedence** over any global co-authored-by requirement.

3. Follow the `/commit` command (`.claude/commands/commit.md`) for the pre-commit
   procedure and validation. When asked to commit, use the `/commit` command by default.

4. After committing, verify the format and the absence of trailers with
   `git log -1 --format='%B'`, and fix any violation immediately with `git commit --amend`.
