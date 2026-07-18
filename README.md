# cawcaw253-plugins

cawcaw253의 Claude Code 플러그인 마켓플레이스입니다.

## 구조

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json          # 마켓플레이스 카탈로그
└── plugins/
    └── harness-plugin/           # 플러그인
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            ├── agentic-loop/     # Claude Code 동작 원리
            │   └── SKILL.md
            ├── settings-scopes/  # 설정 범위(user/project/local)
            │   └── SKILL.md
            └── harness-hooks/    # hooks/permissions 강제
                └── SKILL.md
```

## 포함된 플러그인

| 플러그인 | 설명 |
|----------|------|
| `harness-plugin` | Claude Code harness 구성을 돕는 skill 모음 |

### `harness-plugin`의 skill

harness를 설계하는 순서대로 3개의 skill을 제공한다.

| skill | 역할 | 다루는 것 |
|-------|------|-----------|
| `agentic-loop` | 어디에 개입 가능한가 | agentic loop 3단계, 도구, 컨텍스트 윈도우, 세션, 체크포인트/권한 |
| `settings-scopes` | 정책을 어느 범위에 둘까 | user/project/local 범위·우선순위·파일 위치 (Managed 조직 범위는 무시) |
| `harness-hooks` | 정책을 어떻게 강제할까 | hooks 수명주기, matcher/if, 종료 코드·JSON 출력, settings 등록 |

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

- Hooks: https://code.claude.com/docs/ko/hooks
- Plugins: https://code.claude.com/docs/ko/plugins
- Marketplaces: https://code.claude.com/docs/ko/plugin-marketplaces
