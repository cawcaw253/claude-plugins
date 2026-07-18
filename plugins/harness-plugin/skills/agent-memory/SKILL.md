---
name: agent-memory
description: >-
  Claude Code의 자동 메모리(auto memory)와 MEMORY.md를 안내한다. CLAUDE.md와의 차이,
  저장 위치(~/.claude/projects/<project>/memory/), 로드 규칙(200줄/25KB), 활성화·비활성화,
  감사·편집(/memory), autoMemoryDirectory/autoMemoryEnabled 설정을 다룬다.
  사용자가 "자동 메모리", "MEMORY.md", "Claude가 기억하는 내용", "메모리 끄기",
  "기억한 것 확인/편집", "auto memory 위치" 등을 물을 때 사용한다.
---

# 자동 메모리 (Auto Memory & MEMORY.md)

Claude가 세션 간 학습을 스스로 축적하는 **자동 메모리**를 안내한다.
공식 문서: https://code.claude.com/docs/ko/memory

> 각 세션은 fresh 컨텍스트로 시작한다. 두 메커니즘이 세션 간 지식을 전달한다:
> **CLAUDE.md**(사용자가 쓰는 지침 → `project-rules` skill)와
> **자동 메모리**(Claude가 스스로 쓰는 학습 노트, 이 skill).

---

## 1. CLAUDE.md vs 자동 메모리

둘 다 모든 대화 시작 시 로드되고, 둘 다 **강제가 아닌 컨텍스트**다.

| | CLAUDE.md | 자동 메모리 |
|---|---|---|
| 작성자 | 사용자 | Claude |
| 내용 | 지침·규칙 | 학습·패턴 |
| 범위 | 프로젝트/사용자/조직 | 저장소당(worktree 공유) |
| 로드 | 모든 세션(전체) | 모든 세션(MEMORY.md 앞 200줄/25KB) |
| 용도 | 코딩 표준·워크플로우·아키텍처 | 빌드 명령·디버깅 인사이트·발견한 선호도 |

> 작업 차단이 필요하면 어느 쪽도 아니라 **PreToolUse 훅**(`harness-hooks` skill)을 쓴다.
> subagent도 자기 자동 메모리를 가질 수 있다(subagent 설정).

---

## 2. 저장 위치

프로젝트마다 `~/.claude/projects/<project>/memory/` 디렉토리를 가진다.
`<project>`는 git 저장소에서 파생 → 같은 저장소의 모든 worktree·하위 디렉토리가 **공유**.
자동 메모리는 **머신 로컬**이며 머신·클라우드 간 공유되지 않는다.

```text
~/.claude/projects/<project>/memory/
├── MEMORY.md          # 간결한 인덱스, 모든 세션에 로드
├── debugging.md       # 주제 파일(필요 시 로드)
├── api-conventions.md
└── ...
```

다른 위치에 저장하려면 `settings.json`의 `autoMemoryDirectory`(절대경로 또는 `~/`):

```json
{ "autoMemoryDirectory": "~/my-custom-memory-dir" }
```

> 프로젝트/로컬 설정에서 지정하면 **워크스페이스 신뢰 수락 후**에만 적용된다(hook과 동일 게이트).

---

## 3. 작동 방식

- **MEMORY.md 앞 200줄 또는 25KB**(먼저 오는 것)만 모든 대화 시작 시 로드. 초과분은 미로드.
  → Claude는 자세한 노트를 주제 파일로 옮겨 MEMORY.md를 간결히 유지한다.
- 이 제한은 **MEMORY.md에만** 적용(CLAUDE.md는 길이 무관 전체 로드, 단 짧을수록 준수↑).
- `debugging.md` 등 주제 파일은 시작 시 로드 안 됨 → 필요 시 파일 도구로 읽는다.
- UI에 "Writing memory"/"Recalled memory"가 보이면 memory 디렉토리를 읽고/쓰는 중이다.

---

## 4. 활성화·비활성화 (harness)

기본 **켜짐**. 토글:

| 방법 | 효과 |
|------|------|
| `/memory`의 자동 메모리 토글 | 세션에서 on/off |
| `settings.json`의 `"autoMemoryEnabled": false` | 비활성화 |
| 환경변수 `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` | 비활성화 |

> **harness 관점:** 민감 정보가 자동 메모리에 남는 게 우려되면 `autoMemoryEnabled: false`로
> 끄거나 `autoMemoryDirectory`로 위치를 통제한다. 자동 메모리는 강제가 아닌 컨텍스트이므로
> 정책 강제와는 무관하다.

---

## 5. 감사·편집

- 자동 메모리 파일은 언제든 편집·삭제 가능한 일반 마크다운.
- `/memory` — 로드된 CLAUDE.md·CLAUDE.local.md·rules 목록 표시, 자동 메모리 on/off,
  메모리 폴더 열기. 파일 선택 시 편집기로 연다.
- "X를 기억해"라고 하면 Claude가 **자동 메모리**에 저장한다. 대신 CLAUDE.md에 넣으려면
  "이걸 CLAUDE.md에 추가해"라고 명시하거나 `/memory`로 직접 편집한다.
- 저장된 내용을 모르면 `/memory` → 자동 메모리 폴더에서 확인.

---

## 6. 이 플러그인 저장소의 실제 사용

이 repo에는 `~/.claude/projects/-...-claude-plugins/memory/`에 자동 메모리가 존재한다.
harness 구성 시 "무엇을 기억할지"와 "무엇을 CLAUDE.md 규칙으로 강제할지"를 구분한다:

- **자동 메모리** — Claude가 발견한 빌드 명령·선호도(변동 가능한 학습).
- **CLAUDE.md** — 팀이 반드시 지켜야 하는 규칙(예: 이 repo의 커밋 규칙) → `project-rules` skill.
- **hook** — 규칙조차 강제로 만들 때 → `harness-hooks` skill.

---

## 참고 링크

- 메모리 (한국어): https://code.claude.com/docs/ko/memory
- 관련 skill: `project-rules`(CLAUDE.md), `settings-scopes`, `harness-hooks`
