[한국어](ARCHITECTURE.md) | English

# prompt-vault Architecture Guide

This document covers the technical internals, design decisions, and extension methods of the prompt-vault plugin. A deep-dive guide for developers and contributors.

## Table of Contents

- [Overview](#overview)
- [Plugin Structure](#plugin-structure)
- [Core Components](#core-components)
- [Hook Implementation Details](#hook-implementation-details)
- [Skill Implementation Details](#skill-implementation-details)
- [Data Flow](#data-flow)
- [Environment Variables](#environment-variables)
- [Configuration Schema](#configuration-schema)
- [Template System](#template-system)
- [Customization Guide](#customization-guide)
- [Extension Points](#extension-points)
- [Testing and Debugging](#testing-and-debugging)
- [Performance Considerations](#performance-considerations)
- [Security and Privacy](#security-and-privacy)
- [Version History](#version-history)

## Overview

### Architecture at a Glance

```
prompt-vault/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── hooks/
│   └── hooks.json           # Hook registration (Stop, PreCompact, SessionStart)
├── scripts/
│   ├── context-check.sh     # Stop hook: context usage check
│   ├── pre-compact.sh       # PreCompact hook: compaction checkpoint
│   ├── post-compact.sh      # SessionStart hook: recovery data injection
│   └── generate-report.sh   # HTML report generator (zero token cost)
├── skills/
│   ├── init/SKILL.md        # /prompt-vault:init skill
│   ├── log/SKILL.md         # /prompt-vault:log skill
│   ├── status/SKILL.md      # /prompt-vault:status skill
│   └── report/SKILL.md      # /prompt-vault:report skill
├── templates/
│   ├── phase.md             # Phase log template
│   ├── index.md             # _index.md initial template
│   ├── claude-md-snippet.md # CLAUDE.md injection protocol
│   ├── report-summary.html  # Summary dashboard template
│   └── report-detail.html   # Detail chat log template
└── data/
    └── palettes.json        # Curated 5-color palette sets
```

### Design Philosophy

**Vault Metaphor**:
- Safely store prompts and work history
- Protect progress state even through context compaction
- Automated protection mechanisms (minimize user intervention)

**Key Design Principles**:

1. **Idempotency**: `/prompt-vault:init` is safe to run multiple times
2. **Separation**: Logs stored in `.local/logs/`, excluded from git
3. **Automation**: Hook-based automatic warnings and recovery
4. **Reusability**: Same plugin works across all projects

## Plugin Structure

### Directory Roles

| Directory/File | Role | Access Method |
|---------------|------|--------------|
| `.claude-plugin/plugin.json` | Plugin metadata (name, version, desc) | Read by Claude Code on load |
| `hooks/hooks.json` | Hook registration (Stop, PreCompact, SessionStart) | Referenced by Claude Code on hook events |
| `scripts/*.sh` | Hook implementation scripts (Bash) | Referenced via `command` in hooks.json |
| `skills/*/SKILL.md` | Skill definitions and prompts | Injected to Claude when user runs `/prompt-vault:*` |
| `templates/*.md` | Markdown templates | Used by `init`, `log` skills for file creation |
| `templates/*.html` | HTML report templates | Used by `generate-report.sh` for placeholder substitution |
| `data/palettes.json` | Curated 5-color palette presets | Random selection by `init` skill (API fallback) |

## Core Components

### 1. Plugin Manifest (plugin.json)

```json
{
  "name": "prompt-vault",
  "version": "1.1.0",
  "description": "Phase-based conversation logging with context protection.",
  "author": { "name": "etvibe" },
  "keywords": ["logging", "phase", "context", "history", "session"],
  "license": "MIT"
}
```

### 2. Hook System (hooks.json)

**Hook Lifecycle**:

| Hook Type | Trigger | Execution Context | Purpose |
|-----------|---------|-------------------|---------|
| `Stop` | After Claude response | Every response | Monitoring, warnings |
| `PreCompact` | Before context compaction | Before compaction | State saving, logging |
| `SessionStart` | On session start | New session init | Recovery, injection |

**Hook Types**:
- **`command`**: Execute Bash script
- **`matcher`**: SessionStart hook condition (e.g., `"compact"` = only after compaction)

**Environment Variables**:
- `${CLAUDE_PLUGIN_ROOT}`: Plugin directory absolute path
- `$TRANSCRIPT_PATH`: Session transcript file path (Stop hook)
- `$PWD`: User's project directory

### 3. Skill System (SKILL.md)

**SKILL.md Format**:
```markdown
---
name: skill-name
description: One-line skill description
disable-model-invocation: true/false
argument-hint: [argument hint]
---

Skill prompt body (injected to Claude)
```

**YAML Frontmatter Fields**:
- `name`: Skill name (must match directory name)
- `description`: Skill purpose and behavior
- `disable-model-invocation`:
  - `true`: Prompt injection only, Claude won't invoke model (read-only ops)
  - `false`: Claude can invoke model to generate content (write ops)
- `argument-hint`: Argument hint shown to user

## Hook Implementation Details

### Stop Hook: context-check.sh

**Purpose**: Check context usage after every response and warn

**Data Flow**:
```
Claude response → Stop hook trigger → JSON stdin → context-check.sh
                                                      ↓
                                               Extract transcript_path
                                                      ↓
                                               Measure file size
                                                      ↓
                                               Read threshold from .config
                                                      ↓
                                               size > threshold?
                                               ↙ Yes      ↘ No
                                        Output warning    Exit (0)
```

**Performance**: ~35-50ms total (imperceptible to user)

### PreCompact Hook: pre-compact.sh

**Purpose**: Audit trail for compaction events

**Actions**:
1. Check `.local/logs/` directory exists
2. Generate current timestamp
3. Count `phase-*.md` files
4. Append to `compaction.log`

**No stdout**: This hook doesn't output to user (background logging)

### SessionStart Hook: post-compact.sh

**Purpose**: Recover progress state after compaction

**Key**: This hook's **stdout is injected into Claude's new session context**

**Data Flow**:
```
Compaction done → New session start → SessionStart hook (matcher: "compact")
                                              ↓
                                      post-compact.sh executes
                                              ↓
                                      stdout: _index.md + latest phase
                                              ↓
                                      Injected into Claude's new session context
```

**Recovery Data Size**: ~2-5 KB total (negligible impact on context)

## Skill Implementation Details

### /prompt-vault:init

**6-Step Procedure**:
1. Create `.local/logs/` directory
2. Add `.local/` to `.gitignore` (idempotent)
3. Initialize `.local/logs/_index.md` from template
4. Add Phase Logging Protocol to `CLAUDE.md`
5. Create `.local/logs/.config` with context thresholds + project metadata + palette
6. Output completion message

### /prompt-vault:log [title]

**5-Step Procedure**:
1. Verify `.local/logs/` exists
2. Determine next phase number (max existing + 1, 3-digit zero-padded)
3. Create `phase-NNN.md` from template with Claude-generated content
4. Update `_index.md` with new row
5. Output completion message

**Phase Numbering**: Based on max existing number + 1 (not file count). Gaps are allowed.

### /prompt-vault:report

**Dual-Track Architecture**:
- **Track 1 (Default)**: `generate-report.sh` — zero token cost, pure shell
- **Track 2 (Custom)**: Claude model invocation for custom enhancements

**generate-report.sh Core Logic**:
1. Read config via `jq`
2. Parse `_index.md` via `awk` → HTML table rows + timeline cards
3. Parse `phase-*.md` via awk state machine → chat bubble HTML
4. Template substitution: simple placeholders via `sed`, multi-line markers via `head/tail` split

## Data Flow

### Normal Workflow (Warning Only)

```
User prompt → Claude response → Stop hook → context-check.sh
→ transcript size < threshold? → No → Output warning → Display to user
```

### Compaction Workflow (Full Cycle)

```
User: /prompt-vault:log "title"
→ Claude: create phase-NNN.md, update _index.md
→ User: /compact
→ PreCompact hook: record to compaction.log
→ Claude: context compaction
→ New session start (matcher: "compact")
→ SessionStart hook: output _index.md + latest phase
→ stdout → Claude's new session context
→ Claude: ready with recovered state
→ User: resume work
```

## Environment Variables

### Provided by Claude Code

| Variable | When | Example | Purpose |
|----------|------|---------|---------|
| `${CLAUDE_PLUGIN_ROOT}` | Skill prompt processing | `/Users/user/prompt-vault` | Template path reference |
| `$TRANSCRIPT_PATH` | Stop hook execution | `/Users/user/.claude/sessions/abc.jsonl` | Transcript size measurement |
| `$PWD` | All hooks/skills | `/Users/user/my-project` | Project directory |

## Configuration Schema

### .config JSON Schema

```json
{
  "model": "claude-opus-4-6",
  "context_window_tokens": 200000,
  "warn_percent": 80,
  "warn_bytes": 640000,
  "project_name": "My Project",
  "project_description": "Project description",
  "palette": ["#264653", "#2A9D8F", "#E9C46A", "#F4A261", "#E76F51"]
}
```

**Threshold Calculation**:
```
warn_bytes = context_window_tokens × 4 bytes/token × (warn_percent / 100)
```

## Template System

### phase.md Structure

```markdown
# Phase NNN: TITLE
- **Date**: YYYY-MM-DD
- **Session**: SESSION_ID

## User Prompt
> Original user request verbatim

## Actions
- Actions performed by Claude in chronological order

## Results
- Output summary (file paths, key findings)

## Decisions
- Decisions made and their rationale

## Next
- Next steps or pending items
```

### HTML Report Templates

**report-summary.html**: Project dashboard with stats, timeline, phase index table
**report-detail.html**: Chat bubble UI with phase navigation, collapsible sections

**Placeholders**:
- Simple: `{{PROJECT_NAME}}`, `{{THEME_COLOR}}`, etc. → `sed` substitution
- Multi-line: `{{PHASE_TABLE}}`, `{{PHASE_SECTIONS}}`, etc. → `head/tail` split + `cat` assembly

**5-Color Palette System**:
- CSS variables: `--color-primary` through `--color-muted`
- Source: colormind.io API (fallback: `data/palettes.json` curated presets)

## Customization Guide

### 1. Adjust Thresholds

Edit `.local/logs/.config`:
```json
{ "warn_percent": 70, "warn_bytes": 560000 }
```

### 2. Custom Phase Format

Edit `templates/phase.md` to add fields like issue tracker links.

### 3. Add New Hooks

Create a script in `scripts/`, add to `hooks.json`:
```json
{
  "type": "command",
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/my-hook.sh"
}
```

## Extension Points

- **Phase export**: Convert logs to PDF via pandoc
- **Phase search**: Keyword search across phases via grep
- **Git integration**: Auto-commit phases
- **Team collaboration**: Author tagging per phase

## Testing and Debugging

### Manual Testing

```bash
# Hook testing
echo '{"transcript_path":"/path/to/transcript"}' | scripts/context-check.sh
scripts/pre-compact.sh
scripts/post-compact.sh

# Report testing
CLAUDE_PLUGIN_ROOT=$(pwd) bash scripts/generate-report.sh all
```

### Debugging Tips

- Add `echo "DEBUG: ..." >&2` to scripts (stderr for debug, stdout for Claude)
- Create fake transcripts: `dd if=/dev/zero of=/tmp/test bs=1024 count=700`

## Performance Considerations

| Operation | Time | Bottleneck |
|-----------|------|-----------|
| Stop hook (context check) | ~35-50ms | None (imperceptible) |
| Phase logging | 2-5s | Model invocation |
| Recovery injection | ~2-5 KB | None (~0.01% of context) |
| Report generation | ~1-2s | awk parsing + file I/O |

## Security and Privacy

- All logs stored locally only — no network transmission
- `.local/` auto-added to `.gitignore`
- No external service dependencies (colormind.io is optional, for palette only)
- **Warning**: Logs may contain user prompts, generated code, architecture decisions, file paths

## Version History

### v1.0.0 (2026-02-12)
- Initial release: 3 skills (init, log, status), 3 hooks (Stop, PreCompact, SessionStart)
- Template system, context threshold auto-warning, post-compaction auto-recovery

### v1.1.0 (2026-02-26)
- HTML reporting: `/prompt-vault:report` skill, `generate-report.sh` (zero token cost)
- Summary dashboard + detailed chat log HTML templates
- 5-color palette system (colormind.io API + curated fallback)
- `.config` extended with project metadata and palette

## References

- **Claude Code Plugin Docs**: https://docs.anthropic.com/claude-code/plugins
- **Hook System Spec**: https://docs.anthropic.com/claude-code/hooks
- **Skill Spec**: https://docs.anthropic.com/claude-code/skills
- **GitHub Repository**: https://github.com/lemon-etvibe/prompt-vault

---

**Questions or suggestions?**
Discuss on GitHub Issues. Contributions welcome!
