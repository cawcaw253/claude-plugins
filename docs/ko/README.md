[English](../en/README.md) | [한국어](../ko/README.md)

# cawcaw253-plugins

cawcaw253의 Claude Code 플러그인 마켓플레이스입니다.

## 구조

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json          # 마켓플레이스 카탈로그
├── docs/
│   ├── en/                       # 영어 문서
│   │   └── README.md
│   └── ko/                       # 한국어 문서
│       └── README.md
└── plugins/
    └── harness-plugin/           # 플러그인
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            ├── agentic-loop/     # Claude Code 동작 원리
            ├── settings-scopes/  # 설정 범위(user/project/local)
            ├── harness-hooks/    # hooks/permissions 강제
            │   └── examples.md   # 실전 hook 예제 모음
            ├── project-rules/    # CLAUDE.md·.claude/rules 규칙
            ├── slash-commands/   # 커스텀 커맨드(= skill)
            ├── workflows/        # subagent 오케스트레이션
            └── agent-memory/     # 자동 메모리·MEMORY.md
```

## 포함된 플러그인

| 플러그인 | 설명 |
|----------|------|
| `harness-plugin` | Claude Code harness 구성을 돕는 skill 모음 |

### `harness-plugin`의 skill

**기초** — harness를 설계하는 순서.

| skill | 역할 | 다루는 것 |
|-------|------|-----------|
| `agentic-loop` | 어디에 개입 가능한가 | agentic loop 3단계, 도구, 컨텍스트 윈도우, 세션, 체크포인트/권한 |
| `settings-scopes` | 정책을 어느 범위에 둘까 | user/project/local 범위·우선순위·파일 위치 (Managed 조직 범위는 무시) |
| `harness-hooks` | 정책을 어떻게 강제할까 | hooks 수명주기, matcher/if, 종료 코드·JSON 출력, settings 등록 |

**확장 계층** — 무엇을 구성·제약하는가.

| skill | 역할 | 다루는 것 |
|-------|------|-----------|
| `project-rules` | 지침을 구성 | CLAUDE.md 위치·로드 순서, `.claude/rules/`·path-specific rules, @import, "규칙은 강제 아님" |
| `slash-commands` | 커스텀 커맨드 | `.claude/commands`↔skills, frontmatter, 인자, 동적 컨텍스트 주입, 접근 제어 |
| `workflows` | 오케스트레이션 | dynamic workflows, subagent/skill/team 비교, ultracode, 저장·비활성화 |
| `agent-memory` | 메모리 통제 | 자동 메모리 vs CLAUDE.md, MEMORY.md 로드 규칙, 위치, 활성화·감사 |

> Managed(조직 레벨) 설정은 IT/DevOps가 배포하는 엔터프라이즈 범위로, 이 플러그인의
> harness 구성 대상이 아니다. skill 전반에서 해당 내용은 "무시"로 명시해 두었다.

`harness-hooks` skill에는 실전 hook 패턴을 모은 보조 레퍼런스
`skills/harness-hooks/examples.md`가 포함되어 있어, skill이 필요할 때 함께 참조합니다.

## 설치

마켓플레이스를 추가한 뒤 원하는 플러그인을 설치합니다.

```shell
/plugin marketplace add cawcaw253/claude-plugins
/plugin install harness-plugin@cawcaw253-plugins
```

설치 후 skill은 네임스페이스가 붙어 `/harness-plugin:harness-hooks`로 호출되며,
관련 작업(hooks·harness 구성) 시 자동으로도 사용됩니다.

## 팀에서 자동 등록

각 repo의 `.claude/settings.json`에 아래를 추가하면 프로젝트를 신뢰할 때
마켓플레이스가 자동 등록됩니다.

```json
{
  "extraKnownMarketplaces": {
    "cawcaw253-plugins": {
      "source": {
        "source": "github",
        "repo": "cawcaw253/claude-plugins"
      }
    }
  },
  "enabledPlugins": {
    "harness-plugin@cawcaw253-plugins": true
  }
}
```

## 로컬 테스트 / 검증

```shell
claude plugin validate .
/plugin marketplace add ./claude-plugins
```

## 업데이트

플러그인은 `version`을 생략했으므로 이 repo에 새 커밋을 푸시하면 새 버전으로 취급됩니다.
사용자는 `/plugin marketplace update cawcaw253-plugins`로 새로 고칩니다.

## 참고

- Hooks: https://code.claude.com/docs/en/hooks
- Plugins: https://code.claude.com/docs/en/plugins
- Marketplaces: https://code.claude.com/docs/en/plugin-marketplaces
