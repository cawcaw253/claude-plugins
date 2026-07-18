---
name: slash-commands
description: >-
  커스텀 slash command(= skill)를 작성·배치하는 방법을 안내한다. .claude/commands와
  .claude/skills의 관계, frontmatter(description, disable-model-invocation,
  allowed-tools, argument-hint, model 등), 인자($ARGUMENTS/$N), 동적 컨텍스트
  주입(!`cmd`), 파일 위치·우선순위·네임스페이스를 다룬다. 사용자가 "커스텀 커맨드
  만들기", "/commit 같은 커맨드", "slash command frontmatter", "커맨드에 인자 전달"
  등을 물을 때 사용한다.
---

# 커스텀 Slash Commands (= Skills)

`/commit` 같은 커스텀 커맨드를 만드는 방법을 안내한다.
공식 문서: https://code.claude.com/docs/en/slash-commands , https://code.claude.com/docs/en/skills

> **핵심:** 커스텀 커맨드는 **skill로 병합**되었다. `.claude/commands/deploy.md`와
> `.claude/skills/deploy/SKILL.md`는 둘 다 `/deploy`를 만들고 동일하게 동작한다.
> 기존 `.claude/commands/*.md`도 계속 작동하지만, **skill 방식이 권장**된다
> (지원 파일 디렉토리·자동 호출 제어 등 추가 기능 제공).
> 이 repo의 `/commit`은 `.claude/commands/commit.md`에 있으며 정상 작동한다.

---

## 1. 파일 위치와 커맨드 이름

커맨드 이름은 **파일/디렉토리 위치**에서 나온다(frontmatter `name`은 표시 라벨일 뿐).

| 위치 | 커맨드 이름 | 적용 범위 |
|------|-------------|-----------|
| `.claude/commands/deploy.md` | `/deploy` (파일명) | 프로젝트(커밋) |
| `.claude/skills/deploy/SKILL.md` | `/deploy` (디렉토리명) | 프로젝트(커밋) |
| `~/.claude/skills/<name>/SKILL.md` | `/<name>` | 나(모든 프로젝트) |
| `<plugin>/skills/<name>/SKILL.md` | `/<plugin>:<name>` | 플러그인 활성 위치 |

- 같은 이름 충돌 시: 플러그인은 네임스페이스라 무충돌, 그 외 enterprise > personal > project.
  skill과 command가 같은 이름이면 **skill 우선**.
- 커스텀 커맨드/skill은 같은 이름의 bundled skill(`/code-review` 등)도 오버라이드한다.

---

## 2. frontmatter (자주 쓰는 필드)

```yaml
---
description: 무엇을 하고 언제 쓰는지 (Claude가 자동 호출 판단에 사용)
disable-model-invocation: true      # 나만 호출 가능(Claude 자동 호출 금지)
allowed-tools: Bash(git add *) Bash(git commit *)
argument-hint: "[issue-number]"
model: inherit                      # 이 skill 활성 동안 쓸 모델
context: fork                       # 별도 subagent 컨텍스트에서 실행
---
```

| 필드 | 용도 |
|------|------|
| `description` | 유일 권장 필드. Claude의 자동 호출 판단 기준 |
| `disable-model-invocation: true` | **나만** 호출(부작용 있는 `/commit`·`/deploy`에 필수) |
| `user-invocable: false` | **Claude만** 호출(`/` 메뉴 숨김, 배경 지식용) |
| `allowed-tools` | 이 커맨드 호출 턴 동안 무승인 허용 도구(다음 메시지에 해제) |
| `disallowed-tools` | 이 커맨드 활성 동안 제거할 도구 |
| `argument-hint` | 자동완성 힌트 |
| `arguments` | 명명 위치 인자(`$name` 치환) |
| `model` / `effort` | 이 커맨드 활성 동안 모델/추론 강도 |
| `context: fork` | 격리된 subagent에서 실행(`agent`로 타입 지정) |
| `paths` | 이 패턴 파일 작업 시에만 자동 활성 |

> **harness 관점:** 부작용이 있는 커맨드(`/commit`, `/deploy`)에는 반드시
> `disable-model-invocation: true`를 붙여 Claude가 임의 실행하지 못하게 한다.
> `allowed-tools`는 프로젝트 skill의 경우 워크스페이스 신뢰 수락 후 적용된다 —
> skill이 스스로 넓은 권한을 부여할 수 있으니 신뢰 전 검토한다.

---

## 3. 인자 전달

| 변수 | 의미 |
|------|------|
| `$ARGUMENTS` | 전체 인자 문자열 |
| `$ARGUMENTS[N]` / `$N` | N번째(0-based) 인자. `$0`, `$1` … |
| `$name` | `arguments` frontmatter로 선언한 명명 인자 |

```yaml
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
---
Fix GitHub issue $ARGUMENTS following our coding standards.
```

`/fix-issue 123` → "Fix GitHub issue 123 …". `$ARGUMENTS`가 없으면 입력이
`ARGUMENTS: <값>`으로 뒤에 붙는다. 다중 단어 인자는 따옴표로 감싼다.

---

## 4. 동적 컨텍스트 주입 — `` !`command` ``

skill 내용이 Claude에 전달되기 **전에** 셸 명령을 실행하고 그 출력으로 치환한다
(Claude가 실행하는 게 아니라 전처리).

```yaml
---
name: summarize-changes
description: Summarizes uncommitted changes and flags risks.
allowed-tools: Bash(git diff *)
---

## Current changes
!`git diff HEAD`

## Instructions
위 변경을 2~3개 불릿으로 요약하고 위험을 나열한다.
```

- 줄 시작 또는 공백 뒤의 `` !`...` ``만 인식(`KEY=!`cmd``는 리터럴).
- 여러 줄은 ` ```! ` 펜스 블록 사용.
- ⚠️ 정책상 차단: 설정 `disableSkillShellExecution: true`면 실행 대신
  `[shell command execution disabled by policy]`로 대체(bundled/managed는 예외).
  → harness에서 skill 내 임의 셸 실행을 막고 싶을 때 사용(`settings-scopes` skill).

---

## 5. Claude의 커맨드 접근 제어 (harness)

permissions로 어떤 skill/command를 Claude가 호출할지 통제한다(`Skill` 도구 기준):

```text
# 전체 차단(deny): Skill
# 특정만 허용:      Skill(commit)   Skill(review-pr *)
# 특정 차단:        Skill(deploy *)
```

- `Skill(name)` 정확 일치, `Skill(name *)` 접두 일치.
- `disable-model-invocation: true`는 Claude 컨텍스트에서 아예 제거.
- 설정의 `skillOverrides`로 frontmatter 수정 없이 가시성 제어(on/name-only/off 등).

---

## 예시: 이 repo의 `/commit`을 skill로 강화한다면

```yaml
---
description: Conventional Commits 규칙으로 커밋(co-authored-by 제거)
disable-model-invocation: true
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *) Bash(git diff *) Bash(git log *)
---
```

`disable-model-invocation`으로 사용자만 실행, `allowed-tools`로 커밋 관련 git 명령을
무승인 허용. 절차 본문은 기존 `commit.md`를 그대로 쓴다.

---

## 참고 링크

- Slash commands (영문): https://code.claude.com/docs/en/slash-commands
- Skills (영문): https://code.claude.com/docs/en/skills
- 관련 skill: `project-rules`(CLAUDE.md), `workflows`, `harness-hooks`
