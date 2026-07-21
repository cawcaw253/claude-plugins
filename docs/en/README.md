[English](../en/README.md) | [한국어](../ko/README.md)

# cawcaw253-plugins

cawcaw253's Claude Code plugin marketplace.

## Structure

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace catalog
├── docs/
│   ├── en/                       # English documentation
│   │   └── README.md
│   └── ko/                       # Korean documentation
│       └── README.md
└── plugins/
    └── harness-plugin/           # Plugin
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            ├── agentic-loop/     # How Claude Code works
            ├── settings-scopes/  # Settings scopes (user/project/local)
            ├── harness-hooks/    # Enforcing hooks/permissions
            │   └── examples.md   # Practical hook examples
            ├── project-rules/    # CLAUDE.md and .claude/rules rules
            ├── slash-commands/   # Custom commands (= skills)
            ├── workflows/        # Subagent orchestration
            └── agent-memory/     # Auto memory and MEMORY.md
```

## Included plugins

| Plugin | Description |
|--------|-------------|
| `harness-plugin` | A collection of skills for configuring the Claude Code harness |

### Skills in `harness-plugin`

**Foundation** — the order in which to design a harness.

| Skill | Role | Covers |
|-------|------|--------|
| `agentic-loop` | Where can you intervene? | The 3 stages of the agentic loop, tools, context window, sessions, checkpoints/permissions |
| `settings-scopes` | Which scope should a policy live in? | user/project/local scopes, precedence, file locations (Managed org scope is ignored) |
| `harness-hooks` | How do you enforce a policy? | Hook lifecycle, matcher/if, exit codes and JSON output, settings registration |

**Extension layer** — what to configure and constrain.

| Skill | Role | Covers |
|-------|------|--------|
| `project-rules` | Structuring instructions | CLAUDE.md locations and load order, `.claude/rules/` and path-specific rules, @import, "rules are not enforcement" |
| `slash-commands` | Custom commands | `.claude/commands` ↔ skills, frontmatter, arguments, dynamic context injection, access control |
| `workflows` | Orchestration | Dynamic workflows, subagent/skill/team comparison, ultracode, saving and disabling |
| `agent-memory` | Controlling memory | Auto memory vs CLAUDE.md, MEMORY.md load rules, locations, enabling and auditing |

> Managed (organization-level) settings are the enterprise scope deployed by IT/DevOps and
> are out of scope for this plugin's harness configuration. Every skill explicitly marks
> that scope as "ignored".

The `harness-hooks` skill ships with a companion reference,
`skills/harness-hooks/examples.md`, which collects practical hook patterns and is
consulted alongside the skill when needed.

## Installation

Add the marketplace, then install the plugin you want.

```shell
/plugin marketplace add cawcaw253/claude-plugins
/plugin install harness-plugin@cawcaw253-plugins
```

After installation, skills are namespaced and invoked as `/harness-plugin:harness-hooks`,
and they are also used automatically for related work (hooks and harness configuration).

## Automatic registration for teams

Add the following to each repo's `.claude/settings.json` and the marketplace will be
registered automatically when the project is trusted.

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

## Local testing / validation

```shell
claude plugin validate .
/plugin marketplace add ./claude-plugins
```

## Updates

The plugin omits `version`, so any new commit pushed to this repo is treated as a new
version. Users refresh with `/plugin marketplace update cawcaw253-plugins`.

## References

- Hooks: https://code.claude.com/docs/en/hooks
- Plugins: https://code.claude.com/docs/en/plugins
- Marketplaces: https://code.claude.com/docs/en/plugin-marketplaces
