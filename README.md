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
            └── harness-hooks/
                └── SKILL.md
```

## 포함된 플러그인

| 플러그인 | 설명 |
|----------|------|
| `harness-plugin` | Claude Code hooks/permissions로 AI 작업 범위를 제한하는 harness 구성을 돕는 `harness-hooks` skill |

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
