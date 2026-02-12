# prompt-vault

Phase-based conversation logging plugin for Claude Code.

Tracks user prompts, Claude actions, and results per phase. Auto-preserves progress across context compactions.

## Installation

```bash
claude --plugin-dir /path/to/prompt-vault
```

## Skills

| Skill | Description |
|-------|-------------|
| `/prompt-vault:init` | Initialize logging environment in current project |
| `/prompt-vault:log [title]` | Log current phase to `.local/logs/` |
| `/prompt-vault:status` | Show phase progress summary |

## How It Works

1. **Init** — Creates `.local/logs/`, updates `.gitignore` and `CLAUDE.md`
2. **Log** — Saves completed work as `phase-NNN.md` with structured format
3. **Status** — Reads `_index.md` to show progress at a glance

## Context Protection

- **Stop hook** — Warns when context usage is high
- **PreCompact hook** — Records compaction timestamp before context compression
- **SessionStart hook** — Restores phase index and latest log after compaction

## License

MIT
