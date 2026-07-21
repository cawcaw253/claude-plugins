# Phase 2 — settings.json (Step 2/6)

Target file comes from Phase 1 state (`scope`):
project → `.claude/settings.json` | local → `.claude/settings.local.json` |
user → `~/.claude/settings.json`

Surface this reminder to the user: **permissions allow/ask/deny MERGE across
scopes** (a project deny cannot be removed by a local allow); all other
settings override, local > project > user.

## Preset question (ONE AskUserQuestion call, ONE multiSelect question)

Question: "Which permission baselines should I merge into your settings?
(deny rules are the hard wall your hooks will pair with)" — header
`Permissions`, multiSelect: true. No previews (multiSelect) — descriptions
carry the detail. Do NOT add an "Other" option.

| # | Label | Description (shown in UI) |
|---|-------|---------------------------|
| 1 | Deny secret files (Recommended) | deny Read/Write/Edit on .env*, secrets/**, *.pem, id_rsa* — holds even if a hook fails |
| 2 | Deny destructive bash (Recommended) | deny rm -rf /~, force-push, `curl \| sh`, sudo, git reset --hard |
| 3 | Allow common dev commands | pre-approve git status/diff/log, npm/pnpm test & lint, ls — fewer prompts for routine ops |
| 4 | Ask before network/remote | route curl/wget/gh api and git push through the ask list |

### Exact rules per preset

**deny-secrets**
```json
{ "permissions": { "deny": [
  "Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)", "Read(./**/*.pem)", "Read(./**/id_rsa*)",
  "Write(./.env)", "Write(./.env.*)", "Write(./secrets/**)",
  "Edit(./.env)", "Edit(./.env.*)", "Edit(./secrets/**)"
] } }
```

**deny-destructive-bash**
```json
{ "permissions": { "deny": [
  "Bash(rm -rf /*)", "Bash(rm -rf ~*)", "Bash(git push --force*)", "Bash(git push -f*)",
  "Bash(sudo *)", "Bash(curl * | sh)", "Bash(curl * | bash)", "Bash(wget * | sh)",
  "Bash(git reset --hard*)"
] } }
```

**allow-common-dev-cmds**
```json
{ "permissions": { "allow": [
  "Bash(git status)", "Bash(git diff *)", "Bash(git log *)", "Bash(ls *)",
  "Bash(npm run lint)", "Bash(npm run test *)", "Bash(npm test *)",
  "Bash(pnpm test *)", "Bash(pnpm lint)"
] } }
```
After applying, ask: "Project uses a different runner? Tell me and I'll swap
npm → pnpm/yarn/cargo/go/etc." Detect from lockfiles where possible and
propose the swap yourself.

**ask-before-network**
```json
{ "permissions": { "ask": [
  "Bash(curl *)", "Bash(wget *)", "Bash(gh api *)", "Bash(git push *)"
] } }
```
Conflict note: if the user also picked deny-destructive-bash, the
`curl * | sh` denies stay in deny (deny beats ask) — say so explicitly, do
not remove them.

## Merge algorithm (NEVER clobber)

1. Target file absent → create parent dir; write
   `{"$schema": "https://json.schemastore.org/claude-code-settings.json"}`
   plus the selected rules.
2. File exists but is invalid JSON → STOP. Show the parse error; single-select
   "I'll fix it myself first / Show me the problem / Skip Phase 2". Never
   overwrite invalid JSON.
3. Deep-merge:
   - `permissions.allow` / `.ask` / `.deny`: union + dedupe as
     `existing + (new − existing)` — preserve existing order, append new
     entries at the end. NEVER remove or rewrite an existing entry.
   - Every other key: keep the existing value; only add absent keys. If a
     preset wants a key that exists with a different value, keep the user's
     value and report the skip.
4. Show a unified diff (existing → candidate) in a fenced block BEFORE
   writing.
5. Confirm (single-select): Apply (Recommended) / Edit first / Skip. Write
   only on Apply.
6. Record in state `appliedFiles` as `{"path": ..., "action": "created"|"merged"}`.

Closing note to the user: these deny rules are the hard backstop for
Phase 4's hooks — hooks are best-effort, deny is the wall.
