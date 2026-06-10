> **Moved:** this skill now lives in [cbzehner/skills](https://github.com/cbzehner/skills) under `skills/agent-ergonomic-design/`. This repo is archived and read-only.

# Agent Ergonomic Design

Design CLIs, APIs, and MCP tools that agents can call without guessing. The skill focuses on machine-readable output, clear failure modes, and interfaces that work well in real agent loops.

## Use It For

- Adding robot or machine mode to a CLI
- Reviewing an API or MCP tool for agent use
- Turning human-only output into structured output an agent can trust

## Install

Clone the repo and run the installer:

```bash
git clone https://github.com/cbzehner/skill-agent-ergonomic-design.git
cd skill-agent-ergonomic-design
./install.sh all
```

Install targets:

- `./install.sh claude` installs to `~/.claude/skills/agent-ergonomic-design`
- `./install.sh codex` installs to `~/.codex/skills/agent-ergonomic-design`
- `./install.sh agents` installs to `~/.agents/skills/agent-ergonomic-design`
- `./install.sh opencode` installs to `~/.config/opencode/skills/agent-ergonomic-design`
- `./install.sh all --copy` copies files instead of symlinking

Manual install works too: symlink or copy `skills/agent-ergonomic-design` into your agent's skills directory.

## Agent Support

This repo uses the plain `skills/agent-ergonomic-design/SKILL.md` layout. Claude Code and Codex also get small plugin manifests at `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`.

Other agents can read the same `SKILL.md` file. If a host does not support a frontmatter field or tool name, ignore that field and follow the workflow text.

## Layout

```text
.claude-plugin/plugin.json
.codex-plugin/plugin.json
install.sh
skills/agent-ergonomic-design/SKILL.md
README.md
LICENSE
```

## Public Notes

These repos are public. Keep private repo names, secrets, customer data, raw logs, cookies, and absolute filesystem paths out of examples.

## License

MIT