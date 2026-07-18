---
name: workflows
description: >-
  Claude Code의 dynamic workflows(다수 subagent를 스크립트로 오케스트레이션)를 안내한다.
  언제 workflow를 쓰는지(subagent/skill/agent team과 비교), 실행·승인 방법,
  ultracode 키워드, 저장 위치(.claude/workflows), 스크립트 구조(meta·agent·pipeline),
  실행 제약, 비활성화 설정을 다룬다. 사용자가 "workflow", "여러 에이전트 오케스트레이션",
  "대규모 마이그레이션/감사", "ultracode", "deep-research" 등을 물을 때 사용한다.
---

# Dynamic Workflows (subagent 오케스트레이션)

다수의 subagent를 **스크립트**로 조율하는 dynamic workflows를 안내한다.
공식 문서: https://code.claude.com/docs/en/workflows

> Dynamic workflow는 Claude가 작성하고 런타임이 백그라운드에서 실행하는 JavaScript
> 스크립트다. 한 대화가 조율하기 어려운 규모(수십~수백 에이전트)의 작업이나,
> 오케스트레이션 자체를 읽고 재실행 가능한 스크립트로 남기고 싶을 때 쓴다.
> Claude Code v2.1.154+ 및 유료 플랜 필요.

---

## 1. 언제 workflow를 쓰나 (subagent/skill/agent team과 비교)

핵심 차이는 **누가 계획을 쥐고 있는가**다.

| | Subagents | Skills | Agent teams | **Workflows** |
|---|---|---|---|---|
| 정체 | Claude가 띄우는 워커 | Claude가 따르는 지침 | 리드가 감독하는 세션들 | **런타임이 실행하는 스크립트** |
| 다음 실행 결정 | Claude(턴별) | Claude(프롬프트대로) | 리드(턴별) | **스크립트** |
| 중간 결과 저장 | Claude 컨텍스트 | Claude 컨텍스트 | 공유 태스크 목록 | **스크립트 변수** |
| 재사용 대상 | 워커 정의 | 지침 | 팀 정의 | **오케스트레이션 자체** |
| 규모 | 턴당 소수 | 동일 | 소수 장기 실행 | **런당 수십~수백** |

workflow는 계획을 코드로 옮겨 **반복 가능한 품질 패턴**(에이전트 간 적대적 상호 검증,
여러 각도에서 초안 작성 후 비교 등)을 적용할 수 있다. 중간 결과가 스크립트 변수에
남아 Claude 컨텍스트에는 최종 답만 남는다.

**적합한 작업:** 코드베이스 전체 버그 스윕, 500파일 마이그레이션, 교차 검증 리서치,
여러 각도로 초안을 잡아 비교하는 어려운 계획.

---

## 2. 실행 방법

- **번들 workflow:** `/deep-research <질문>` — 여러 각도로 웹 검색·교차검증 후 인용 리포트.
- **직접 요청:** 프롬프트에 `ultracode` 키워드 포함 또는 "use a workflow"라고 요청 →
  Claude가 해당 작업용 스크립트를 작성. (내가 입력한 프롬프트에서만 opt-in으로 동작하며,
  `-p`·스케줄·webhook 경로에서는 트리거되지 않는다.)
- **ultracode 모드:** `/effort ultracode` → 세션의 모든 substantive 작업에 workflow 계획.
  토큰·시간이 늘어난다. 새 세션에서 리셋.
- `/workflows`로 진행 상황(단계·에이전트 수·토큰·시간) 확인, 저장한 것은 `/이름`으로 실행.

### 승인 (permission mode별)

| 모드 | 프롬프트 시점 |
|------|--------------|
| Default / accept edits | 매 실행("이 workflow 다시 묻지 않기" 선택 시 생략) |
| Auto | 첫 실행만(ultracode 켜지면 생략) |
| Bypass / `-p` / SDK | 없음(즉시 시작) |

> **harness 관점:** launch 프롬프트는 시작만 통제한다. workflow가 띄우는 subagent는
> 세션 모드와 무관하게 항상 **`acceptEdits` 모드**로 돌고 **tool allowlist를 상속**한다.
> 파일 편집은 자동 승인된다. allowlist에 없는 셸/웹/MCP 호출은 런 중 프롬프트가 뜰 수 있다 —
> 긴 런 전에 필요한 명령을 allowlist에 추가한다.

---

## 3. 저장 위치와 재사용

`/workflows`에서 런 선택 후 `s`로 스크립트를 커맨드로 저장.

| 위치 | 공유 |
|------|------|
| `.claude/workflows/` (프로젝트) | 팀(커밋) |
| `~/.claude/workflows/` (홈) | 나(모든 프로젝트) |

- 저장 후 `/이름`으로 실행. 같은 이름이면 프로젝트 것이 우선.
- `args`로 입력 전달(스크립트에서 전역 `args`로 읽음) — 리서치 질문·경로 목록 등.

---

## 4. 저장된 스크립트 구조

`meta` 블록 + 본문(top-level await의 일반 JavaScript). 보통 직접 편집할 필요 없다.

```javascript
export const meta = {
  name: 'audit-routes',
  description: 'Audit every route handler for missing auth checks',
}

const found = await agent('List every .ts file under src/routes/.', {
  schema: { type: 'object', required: ['files'],
    properties: { files: { type: 'array', items: { type: 'string' } } } },
})

const audits = await pipeline(found.files, file =>
  agent(`Audit ${file} for missing authentication checks.`, { label: file }),
)

return audits.filter(Boolean)
```

- `agent(prompt, opts)` — subagent 하나 실행(`schema`로 구조화 출력).
- `pipeline(items, ...stages)` — 항목마다 스테이지 체인 실행(스테이지 간 배리어 없음).
- `parallel(thunks)` — 배리어. 전부 완료까지 대기.

---

## 5. 실행 제약

| 제약 | 이유 |
|------|------|
| 런 중 사용자 입력 불가 | 에이전트 권한 프롬프트만 일시정지 가능(단계별 승인은 각 단계를 별도 workflow로) |
| 스크립트 자체는 파일·셸 직접 접근 불가 | 에이전트가 실행하고 스크립트는 조율만 |
| 동시 에이전트 최대 16(코어 적으면 ↓) | 로컬 자원 제한 |
| 런당 총 1,000 에이전트 | 폭주 방지 |

- 같은 세션 내 **resume 가능**(완료 에이전트는 캐시 결과 반환). Claude Code 종료 시엔 새로 시작.
- 대규모 경고: 에이전트 25개 초과 또는 예상 토큰 150만 초과 시 `Large workflow` 경고(권고).
- 비용: 여러 에이전트를 띄우므로 대화보다 토큰↑. 큰 작업은 일부(디렉토리 하나)로 먼저 가늠.

---

## 6. 비활성화 (harness)

| 방법 | 범위 |
|------|------|
| `/config`의 Dynamic workflows 토글 | 세션 지속 |
| `settings.json`의 `"disableWorkflows": true` | 세션 지속 |
| 환경변수 `CLAUDE_CODE_DISABLE_WORKFLOWS=1` | 시작 시 |

비활성화하면 번들 workflow 커맨드가 사라지고 `ultracode` 키워드도 트리거하지 않는다.
`/config`의 **Dynamic workflow size**로 Claude가 작성하는 스크립트 규모를 제한할 수도 있다
(small<5 / medium<15 / large<50 에이전트, 권고값).

> 조직 전체 비활성화는 managed settings 사안 → 이 repo 범위 밖(무시).

---

## 참고 링크

- Workflows (영문): https://code.claude.com/docs/en/workflows
- 관련 skill: `slash-commands`(저장된 workflow = 커맨드), `settings-scopes`, `agentic-loop`
