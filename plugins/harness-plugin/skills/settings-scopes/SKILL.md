---
name: settings-scopes
description: >-
  Claude Code 설정(settings.json)의 범위(scope)와 우선순위, 파일 위치, 주요 옵션을
  안내한다. harness 정책(permissions·hooks·env)을 어느 범위에 둘지 결정하도록 돕는다.
  Managed(조직 레벨) 범위는 이 repo의 harness 구성 대상이 아니므로 무시한다.
  사용자가 "settings.json 어디에 둬야 하나", "설정 우선순위", "user/project/local 범위",
  "권한을 팀과 공유", "설정 범위" 등을 물을 때 사용한다.
---

# Claude Code 설정 범위 (Settings Scopes)

harness 정책(permissions, hooks, env 등)을 **어느 파일/범위에 둘지** 결정하도록 돕는다.
공식 문서: https://code.claude.com/docs/en/settings

> ⚠️ **Managed(조직 레벨) 범위는 이 skill에서 다루지 않는다.**
> Managed scope는 IT/DevOps가 MDM·레지스트리·서버로 조직 전체에 강제 배포하는
> 엔터프라이즈 설정이며, 개별 개발자가 repo/머신에서 구성하는 harness의 범위를 벗어난다.
> 아래 "Managed 범위 — 무시" 절에 존재만 기록하고 실무에서는 **user/project/local
> 세 범위만** 사용한다.

---

## 1. 실무에서 쓰는 세 범위

| 범위 | 위치 | 영향 대상 | 팀 공유 |
|------|------|-----------|:-------:|
| **User** | `~/.claude/settings.json` | 나, 모든 프로젝트 | X (내 머신) |
| **Project** | `.claude/settings.json` | 이 repo의 모든 협업자 | O (커밋) |
| **Local** | `.claude/settings.local.json` | 나, 이 repo에서만 | X (자동 gitignore) |

### 언제 어느 범위를 쓰나

- **User** — 개인 취향(테마·에디터), 모든 프로젝트 공통 도구, 인증.
- **Project** — 팀 공유 정책(permissions·hooks·MCP 서버), 표준 도구. **harness 정책의 기본 위치.**
- **Local** — 특정 프로젝트의 개인 오버라이드, 공유 전 실험, 머신별 설정.
  "don't ask again" 영구 권한 승인도 여기 저장된다.

> **harness 권장:** 팀이 공유해야 하는 규칙(커밋 정책 훅, 위험 명령 차단)은
> **Project(`.claude/settings.json`)**에 두고 커밋한다. 개인 실험은 Local에 둔다.

---

## 2. 우선순위 (같은 설정이 여러 범위에 있을 때)

높은 순 → 낮은 순:

1. **Managed** (최상위, 오버라이드 불가) — *이 repo 범위 밖, 무시*
2. **명령줄 인자** — 임시 세션 오버라이드
3. **Local** — project·user 오버라이드
4. **Project** — user 오버라이드
5. **User** (최하위) — 다른 곳에서 지정 안 할 때 적용

> 예: user가 `spinnerTipsEnabled: true`, project가 `false`면 project 값이 적용된다.

### ⚠️ 중요 예외: permissions는 병합된다

`permissions`의 `allow`/`ask`/`deny` 규칙은 오버라이드가 아니라 **모든 범위에서 병합**된다.
즉 project의 `deny`와 local의 `allow`가 함께 작동한다. harness 정책 설계 시 핵심.

---

## 3. 기능별 파일 위치 (user/project/local)

| 기능 | User | Project | Local |
|------|------|---------|-------|
| Settings | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| Subagents | `~/.claude/agents/` | `.claude/agents/` | 없음 |
| MCP servers | `~/.claude.json` | `.mcp.json` | `~/.claude.json`(프로젝트별) |
| Plugins | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| CLAUDE.md | `~/.claude/CLAUDE.md` | `CLAUDE.md` 또는 `.claude/CLAUDE.md` | `CLAUDE.local.md` |

> Windows에서 `~/.claude`는 `%USERPROFILE%\.claude`로 해석된다.
> `settings.local.json`은 git repo 루트(worktree 해석)에서 읽고 쓰므로 하위 디렉토리·
> worktree 전체를 하나의 파일이 커버한다.

---

## 4. settings.json 예시와 핵심 옵션

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

- `$schema` — 에디터 자동완성·검증 활성화(스키마는 최신 CLI보다 늦을 수 있음).
- `permissions` — 도구 접근을 `allow`/`ask`/`deny`로 통제. **범위 간 병합**.
- `env` — 모든 세션·하위 프로세스에 적용되는 환경변수. `""`로 셸 export 무효화.
- `hooks` — 수명주기 훅 등록(→ `harness-hooks` skill).

harness에 특히 관련 있는 옵션(모두 user/project/local에서 사용 가능):

| 옵션 | 용도 |
|------|------|
| `permissions.deny` | 위험 명령/파일 하드 차단 |
| `disableAllHooks` | 모든 훅·커스텀 status line 비활성화 |
| `disableSkillShellExecution` | skill/command 내 인라인 셸 실행 차단 |
| `enableAllProjectMcpServers` | 프로젝트 `.mcp.json`의 MCP 서버 자동 승인 |
| `enabledMcpjsonServers` / `disabledMcpjsonServers` | `.mcp.json` 서버 개별 승인/거부 |

### 반영 시점

- 대부분(`permissions`, `hooks`, `env` 등)은 파일 저장 시 **재시작 없이** 반영된다.
- 세션 시작 시 1회 읽는 것: `model`(중엔 `/model`), `outputStyle`(`/clear`·재시작 시).
- `/config`로 설정 UI, `/status`의 `Setting sources`로 로드된 소스 확인.

---

## 5. Managed 범위 — 무시 (기록만)

> 아래는 **참고용 기록**이다. 이 repo의 harness 구성에서는 **다루지 않는다.**

- **정의:** 조직/엔터프라이즈 레벨 설정. **최상위 우선순위**로 user/project/local/명령줄이
  오버라이드 못 한다.
- **배포 경로:** 서버 관리(claude.ai admin/게이트웨이), MDM/OS 정책(macOS plist,
  Windows 레지스트리), 파일(`managed-settings.json` + `managed-settings.d/`).
- **Managed 전용 옵션 예:** `allowedMcpServers`, `deniedMcpServers`,
  `allowManagedPermissionRulesOnly`, `blockedMarketplaces`, `claudeMd` 등.
  → 이들은 user/project/local에 써도 무시되므로 이 repo의 skill에서 사용하지 않는다.

**결론:** harness 정책은 **user / project / local** 세 범위로만 구성한다.
조직 강제가 필요하면 IT가 Managed로 배포할 사안이며 본 플러그인의 범위가 아니다.

---

## harness 구성으로 이어지는 흐름

1. `agentic-loop` skill — 어디에 개입 가능한가?
2. **이 skill** — 정책을 *어느 범위*에 둘 것인가? (user/project/local)
3. `harness-hooks` skill — 정책을 *어떻게* 강제할 것인가?

---

## 참고 링크

- 설정 (영문): https://code.claude.com/docs/en/settings
- 권한: https://code.claude.com/docs/en/permissions
- Hooks: https://code.claude.com/docs/ko/hooks
