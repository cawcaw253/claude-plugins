---
name: agentic-loop
description: >-
  Claude Code가 내부적으로 어떻게 동작하는지(agentic loop, 도구, 컨텍스트 윈도우,
  세션, 체크포인트/권한)를 설명한다. harness를 구성하기 전에 "어느 지점에 개입할 수
  있는지"를 이해하도록 돕는 기초 skill이다. 사용자가 "Claude Code 동작 원리",
  "agent loop", "에이전트 루프", "컨텍스트 관리", "Claude가 어떻게 작업하는지",
  "harness가 뭘 감싸는지" 등을 물을 때 사용한다.
---

# Claude Code 동작 원리 (Agentic Loop)

Claude Code가 내부적으로 어떻게 동작하는지 설명한다. harness(작업 범위 제한)를
설계하려면 먼저 **어느 지점에 개입할 수 있는지**를 알아야 한다.
공식 문서: https://code.claude.com/docs/en/how-claude-code-works

> Claude Code는 Claude 모델을 감싸는 **agentic harness**다. 도구·컨텍스트 관리·
> 실행 환경을 제공해 언어 모델을 유능한 코딩 에이전트로 바꾼다. harness 구성이란
> 이 harness가 제공하는 범위를 정책으로 제약하는 일이다.

---

## 1. Agentic Loop — 세 단계

작업을 받으면 Claude는 세 단계를 반복한다. 단계는 뚜렷이 나뉘지 않고 섞인다.

| 단계 | 하는 일 | 예시 도구 |
|------|---------|-----------|
| **Gather context** | 코드·상태 이해 | 파일 검색, Read, git 상태 |
| **Take action** | 변경 수행 | Edit/Write, Bash 실행 |
| **Verify results** | 결과 검증 | 테스트 실행, 재검색 |

- 루프는 요청에 따라 적응한다. 단순 질문은 context gather만, 버그 수정은 세 단계를
  여러 번 순환한다.
- 각 도구 호출 결과가 다음 결정으로 피드백된다("fix the failing tests" → 테스트 실행
  → 에러 읽기 → 소스 검색 → 수정 → 재실행).
- 사용자는 언제든 `Esc`로 중단하거나 지시를 덧붙여 방향을 바꿀 수 있다.

> **harness 관점:** 이 세 단계 각각이 도구 호출로 이뤄지므로, 훅의 `PreToolUse`/
> `PostToolUse`가 개입 지점이다. "action" 단계의 위험 도구(파괴적 Bash, 보호 파일
> 수정)를 차단하는 것이 harness의 핵심이다. → `harness-hooks` skill 참고.

---

## 2. 루프를 이루는 두 축: 모델과 도구

### 모델 (reasoning)

- Claude 모델이 코드를 이해하고 작업을 추론한다. "Claude가 결정한다"는 곧 모델의 추론이다.
- `/model`로 세션 중 전환하거나 `claude --model <name>`으로 시작한다.
  (Sonnet은 대부분의 코딩, Opus는 복잡한 설계 추론에 강함.)

### 도구 (action)

도구가 없으면 Claude는 텍스트만 반환한다. 도구가 있어야 **행동**한다.
내장 도구는 다섯 범주로 나뉜다.

| 범주 | Claude가 할 수 있는 일 |
|------|------------------------|
| **File operations** | 읽기, 편집, 생성, 이름변경/재구성 |
| **Search** | 패턴으로 파일 찾기, regex 내용 검색, 코드베이스 탐색 |
| **Execution** | 셸 명령, 서버 기동, 테스트, git |
| **Web** | 웹 검색, 문서 fetch, 에러 조회 |
| **Code intelligence** | 편집 후 타입 에러/경고 확인, 정의 이동, 참조 찾기 (플러그인 필요) |

이 외에 서브에이전트 생성·질문 등 오케스트레이션 도구가 있다.

> **확장 계층:** 내장 도구가 기초다. 그 위에 skills(→ `slash-commands` skill),
> MCP, hooks(→ `harness-hooks` skill), subagents, workflows(→ `workflows` skill)가
> 올라간다. **harness는 주로 hooks·permissions 계층에서 이 도구 사용을 제약한다.**

---

## 3. Claude가 접근하는 것

`claude`를 디렉토리에서 실행하면 접근 범위:

- **프로젝트** — 현재 디렉토리·하위 파일(그 외는 권한 필요)
- **터미널** — 사용자가 실행 가능한 모든 명령(빌드·git·패키지 매니저·스크립트)
- **git 상태** — 현재 브랜치, 미커밋 변경, 최근 커밋 이력
- **CLAUDE.md** — 매 세션 로드되는 프로젝트 지침
- **Auto memory** — 자동 저장 학습(MEMORY.md 앞부분 로드)
- **설정한 확장** — MCP 서버, skills, subagents 등

> harness가 제약해야 하는 "공격면"이 곧 이 접근 범위다. 특히 **터미널(Bash)**과
> **파일 수정(Edit/Write)**이 가장 넓어 우선 통제 대상이다.

---

## 4. 컨텍스트 윈도우 (harness 설계에 중요)

컨텍스트 윈도우는 대화 이력, 파일 내용, 명령 출력, CLAUDE.md, auto memory,
로드된 skill, 시스템 지침을 담는다. 채워지면 Claude가 자동 압축(compact)한다.

- **자동 압축 시 초기 지침이 유실될 수 있다.** → 영구 규칙은 대화가 아니라
  **CLAUDE.md에 둔다.** (이것이 커밋 규칙 등을 CLAUDE.md로 강제하는 이유다.)
- 압축 순서: 오래된 도구 출력 먼저 제거 → 필요 시 대화 요약. 요청·핵심 코드는 보존.
- `/context`로 사용량 확인, `/compact focus on ...`로 보존 대상 지정.
- **Skills는 on-demand 로드** — 세션 시작엔 설명만, 사용 시 전체 로드.
  `disable-model-invocation: true` / 설정의 `skillOverrides`로 설명도 숨길 수 있다.
- **Subagents는 별도 컨텍스트** — 메인 대화를 오염시키지 않고 요약만 반환.

---

## 5. 세션과 안전장치

### 세션

- 대화는 `~/.claude/projects/` 아래 JSONL로 저장 → rewind/resume/fork 가능.
- **세션은 독립적**이다. 새 세션은 fresh 컨텍스트로 시작(이전 대화 미포함).
  → 지속 정보는 auto memory(→ `agent-memory` skill) 또는 CLAUDE.md(→ `project-rules` skill)로.
- `--continue`/`--resume`은 같은 세션 ID에 이어붙임, `--fork-session`/`/branch`는 복제.

### 체크포인트 & 권한 (harness의 안전 축)

- **모든 파일 편집은 되돌릴 수 있다** — 편집 전 스냅샷, `Esc` 두 번으로 rewind.
  단 파일 변경만 커버한다. **원격 부작용(DB·API·배포)은 되돌릴 수 없어** Claude가
  실행 전 확인을 요구한다. → harness가 하드 차단해야 할 대상.
- **권한 모드** (`Shift+Tab`로 순환):

  | 모드 | 동작 |
  |------|------|
  | Manual | 파일 편집·셸 명령 전 항상 질문 |
  | Accept edits | 편집·일반 파일시스템 명령은 무질문, 그 외 질문 |
  | Plan | 탐색·계획만, 소스 미수정 |
  | Auto | 백그라운드 안전 검사와 함께 모든 행동 평가 |

- `.claude/settings.json`으로 특정 명령을 미리 허용/거부할 수 있다(조직→개인 범위).
  → 상세는 `settings-scopes` skill, 하드 정책은 `harness-hooks` skill 참고.

---

## harness 구성으로 이어지는 흐름

**기초**
1. **이 skill** — 어디에 개입 가능한가? (loop 단계·도구·접근 범위 파악)
2. **`settings-scopes` skill** — 정책을 *어디에* 둘 것인가? (user/project/local)
3. **`harness-hooks` skill** — 정책을 *어떻게* 강제할 것인가? (훅으로 검사·차단·수정)

**확장 계층 (무엇을 제약·구성하는가)**
- **`project-rules` skill** — CLAUDE.md·`.claude/rules/`로 지침 구성
- **`slash-commands` skill** — 커스텀 커맨드(= skill) 작성·접근 제어
- **`workflows` skill** — 다수 subagent 오케스트레이션과 비활성화
- **`agent-memory` skill** — 자동 메모리 통제

---

## 참고 링크

- 동작 원리 (영문): https://code.claude.com/docs/en/how-claude-code-works
- 설정: https://code.claude.com/docs/en/settings
- Hooks: https://code.claude.com/docs/ko/hooks
