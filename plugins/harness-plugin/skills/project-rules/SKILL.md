---
name: project-rules
description: >-
  CLAUDE.md와 .claude/rules/로 프로젝트 규칙·지침을 구성하는 방법을 안내한다.
  파일 위치·로드 순서, path-specific rules(paths frontmatter), @import, 효과적인
  지침 작성, "규칙은 강제가 아닌 컨텍스트"라는 한계와 hooks 병행을 다룬다.
  사용자가 "CLAUDE.md 작성", "프로젝트 규칙", ".claude/rules", "특정 파일에만
  규칙 적용", "지침을 안 지킨다", "커밋 규칙 강제" 등을 물을 때 사용한다.
---

# 프로젝트 규칙 (CLAUDE.md & .claude/rules/)

Claude에 지속적인 지침을 주는 방법을 안내한다.
공식 문서: https://code.claude.com/docs/ko/memory

> ⚠️ **핵심 한계:** CLAUDE.md와 rules는 시스템 프롬프트가 아니라 **컨텍스트**로 전달된다.
> Claude는 이를 읽고 따르려 하지만 **강제되지 않는다.** 커밋 전·파일 편집 후처럼
> 반드시 실행돼야 하는 정책은 `harness-hooks` skill의 `PreToolUse` 훅으로 강제한다.
> 규칙은 안내, 훅은 강제 — 둘을 병행한다.

---

## 1. CLAUDE.md 위치와 로드 순서

여러 위치에 둘 수 있고, **넓은 범위 → 좁은 범위** 순으로 로드되어 뒤에 온 것이 더 가깝다.
(모두 서로를 덮어쓰지 않고 컨텍스트에 **연결**된다.)

| 범위 | 위치 | 공유 |
|------|------|:----:|
| 사용자 | `~/.claude/CLAUDE.md` | 나(모든 프로젝트) |
| 프로젝트 | `./CLAUDE.md` 또는 `./.claude/CLAUDE.md` | 팀(커밋) |
| 로컬 | `./CLAUDE.local.md` | 나(이 프로젝트, gitignore) |

- 작업 디렉토리 **위쪽** 계층의 CLAUDE.md는 시작 시 전체 로드. 아래쪽 하위 디렉토리
  파일은 Claude가 그 디렉토리 파일을 읽을 때 로드된다.
- 프로젝트 루트 CLAUDE.md는 `/compact` 후 디스크에서 다시 읽혀 **재주입**된다
  (하위 디렉토리 중첩 CLAUDE.md는 자동 재주입 안 됨).
- `/init`으로 시작 CLAUDE.md 자동 생성, `/memory`로 로드된 파일 확인·편집.

> **harness 관점:** 팀 공유 규칙(커밋 규칙 등)은 **프로젝트 CLAUDE.md**에 커밋한다.
> 이 repo가 커밋 규칙을 `CLAUDE.md`에 둔 것이 그 예다.

---

## 2. 효과적인 지침 작성

컨텍스트를 소비하고 준수율에 영향을 주므로 **구체적·간결·구조적**으로 쓴다.

- **크기:** 파일당 200줄 이하 목표. 길수록 컨텍스트 소비↑·준수율↓.
- **구조:** 마크다운 헤더·불릿으로 그룹화.
- **구체성:** 검증 가능하게. "제대로 포맷" ❌ → "2칸 들여쓰기" ✅ /
  "테스트하라" ❌ → "커밋 전 `npm test` 실행" ✅
- **일관성:** 충돌하는 규칙이 있으면 Claude가 임의 선택한다. 주기적으로 정리.
- HTML 주석(`<!-- ... -->`)은 컨텍스트 주입 전 제거되어 토큰 미소비(유지보수 노트용).

---

## 3. `.claude/rules/` — 규칙을 파일로 분리

대규모 프로젝트에서 지침을 주제별 파일로 나눈다. 모듈식이라 팀 유지보수가 쉽다.

```text
.claude/
├── CLAUDE.md          # 주 지침
└── rules/
    ├── code-style.md
    ├── testing.md
    └── security.md
```

- `paths` frontmatter가 **없는** 규칙 → `.claude/CLAUDE.md`와 같은 우선순위로 시작 시 로드.
- `~/.claude/rules/`는 사용자 수준(모든 프로젝트), 프로젝트 규칙보다 먼저 로드.
- 심볼릭 링크로 프로젝트 간 공유 가능.

### Path-specific rules (경로 범위 규칙)

`paths`로 특정 파일에서 작업할 때만 로드 → 노이즈·컨텍스트 절약.

```markdown
---
paths:
  - "src/api/**/*.{ts,tsx}"
  - "lib/**/*.ts"
---

# API 개발 규칙
- 모든 엔드포인트는 입력 검증 포함
- 표준 오류 응답 형식 사용
```

| 패턴 | 일치 |
|------|------|
| `**/*.ts` | 모든 TS 파일 |
| `src/**/*` | `src/` 아래 전부 |
| `*.md` | 루트의 md |

> 경로 범위 규칙은 **파일을 읽을 때** 트리거된다(모든 도구 사용 시가 아님).
> 항상 필요하진 않은 작업별 절차는 규칙보다 **skill**(`slash-commands` skill 참고)이 낫다.

---

## 4. @import로 파일 가져오기

CLAUDE.md는 `@path/to/file` 구문으로 다른 파일을 확장 포함한다(최대 4홉 재귀).

```text
프로젝트 개요는 @README, npm 명령은 @package.json 참고.

# 추가 지침
- git 워크플로우 @docs/git-instructions.md
- 개인 지침 @~/.claude/my-project-instructions.md
```

- 상대 경로는 **가져오는 파일 기준**으로 해석.
- 코드 스팬/펜스 안의 `@`는 무시된다(`` `@README` ``는 리터럴).
- ⚠️ import한 파일도 **시작 시 컨텍스트에 로드**되므로 토큰을 줄이진 못한다.
  토큰 절약이 목적이면 path-specific rules나 skill을 쓴다.
- `AGENTS.md`는 Claude가 직접 읽지 않는다 → `@AGENTS.md`로 import하거나 심볼릭 링크.

---

## 5. "안 지킨다" 문제 해결

1. `/memory`로 파일이 실제 **로드**됐는지 확인(목록에 없으면 Claude가 못 봄).
2. 지침을 더 **구체적**으로.
3. 파일 간 **충돌** 제거.
4. 그래도 반드시 지켜야 하면 → **hook으로 강제**(`harness-hooks` skill).
   `--append-system-prompt`는 스크립트/자동화에 적합.

> 규칙(CLAUDE.md/rules) = 행동 형성, hook = 하드 강제. `설정(permissions.deny)` = 도구 차단.
> 세 층을 목적에 맞게 나눠 쓴다.

---

## Managed(조직 레벨) — 무시

> 조직은 관리 정책 위치의 CLAUDE.md나 `managed-settings.json`의 `claudeMd` 키로
> 조직 전체 지침을 강제 배포할 수 있다. **이 repo의 harness 범위 밖이므로 다루지 않는다.**
> 개별 개발자는 user/project/local CLAUDE.md만 사용한다.

---

## 참고 링크

- 메모리 (한국어): https://code.claude.com/docs/ko/memory
- Hooks: https://code.claude.com/docs/ko/hooks
- 관련 skill: `agent-memory`(자동 메모리), `slash-commands`, `harness-hooks`
