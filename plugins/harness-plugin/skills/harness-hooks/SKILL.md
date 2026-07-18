---
name: harness-hooks
description: >-
  Claude Code hooks를 사용해 AI 작업 범위를 제한하는 harness를 구성하도록 돕는다.
  훅 수명주기 이벤트, matcher/if 조건 구성, 종료 코드·JSON 출력 제어, settings.json
  스키마를 안내하고 실제 훅 스크립트를 작성한다. 사용자가 "훅으로 특정 명령 차단",
  "특정 파일 수정 시에만 훅 실행", "커밋/푸시 전 검증", "hook 수명주기", "harness 제한"
  등을 요청할 때 사용한다.
---

# Harness Hooks 구성 가이드

Claude Code의 **hooks**로 AI 작업 범위를 제한하는 harness를 구성한다.
공식 문서: https://code.claude.com/docs/ko/hooks

훅은 세션 흐름의 특정 시점에 스크립트를 실행해 도구 호출을 **검사·차단·수정**한다.
permissions로 표현하기 어려운 조건부 정책(특정 서브명령, 특정 파일 확장자, 브랜치 조건 등)을
코드로 강제할 때 사용한다.

---

## 1단계: 어떤 시점에 개입할지 정한다 (수명주기 이벤트)

훅은 세 가지 주기로 발생한다.

- **세션당 1회:** `SessionStart`, `SessionEnd`
- **턴당 1회:** `UserPromptSubmit`, `Stop`, `StopFailure`
- **도구 호출마다:** `PreToolUse`, `PostToolUse`

harness(작업 범위 제한)에 가장 자주 쓰는 이벤트:

| 이벤트 | 발생 시점 | exit 2로 차단? | 주 용도 |
|--------|-----------|:--------------:|---------|
| `PreToolUse` | 도구 실행 **전** | O (도구 차단) | 위험 명령/파일 수정 차단 |
| `PostToolUse` | 도구 성공 **후** | X (Claude에 stderr 전달) | 포맷팅, 사후 검증, 피드백 |
| `UserPromptSubmit` | 프롬프트 제출 시 | O (프롬프트 차단) | 금지어 필터, 컨텍스트 주입 |
| `PermissionRequest` | 권한 대화창 표시 시 | O (권한 거부) | 자동 승인/거부 정책 |
| `Stop` | Claude 응답 종료 시 | O (종료 방지) | "테스트 통과 전 종료 금지" |
| `SessionStart` | 세션 시작/재개 | X (컨텍스트만) | 브랜치·이슈 정보 주입 |

> 전체 이벤트 목록은 문서의 "Hook Lifecycle Events" 표 참고:
> https://code.claude.com/docs/ko/hooks

---

## 2단계: 대상을 좁힌다 (matcher + if)

훅 실행 대상은 두 단계로 좁힌다.

### matcher — 도구 이름으로 필터

| matcher 값 | 해석 | 예시 |
|------------|------|------|
| `"*"`, `""`, 생략 | 전체 매칭 | 모든 도구 |
| 문자/숫자/`_`/`-`/공백/`,`/`\|` 만 | 정확한 문자열 또는 목록 | `Bash`, `Edit\|Write` |
| 그 외 문자 포함 | JavaScript 정규식 (앵커 없음) | `^Notebook`, `mcp__memory__.*` |

- 정규식은 **부분 일치**한다. `Edit.*`는 `Edit`와 `NotebookEdit` 둘 다 매칭.
  정확히 하려면 `^Edit$`처럼 앵커를 쓴다.
- MCP 도구는 `mcp__<server>__<tool>` 형식. 예: `mcp__memory__.*` (`.*` 필수).

### if — 도구 인자까지 함께 필터 (핵심)

`if` 필드는 **permission rule 문법**으로 도구 이름 + 인자를 함께 검사한다.
`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`에서만 평가된다.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git push *)",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/check-push.sh"
          }
        ]
      }
    ]
  }
}
```

- `"Bash(git *)"` — `git` 서브명령에만 실행
- `"Edit(*.ts)"` — TypeScript 파일 수정 시에만 실행
- `if`에는 규칙을 **하나만** 넣는다 (`&&`/`||` 불가). 조건이 여러 개면 핸들러를 나눈다.
- Bash `if`는 앞쪽 `VAR=value` 할당을 제거하고, `$()`·백틱 내부 서브명령도 검사한다.
- `if`는 best-effort(파싱 실패 시 통과)다. **하드 차단은 permissions를 함께 쓴다.**

이것이 "If 등을 사용하여 특정 명령의 일부 요청에 대해서만 훅을 동작"시키는 방법이다.

---

## 3단계: 입력을 읽는다 (stdin JSON)

훅은 stdin으로 JSON을 받는다. 공통 필드 일부:

| 필드 | 설명 |
|------|------|
| `session_id` | 세션 식별자 |
| `cwd` | 현재 작업 디렉토리 |
| `permission_mode` | `default`/`plan`/`acceptEdits`/`auto`/`bypassPermissions` 등 |
| `hook_event_name` | 발생한 이벤트 이름 |
| `tool_name` | (도구 이벤트) 도구 이름 |
| `tool_input` | (도구 이벤트) 도구 인자 객체 |

`tool_input` 주요 필드 (PreToolUse):

- **Bash:** `command`, `description`, `timeout`, `run_in_background`
- **Write:** `file_path`, `content`
- **Edit:** `file_path`, `old_string`, `new_string`, `replace_all`
- **Read:** `file_path`, `offset`, `limit`

스크립트에서 `jq`로 추출하는 예:

```bash
command=$(jq -r '.tool_input.command' < /dev/stdin)
file=$(jq -r '.tool_input.file_path' < /dev/stdin)
```

---

## 4단계: 결과를 돌려준다 (종료 코드 또는 JSON)

**한 훅에서 종료 코드 방식과 JSON 방식 중 하나만 쓴다** (exit 2일 때 JSON은 무시됨).

### 방법 A — 종료 코드 (간단, 권장 시작점)

| 종료 코드 | 의미 |
|:---------:|------|
| `0` | 성공. stdout을 JSON 출력으로 파싱 |
| `2` | **차단**. stdout 무시, **stderr가 Claude에 오류로 전달** |
| 기타 | 비차단 오류. 계속 진행, stderr 첫 줄만 표시 |

> 주의: `exit 1`은 비차단이다. 정책 강제는 반드시 `exit 2`.

```bash
#!/usr/bin/env bash
command=$(jq -r '.tool_input.command' < /dev/stdin)
if [[ "$command" == rm* ]]; then
  echo "차단: rm 명령은 허용되지 않습니다" >&2
  exit 2
fi
exit 0
```

### 방법 B — JSON 출력 (세밀한 제어)

**공통 필드 (모든 이벤트):**

| 필드 | 설명 |
|------|------|
| `continue` | `false`면 Claude 완전 중단 (이벤트별 결정보다 우선) |
| `stopReason` | `continue:false`일 때 사용자에게 표시 |
| `systemMessage` | 사용자에게 경고 표시 |
| `suppressOutput` | 디버그 로그에서 stdout 숨김 |

**PreToolUse 전용 — permissionDecision:**

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "데이터베이스 쓰기는 허용되지 않습니다"
  }
}
```

`permissionDecision`: `allow` / `deny` / `ask` / `defer`.
`updatedInput`으로 도구 입력을 재작성할 수도 있다.

**top-level decision — block (UserPromptSubmit, PostToolUse, Stop 등):**

```json
{ "decision": "block", "reason": "테스트 통과 후 진행하세요" }
```

**컨텍스트 주입 (차단 아님) — additionalContext:**

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "이 파일은 자동 생성됩니다. src/schema.ts를 수정하세요."
  }
}
```

---

## 5단계: 등록하고 확인한다

훅은 settings 파일에 등록한다 (범위별 위치):

| 위치 | 범위 | 공유 |
|------|------|------|
| `~/.claude/settings.json` | 모든 프로젝트 | X (내 머신) |
| `.claude/settings.json` | 단일 프로젝트 | O (커밋) |
| `.claude/settings.local.json` | 단일 프로젝트 | X (gitignore) |
| Managed policy | 조직 전체 | O (관리자 강제) |

- 경로 플레이스홀더: 프로젝트의 `.claude/hooks/`에 두면 `${CLAUDE_PROJECT_DIR}`,
  플러그인으로 배포하면 `${CLAUDE_PLUGIN_ROOT}`를 쓴다.
- 스크립트에 실행 권한 부여: `chmod +x`.
- `/hooks` 명령으로 등록된 훅을 확인(읽기 전용).
- 전체 임시 비활성화: `"disableAllHooks": true`.

---

## Handler 타입

`command` 외에도 다음이 있다 (모두 `type`, `if`, `timeout`, `once` 공통 지원):

- **`command`** — 셸 명령 (stdin JSON, 종료 코드/stdout으로 결과)
- **`http`** — URL로 JSON POST
- **`mcp_tool`** — MCP 서버 도구 호출
- **`prompt`** — Claude 모델에 단일 턴 프롬프트 (yes/no 결정)
- **`agent`** — 서브에이전트 생성 (실험적)

`args`를 지정하면 **exec 형식**(셸 없이 실행)이 되어 셸 토큰화·인젝션을 피한다:

```json
{ "type": "command", "command": "node", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/lint.js"] }
```

---

## harness 구성 레시피 (자주 쓰는 패턴)

1. **특정 서브명령만 차단** — `matcher: "Bash"` + `if: "Bash(git push *)"` + PreToolUse exit 2
2. **특정 확장자 수정 시 검증** — `matcher: "Edit|Write"` + `if: "Edit(*.ts)"` + 린트 스크립트
3. **자동 생성 파일 보호** — PreToolUse에서 경로 확인 후 `permissionDecision: "deny"`
4. **커밋/저장 후 자동 포맷** — PostToolUse + `if: "Edit(*)"` (차단 아님, 포맷만)
5. **테스트 통과 전 종료 금지** — Stop 이벤트 + `decision: "block"`
6. **세션 시작 시 브랜치 정보 주입** — SessionStart + `additionalContext`
7. **프롬프트 금지어 필터** — UserPromptSubmit + `decision: "block"`

> `if`는 fail-open이므로 절대 금지선은 permissions의 `deny`와 병행한다.

---

## 참고 링크

- 공식 hooks 문서 (한국어): https://code.claude.com/docs/ko/hooks
- 플러그인/마켓플레이스 문서: https://code.claude.com/docs/ko/plugins ,
  https://code.claude.com/docs/ko/plugin-marketplaces
