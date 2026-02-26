# prompt-vault — Claude Code Plugin

## Overview
A Claude Code plugin that systematically logs user prompts and Claude's execution results for each phase during project development, preserving progress state even through context compactions.

## Design Philosophy
- **A vault that safely stores prompts and work history** — protects progress state even when context is compacted
- Reusable plugin form for all projects
- Logs stored in project's `.local/logs/` (excluded from git tracking)

## File Structure and Roles

| File | Role |
|------|------|
| `.claude-plugin/plugin.json` | Plugin manifest (name, version, description) |
| `skills/init/SKILL.md` | `/prompt-vault:init` — Initialize logging environment (.local/logs, .gitignore, CLAUDE.md, .config) |
| `skills/log/SKILL.md` | `/prompt-vault:log [title]` — Record completed work as phase-NNN.md |
| `skills/status/SKILL.md` | `/prompt-vault:status` — Show progress summary based on _index.md |
| `skills/report/SKILL.md` | `/prompt-vault:report` — Visualize phase logs as HTML reports |
| `hooks/hooks.json` | Stop (context warning), PreCompact (checkpoint), SessionStart (restore) hooks |
| `scripts/context-check.sh` | Stop hook — estimate context usage via transcript size, warn at 80% |
| `scripts/pre-compact.sh` | PreCompact hook — record compaction timestamp/phase count |
| `scripts/post-compact.sh` | SessionStart hook — re-inject _index.md + latest phase after compaction |
| `scripts/generate-report.sh` | Report generation shell script (zero token cost) |
| `templates/phase.md` | Phase log template |
| `templates/index.md` | _index.md initial template |
| `templates/claude-md-snippet.md` | Logging protocol snippet for target project's CLAUDE.md |
| `templates/report-summary.html` | Summary dashboard HTML template |
| `templates/report-detail.html` | Detailed chat log HTML template |
| `data/palettes.json` | Curated 5-color palette sets |

## Generated Structure in Target Project

```
project/
├── .local/
│   └── logs/
│       ├── .config              # Model/threshold settings
│       ├── _index.md            # Phase index table
│       ├── phase-001.md         # Individual phase logs
│       ├── phase-002.md
│       ├── compaction.log       # Auto-compaction history
│       ├── report-summary.html  # Summary dashboard (auto-generated)
│       └── report-detail.html   # Detailed chat log (auto-generated)
├── .gitignore                   # .local/ added
└── CLAUDE.md                    # Logging protocol section added
```

## Context Threshold Settings

| Model | Context | 80% warn_bytes |
|-------|---------|----------------|
| Opus/Sonnet/Haiku (200K) | 200K tokens | 640,000 bytes |
| Extended (1M) | 1M tokens | 3,200,000 bytes |

## Usage

```bash
claude --plugin-dir /path/to/prompt-vault
```

## Current Status
- v1.1.0: HTML reporting feature added
- GitHub: https://github.com/lemon-etvibe/prompt-vault
