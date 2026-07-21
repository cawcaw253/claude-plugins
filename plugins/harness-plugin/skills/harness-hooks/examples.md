# Hooks 실전 예시 모음

실제 harness 구성에서 검증된 hooks 패턴이다. 각 예시는 "무엇을 강제/주입하는가",
"어떤 출력 방식을 쓰는가", "빠지기 쉬운 함정"을 함께 담는다.
(출처: 운영 중인 agentic-development harness의 플러그인 번들 hooks)

## 이벤트별 역할 한눈에 보기

| 이벤트 | 역할 | 차단 가능? | 예시 |
|--------|------|:---:|------|
| `SessionStart` | 세션 시작 시 상태 주입 | X | 활성 모드·프로젝트 메모리·커맨드 목록 |
| `UserPromptSubmit` | 프롬프트마다 검사·주입 | O | 키워드 → slash command 제안, 예산 경고 |
| `PreToolUse` | 도구 실행 **전** 정책 강제 | O | 시크릿 파일 쓰기 차단 |
| `PostToolUse` | 도구 성공 **후** 기록·피드백 | X | 감사 로그(JSON-L) + 변경성 호출 리마인드 |
| `Stop` | 턴 종료 방지 | O | phase gate 미통과 시 종료 차단 |
| `StopFailure` | 실패한 턴 알림 | X (금지) | 경고만 — 차단하면 세션이 루프에 갇힘 |

---

## 예시 1: SessionStart — 프로젝트 상태를 컨텍스트로 주입

세션이 시작될 때 프로젝트의 상태 파일들을 읽어 `additionalContext`로 주입한다.
모델이 매 세션 "현재 활성 모드, 열린 인시던트, 예산 상태"를 알고 시작한다.

```bash
#!/usr/bin/env bash
set -euo pipefail

# 킬 스위치 — harness 훅에는 항상 끄는 방법을 마련한다
[[ "${MY_DISABLE_HOOK:-0}" == "1" ]] && exit 0

# CLAUDE_PROJECT_DIR은 Claude Code가 주입. 폴백을 두면 로컬 테스트도 가능
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

CTX=""
if [[ -f "$PROJ_DIR/.state/active-mode" ]]; then
  CTX+="Active mode: $(cat "$PROJ_DIR/.state/active-mode")"$'\n'
fi

# 핵심: 파일 내용이 컨텍스트로 들어가므로 반드시 진짜 JSON 인코더를 쓴다.
# 셸 문자열 보간으로 JSON을 조립하면 따옴표/개행이 든 파일이 JSON을 깨뜨리고
# 조작된 상태 파일이 임의 키를 주입할 수 있다.
jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
```

**함정**: CC 2.x에서 `{additionalContext: "..."}`만 내보내면 조용히 무시된다.
반드시 `hookSpecificOutput.hookEventName`을 포함한 형태로 감싼다.

---

## 예시 2: UserPromptSubmit — 키워드 트리거로 워크플로우 유도

매 프롬프트를 검사해 카탈로그(`triggers.json`)의 키워드가 나오면
관련 slash command를 컨텍스트로 제안한다. 사용자가 커맨드 이름을 몰라도
"릴리즈 진행해줘"라고 치면 모델이 `/release-flow`를 찾아 실행하게 된다.

```bash
#!/usr/bin/env bash
set -euo pipefail
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

INPUT=$(cat)                                   # stdin: {"prompt": "...", ...}
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' | tr '[:upper:]' '[:lower:]')

# 단어 경계 매칭 — "release"가 "released"/"prerelease"에 발화하지 않게
if echo "$PROMPT" | grep -qw "release"; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: "Trigger detected: release\nSuggested command: /release-flow\nInvoke this command for the user request."
    }
  }'
  exit 0
fi
exit 0   # 매칭 없음 → 아무것도 주입하지 않음
```

응용 패턴 (같은 훅에서 우선순위 체인으로 하나만 발화):
1. 키워드 트리거 매칭 → 커맨드 제안
2. 상태 파일 검사 (예: 예산 80% 초과) → 경고 주입
3. 설정 드리프트 감지 (overlay 파일 mtime > settings.json mtime) → 재설치 안내

**설계 원칙**: 이 훅은 부작용이 없다(파일 수정 X, 네트워크 X). `jq`가 없으면
경고만 남기고 통과한다(graceful degradation) — 컨텍스트 주입은 안전장치가 아니라
편의 기능이므로 fail-open이 맞다.

---

## 예시 3: PreToolUse — 선언적 룰셋으로 위험 작업 차단

도구가 실행되기 **전에** 검사하므로 유일하게 "진짜 강제"가 가능한 지점이다.
거부된 호출은 실행되지 않는다. 룰을 스크립트에 하드코딩하지 않고
JSON 룰셋으로 분리하면 정책 변경 시 코드 수정이 필요 없다.

`hooks.json` 등록 (플러그인 번들):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          { "type": "command",
            "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/enforce.py\"" }
        ]
      }
    ]
  }
}
```

룰셋 (`harness-rules.json`) — 시크릿 파일 보호 3종 세트:

```json
{
  "rules": [
    { "id": "deny-secret-file-write",
      "tool": "Write",
      "deny_if": { "file_path_matches": "(^|/)\\.env(\\.|$)|(^|/)secrets?/|\\.pem$|(^|/)kubeconfig$" },
      "decision": "deny",
      "reason": "시크릿 파일 쓰기는 차단됩니다. 시크릿 매니저를 사용하세요." },
    { "id": "deny-secret-file-edit",
      "tool": "Edit",
      "deny_if": { "file_path_matches": "(^|/)\\.env(\\.|$)|(^|/)secrets?/|\\.pem$|(^|/)kubeconfig$" },
      "decision": "deny",
      "reason": "시크릿 파일 편집은 차단됩니다." },
    { "id": "deny-secret-file-shell-redirect",
      "tool": "Bash",
      "deny_if": { "command_matches": "(>>?|tee\\b|dd\\b|cp\\b|mv\\b)[^|;&]*(\\.env(\\.|\\b)|secrets?/|\\.pem\\b|kubeconfig\\b)" },
      "decision": "deny",
      "reason": "셸 리다이렉트를 통한 시크릿 파일 쓰기도 차단됩니다." }
  ]
}
```

> 3번째 룰이 핵심이다. Write/Edit만 막으면 `echo "KEY=x" > .env` 같은
> **셸 우회 경로**가 열려 있다. 같은 정책은 항상 모든 우회 경로를 함께 막는다.

enforcer의 판정 출력:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "시크릿 파일 쓰기는 차단됩니다."
  }
}
```

**fail-open vs fail-closed 구분** (안전장치 설계의 핵심):

| 상황 | 판정 | 이유 |
|------|------|------|
| 룰셋 파일이 아예 없음 | allow | 정책 부재 ≠ 강제 부재. 강제를 원하는 플러그인은 룰셋을 함께 배포 |
| 룰셋이 있는데 파싱 실패 | **ask (fail-closed)** | 강제가 의도됐는데 장치가 고장 → 조용히 allow하면 안 됨 |
| 외부 바이너리(OPA 등) 의존 | 피한다 | 바이너리 부재 시 silently fail-open — 안전장치로서 치명적 |

---

## 예시 4: PostToolUse — 감사 로그 + 변경성 호출 피드백

도구가 이미 실행된 뒤라 **차단은 불가능**하다. 대신 두 가지에 적합하다:

1. **감사 추적**: 모든 도구 호출을 JSON-L로 append. "에이전트가 기록을 기억"하는
   방식이 아니라 harness가 자동 기록하므로 누락이 구조적으로 불가능하다.
2. **선택적 피드백**: 변경성(mutating) 호출에만 `additionalContext`로 후속 조치를 리마인드.

```bash
#!/usr/bin/env bash
set -euo pipefail
INPUT="$(cat)"
TOOL="$(echo "$INPUT" | jq -r '.tool_name // ""')"
COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // ""')"
FILE="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')"

# 변경성 분류 — 어떤 룰이 발화했는지 기록해 나중에 튜닝할 수 있게 한다
CLASS="benign"; RULE=""
case "$TOOL" in
  Write|Edit|NotebookEdit) CLASS="mutating"; RULE="file-write" ;;
  Bash)
    if   [[ "$COMMAND" =~ kubectl[[:space:]]+(apply|delete|patch|scale) ]]; then CLASS="mutating"; RULE="kubectl-mutating"
    elif [[ "$COMMAND" =~ terraform[[:space:]]+(apply|destroy) ]];            then CLASS="mutating"; RULE="terraform-mutating"
    elif [[ "$COMMAND" =~ git[[:space:]]+(push|reset|clean|rebase) ]];        then CLASS="mutating"; RULE="git-mutating"
    fi ;;
esac

# 감사 라인 append (jq로 빌드 — 도구 입력은 외부 영향을 받는 값이므로 이스케이프 필수)
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
mkdir -p "$PROJ_DIR/.audit"
jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg tool "$TOOL" \
       --arg class "$CLASS" --arg rule "$RULE" --arg cmd "${COMMAND:0:512}" \
  '{ts:$ts, tool:$tool, classification:$class}
   + (if $rule != "" then {matched_rule:$rule} else {} end)
   + (if $cmd  != "" then {command_excerpt:$cmd} else {} end)' \
  >> "$PROJ_DIR/.audit/tool-events.jsonl"

# 변경성 호출에만 피드백 주입
if [[ "$CLASS" == "mutating" ]]; then
  jq -n --arg ctx "[audit] 상태 변경 $TOOL 호출을 기록했습니다 (rule: $RULE). 관련 상태 파일 갱신 여부를 확인하세요." '{
    hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: $ctx }
  }'
else
  printf '{}\n'   # 유효한 no-op payload
fi
```

**역할 분담**: PostToolUse의 피드백은 가이드일 뿐이다. 하드 차단이 필요한
정책은 반드시 PreToolUse(예시 3)에 둔다 — 두 훅은 한 쌍으로 설계한다.

---

## 예시 5: Stop / StopFailure — 턴 종료 게이트

"게이트를 통과하기 전에는 턴을 끝낼 수 없다"를 강제한다. 작업을 수행한
에이전트가 스스로 검증을 건너뛰는 **self-grading 실패 모드**를 막는 장치다.
한 스크립트를 두 이벤트에 등록하고 `hook_event_name`으로 분기한다.

```bash
#!/usr/bin/env bash
set -euo pipefail
INPUT="$(cat)"
EVENT="$(echo "$INPUT" | jq -r '.hook_event_name // ""')"
STOP_ACTIVE="$(echo "$INPUT" | jq -r '.stop_hook_active // false')"

# ① 재진입 가드 (필수!) — 차단 후 재실행된 턴에서 또 차단하면 데드락
[[ "$STOP_ACTIVE" == "true" ]] && { printf '{}\n'; exit 0; }

# 게이트 판정 파일 확인 (검증 skill이 기록해 둔 verdict를 신뢰만 한다)
PROJ_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
BLOCKED=$(jq -r 'select(.status == "blocked") | .phase' \
  "$PROJ_DIR"/.state/gates/*.json 2>/dev/null || true)
[[ -z "$BLOCKED" ]] && { printf '{}\n'; exit 0; }

# ② StopFailure는 절대 차단하지 않는다 — 실패한 턴을 막으면 세션이 루프에 갇힘
if [[ "$EVENT" == "StopFailure" ]]; then
  jq -n --arg msg "게이트($BLOCKED)가 blocked 상태입니다. 해결 후 재검증하세요." \
    '{systemMessage: $msg}'
  exit 0
fi

# ③ Stop: 게이트가 blocked → 턴 종료 차단
jq -n --arg reason "턴을 종료할 수 없습니다: 게이트($BLOCKED)가 blocked 상태입니다. blocker를 해결하고 검증을 재실행하세요." \
  '{decision: "block", reason: $reason}'
```

두 이벤트 등록:

```json
{
  "hooks": {
    "Stop":        [ { "hooks": [ { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/stop-gate.sh\"" } ] } ],
    "StopFailure": [ { "hooks": [ { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/stop-gate.sh\"" } ] } ]
  }
}
```

**Stop 훅 3원칙**:
1. `stop_hook_active` 재진입 가드 없이는 배포하지 않는다 (데드락).
2. StopFailure는 경고만 — 차단 금지.
3. 다운그레이드 경로를 둔다 (예: `GATE_MODE=warn` env var로 block → systemMessage).

---

## 함정: 플러그인 hooks.json은 최상위 "hooks" 키로 감싼다

CC 2.1.x부터 플러그인의 `hooks/hooks.json`에서 이벤트 이름을 최상위에 두면
`"Failed to load hooks ... expected record, received undefined"`로 **로드가 조용히
실패**한다. settings.json과 동일하게 `"hooks"` 키로 감싸야 한다.

```json
// ❌ 로드 실패 (구 형식)
{ "SessionStart": [ ... ], "PreToolUse": [ ... ] }

// ✅ CC 2.x 형식
{ "hooks": { "SessionStart": [ ... ], "PreToolUse": [ ... ] } }
```

훅이 동작하지 않는데 에러도 안 보인다면 가장 먼저 이 형식을 의심한다.

---

## 공통 설계 원칙 (모든 예시에 반복되는 패턴)

1. **JSON은 반드시 jq/python으로 인코딩** — 훅이 다루는 값(파일 내용, 명령어,
   도구 입력)은 외부 영향을 받으므로 셸 보간으로 JSON을 조립하면 깨지거나 주입당한다.
2. **킬 스위치 env var** — 모든 훅에 `X_DISABLE_*=1` 탈출구를 둔다.
3. **`CLAUDE_PROJECT_DIR` + `$PWD` 폴백** — 훅의 cwd는 보장되지 않는다.
   경로는 전부 이 변수를 거친다. 플러그인 번들 스크립트는 `${CLAUDE_PLUGIN_ROOT}`.
4. **fail-open/fail-closed를 의식적으로 결정** — 편의 기능(컨텍스트 주입)은
   fail-open, 안전장치(정책 강제)는 fail-closed. 의존 도구(jq) 부재 시의
   동작을 반드시 명시한다.
5. **self-contained 스크립트** — 플러그인으로 배포되는 훅은 repo 루트의 다른
   파일에 의존하지 않는다. 설치된 사본에서 그대로 동작해야 한다.
6. **차단과 가이드의 역할 분담** — 강제는 PreToolUse/Stop, 기록·피드백은
   PostToolUse, 주입은 SessionStart/UserPromptSubmit. 한 정책을 여러 이벤트에
   걸쳐 설계한다 (예: PreToolUse가 막고, PostToolUse가 기록하고, Stop이 검증).
