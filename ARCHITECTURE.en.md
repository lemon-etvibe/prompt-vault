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
- [Contributing Guide](#contributing-guide)
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
│   ├── pre-compact.sh       # PreCompact hook: compaction timestamp recording
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
| `.claude-plugin/plugin.json` | Plugin metadata (name, version, description) | Read by Claude Code on load |
| `hooks/hooks.json` | Hook registration file (Stop, PreCompact, SessionStart) | Referenced by Claude Code on hook events |
| `scripts/*.sh` | Hook implementation scripts (Bash) | Referenced via `command` in `hooks.json` |
| `skills/*/SKILL.md` | Skill definitions and prompts | Injected to Claude when user runs `/prompt-vault:*` |
| `templates/*.md` | Markdown template files | Used by `init`, `log` skills for file creation |
| `templates/*.html` | HTML report templates | Used by `generate-report.sh` for placeholder substitution |
| `data/palettes.json` | Curated 5-color palette sets | Random selection by `init` skill (API fallback) |

### File Size and Complexity

| File | Lines | Complexity | Description |
|------|-------|-----------|-------------|
| `plugin.json` | 9 | Low | JSON metadata only |
| `hooks.json` | 38 | Low | Declarative hook registration |
| `context-check.sh` | 26 | Medium | `jq`, `wc`, conditionals |
| `pre-compact.sh` | 13 | Low | Simple file append |
| `post-compact.sh` | 20 | Low | `cat`, `ls`, pipes |
| `init/SKILL.md` | 44 | Medium | 6-step initialization procedure |
| `log/SKILL.md` | 47 | High | Numbering, file creation, index update |
| `status/SKILL.md` | 9 | Low | Simple read operation |
| `report/SKILL.md` | ~80 | Medium | Report generation (script + custom) |
| `generate-report.sh` | ~200 | High | awk parsing, head/tail substitution, HTML assembly |
| `report-summary.html` | ~170 | Medium | Summary dashboard template |
| `report-detail.html` | ~200 | Medium | Detailed chat log template |
| `palettes.json` | ~15 | Low | 5-color palette JSON array |

## Core Components

### 1. Plugin Manifest (plugin.json)

**Schema**:
```json
{
  "name": "prompt-vault",
  "version": "1.0.0",
  "description": "...",
  "author": { "name": "etvibe" },
  "keywords": ["logging", "phase", "context", "history", "session"],
  "license": "MIT"
}
```

**Field Descriptions**:
- `name`: Plugin unique ID (recommended to match directory name)
- `version`: Semantic versioning (MAJOR.MINOR.PATCH)
- `description`: Description shown in Claude Code UI
- `keywords`: Tags for search and classification

**Version Management**:
- `1.0.0`: Initial release (current)
- `1.x.y`: Backward-compatible updates
- `2.0.0`: Major API changes

### 2. Hook System (hooks.json)

**Hook Lifecycle**:

| Hook Type | Trigger Timing | Execution Context | Primary Use |
|-----------|---------------|-------------------|-------------|
| `Stop` | After Claude response completes | Every response | Monitoring, warnings |
| `PreCompact` | Just before context compaction | Before compaction starts | State saving, logging |
| `SessionStart` | On session start | New session initialization | Recovery, injection |

**Hook Types**:
- **`command`**: Execute Bash script
- **`matcher`**: SessionStart hook condition (e.g., `"compact"` = only after compaction)

**Environment Variable Passing**:
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
- `description`: Skill purpose and behavior description
- `disable-model-invocation`:
  - `true`: Prompt injection only, Claude won't invoke model (read-only operations)
  - `false`: Claude can invoke model to generate content (write operations)
- `argument-hint`: Argument hint displayed to user (e.g., `[phase-title]`)

**Model Invocation Flags**:
- `init`: `disable-model-invocation: true` (file manipulation only)
- `log`: `disable-model-invocation: false` (log content generation required)
- `status`: `disable-model-invocation: false` (output formatting required)

## Hook Implementation Details

### Stop Hook: context-check.sh

**Purpose**: Check context usage after every response and warn if threshold exceeded

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

**Code Analysis**:

```bash
#!/bin/bash
# 1. Read JSON from stdin
INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# 2. Check transcript file existence
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# 3. Read threshold from .config
CONFIG=".local/logs/.config"
if [ -f "$CONFIG" ]; then
  THRESHOLD=$(jq -r '.warn_bytes // 640000' "$CONFIG")
else
  THRESHOLD=640000  # Default: 80% of 200K model
fi

# 4. Measure transcript size
SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d ' ')

# 5. Warn if threshold exceeded
if [ "$SIZE" -gt "$THRESHOLD" ]; then
  PCT=$((SIZE * 100 / (THRESHOLD * 100 / 80)))
  echo "⚠️ [prompt-vault] Context ~${PCT}% used (${SIZE} bytes)."
  echo "💡 Run /prompt-vault:log to save progress, then /compact to free context."
fi
```

**Performance**:
- `jq` parsing: ~10ms
- `wc` execution: ~20ms
- Conditional evaluation: ~5ms
- **Total overhead**: ~35-50ms (imperceptible to user)

**Input Example**:
```json
{
  "transcript_path": "/Users/user/.claude/sessions/abc123.jsonl"
}
```

**Output Example**:
```
⚠️ [prompt-vault] Context ~85% used (680000 bytes).
💡 Run /prompt-vault:log to save progress, then /compact to free context.
```

### PreCompact Hook: pre-compact.sh

**Purpose**: Audit trail for compaction events

**Code Analysis**:

```bash
#!/bin/bash
LOG_DIR=".local/logs"
if [ -d "$LOG_DIR" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  PHASE_COUNT=$(ls -1 "$LOG_DIR"/phase-*.md 2>/dev/null | wc -l | tr -d ' ')
  {
    echo "⚠️ Auto-compaction at $TIMESTAMP"
    echo "Phase count: $PHASE_COUNT"
    echo "---"
  } >> "$LOG_DIR/compaction.log"
fi
```

**Actions**:
1. Check `.local/logs/` directory existence
2. Generate current timestamp
3. Count `phase-*.md` files
4. Append to `compaction.log`

**No stdout**: This hook does not output to user (background logging)

**compaction.log Example**:
```
⚠️ Auto-compaction at 2026-02-12 14:32:10
Phase count: 5
---
⚠️ Auto-compaction at 2026-02-12 16:45:23
Phase count: 8
---
```

### SessionStart Hook: post-compact.sh

**Purpose**: Recover progress state after compaction on session restart

**Key**: This hook's **stdout is injected into Claude's new session context**

**Code Analysis**:

```bash
#!/bin/bash
LOG_DIR=".local/logs"
if [ -d "$LOG_DIR" ]; then
  echo "=== Phase Progress (post-compaction recovery) ==="

  # Output _index.md
  if [ -f "$LOG_DIR/_index.md" ]; then
    cat "$LOG_DIR/_index.md"
  fi

  echo ""
  echo "=== Latest Phase Log ==="

  # Output most recent phase-*.md
  LATEST=$(ls -t "$LOG_DIR"/phase-*.md 2>/dev/null | head -1)
  if [ -n "$LATEST" ]; then
    cat "$LATEST"
  else
    echo "(No phases logged yet)"
  fi

  echo "=== End Recovery ==="
fi
```

**Data Flow**:
```
Compaction complete → New session start → SessionStart hook (matcher: "compact")
                                                  ↓
                                          post-compact.sh executes
                                                  ↓
                                  stdout: _index.md + latest phase
                                                  ↓
                                  Injected into Claude's new session context
```

**Recovery Data Size**:
- `_index.md`: ~500 bytes (phase table)
- `phase-*.md`: ~1-3 KB (latest log)
- **Total injection**: ~2-5 KB (no burden on context)

**Matcher Condition**:
- `"matcher": "compact"`: Runs only after compaction
- Does NOT run on normal session starts

## Skill Implementation Details

### /prompt-vault:init

**Purpose**: Initialize logging environment for a project

**6-Step Procedure**:

1. **Create `.local/logs/` directory**
   ```bash
   mkdir -p .local/logs/
   ```

2. **Add `.local/` to `.gitignore`**
   - Read existing `.gitignore`
   - Add `.local/` line if not present
   - Idempotent: skip if already exists

3. **Initialize `.local/logs/_index.md`**
   - Copy from `${CLAUDE_PLUGIN_ROOT}/templates/index.md`
   - Contents:
     ```markdown
     # Phase Log Index

     | # | Title | Status | Date | Summary |
     |---|-------|--------|------|---------|
     ```

4. **Add Phase Logging Protocol to `CLAUDE.md`**
   - Insert contents of `${CLAUDE_PLUGIN_ROOT}/templates/claude-md-snippet.md`
   - Create `CLAUDE.md` if it doesn't exist
   - Skip if protocol section already present

5. **Create `.local/logs/.config`**
   - Confirm model with user (environment variable or default)
   - Calculate thresholds:
     ```
     warn_bytes = context_window_tokens × 4 × (warn_percent / 100)
     ```
   - Save in JSON format:
     ```json
     {
       "model": "claude-opus-4-6",
       "context_window_tokens": 200000,
       "warn_percent": 80,
       "warn_bytes": 640000
     }
     ```

6. **Output completion message**

**Idempotency Guarantee**:
- Each step checks file/directory existence
- Skips if already exists, creates if not
- Safe to run multiple times

**Environment Variable Usage**:
```markdown
→ Reference ${CLAUDE_PLUGIN_ROOT}/templates/claude-md-snippet.md contents
```
Claude substitutes `${CLAUDE_PLUGIN_ROOT}` with plugin path during prompt processing

### /prompt-vault:log [title]

**Purpose**: Record completed work as a phase log

**5-Step Procedure**:

1. **Check `.local/logs/`**
   - Create if missing (or guide to `/init`)

2. **Determine phase number**
   ```bash
   # Glob existing phase-*.md files
   EXISTING=$(ls -1 .local/logs/phase-*.md 2>/dev/null)

   # Extract max number + 1
   MAX_NUM=$(echo "$EXISTING" | sed 's/.*phase-\([0-9]*\)\.md/\1/' | sort -n | tail -1)
   NEXT_NUM=$((MAX_NUM + 1))

   # 3-digit zero-padding
   PHASE_NUM=$(printf "%03d" $NEXT_NUM)
   ```

3. **Create `phase-NNN.md`**
   - Based on `${CLAUDE_PLUGIN_ROOT}/templates/phase.md`
   - Fill in the following:
     - Title: `$ARGUMENTS` or inferred by Claude
     - Date: `YYYY-MM-DD`
     - Session: session ID
     - User Prompt: extracted from conversation history
     - Actions: list of actions performed by Claude
     - Results: output summary
     - Decisions: decisions made
     - Next: next steps
   - **Model invocation enabled** (`disable-model-invocation: false`) → Claude generates content

4. **Update `_index.md`**
   - Read existing table
   - Add new row:
     ```markdown
     | NNN | Title | done | YYYY-MM-DD | One-line summary |
     ```
   - Rewrite file

5. **Output completion message**
   ```
   ✓ Logged phase 003: "Title"
   ✓ Updated _index.md
   ```

**Phase Numbering Characteristics**:
- Based on **max existing number + 1**, not file count
- Gaps may occur when files are deleted (e.g., 001, 003, 004)
- Intentional design: allows phase deletion/reordering

**Model-Generated Content**:
- User Prompt: references conversation history
- Actions: extracts file creation/modification history
- Results: generates output summary
- Decisions: infers decisions from context

### /prompt-vault:status

**Purpose**: Display phase progress summary

**Simple Implementation**:

```markdown
Read `.local/logs/_index.md` and display a summary of phase progress to date.
If the file doesn't exist, guide to `/prompt-vault:init`.
```

**Error Handling**:
- `_index.md` not found → "Run `/prompt-vault:init` first"
- `.local/logs/` not found → Same guidance

**Output Format**:
```markdown
# Phase Log Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | ... | done | 2026-02-12 | ... |
| 002 | ... | done | 2026-02-12 | ... |

Total: 2 phases completed
```

### /prompt-vault:report

**Purpose**: Convert phase logs into visualized HTML reports

**Dual-Track Architecture**:

```
Track 1 (Default): Shell script — zero token cost
  /prompt-vault:report → scripts/generate-report.sh → HTML files generated

Track 2 (Custom): Claude model invocation
  /prompt-vault:report custom → base report + Claude enhancement
```

**generate-report.sh Core Logic**:

1. **Read config**: Read `project_name`, `palette`, etc. from `.config` via `jq`
2. **Parse _index.md**: Extract table rows via `awk`, assemble HTML `<tr>` and timeline cards
3. **Parse phase-*.md**: Extract multi-line sections via `awk` range patterns (`/^## Section$/,/^## [A-Z]/`)
4. **Template substitution**:
   - Simple placeholders (`{{PROJECT_NAME}}`, etc.): single-line substitution via `sed`
   - Repeating blocks (`{{PHASE_TABLE}}`, etc.): `head/tail` split + `cat` assembly (reverse-order substitution)

**Parser Choice Rationale**:
- `awk`: Multi-line section parsing (avoids sed range pattern edge cases)
- `jq`: JSON config reading (same as existing hooks)
- `head/tail + cat`: Template substitution (more stable than sed multi-line)

**Generated Files**:
- `.local/logs/report-summary.html` — Project summary dashboard (timeline, stats, index)
- `.local/logs/report-detail.html` — Per-phase chat bubble UI (prompts/responses/decisions)

**5-Color Palette System**:
- Read 5 colors from `.config.palette` array → inject as CSS variables `--color-primary` through `--color-muted`
- Palette source: colormind.io API call during init (fallback: `data/palettes.json`)
- Layout: Tailwind CSS gray scale + 5-color palette accents

## Data Flow

### Normal Workflow (Warning Only)

```
User prompt
    ↓
Claude generates response
    ↓
Stop hook triggers
    ↓
context-check.sh executes
    ↓
transcript size < threshold?
    ↓ No
Output warning
    ↓
Display to user
```

### Compaction Workflow (Full Cycle)

```
User: /prompt-vault:log "title"
    ↓
Claude: create phase-NNN.md, update _index.md
    ↓
User: /compact
    ↓
PreCompact hook triggers
    ↓
pre-compact.sh: record to compaction.log
    ↓
Claude: context compaction (conversation summary)
    ↓
New session start (matcher: "compact")
    ↓
SessionStart hook triggers
    ↓
post-compact.sh: output _index.md + latest phase
    ↓
stdout → Claude's new session context
    ↓
Claude: ready with recovered state
    ↓
User: resume work
```

## Environment Variables

### Variables Provided by Claude Code

| Variable | When Provided | Example Value | Purpose |
|----------|--------------|---------------|---------|
| `${CLAUDE_PLUGIN_ROOT}` | During skill prompt processing | `/Users/user/prompt-vault` | Template path reference |
| `$TRANSCRIPT_PATH` | During Stop hook execution | `/Users/user/.claude/sessions/abc.jsonl` | Transcript size measurement |
| `$PWD` | All hooks/skills | `/Users/user/my-project` | Project directory |

### Plugin Internal Variables

| Variable | Script | Purpose |
|----------|--------|---------|
| `LOG_DIR` | All `.sh` | `.local/logs` path constant |
| `CONFIG` | `context-check.sh` | `.local/logs/.config` path |
| `THRESHOLD` | `context-check.sh` | Threshold byte count |
| `PHASE_NUM` | (Skill logic) | Next phase number (001, 002, ...) |

## Configuration Schema

### .config JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["model", "context_window_tokens", "warn_percent", "warn_bytes"],
  "properties": {
    "model": {
      "type": "string",
      "description": "Claude model ID",
      "examples": ["claude-opus-4-6", "claude-sonnet-4-5-20250929"]
    },
    "context_window_tokens": {
      "type": "integer",
      "description": "Context window size (token count)",
      "minimum": 1,
      "examples": [200000, 1000000]
    },
    "warn_percent": {
      "type": "integer",
      "description": "Warning threshold (percentage)",
      "minimum": 1,
      "maximum": 100,
      "examples": [80, 70]
    },
    "warn_bytes": {
      "type": "integer",
      "description": "Warning threshold (byte count)",
      "minimum": 1,
      "examples": [640000, 3200000]
    }
  }
}
```

### Threshold Calculation

**Formula**:
```
warn_bytes = context_window_tokens × bytes_per_token × (warn_percent / 100)
```

**bytes_per_token Estimation**:
- Generally 1 token ≈ 4 bytes (English basis)
- Korean: 1 token ≈ 2-3 bytes (more character encoding)
- **Conservative estimate**: 4 bytes used (safety margin)

**Examples**:
```
200K model, 80% threshold:
200,000 × 4 × 0.8 = 640,000 bytes

1M model, 80% threshold:
1,000,000 × 4 × 0.8 = 3,200,000 bytes
```

## Template System

### phase.md Structure

```markdown
# Phase NNN: TITLE

- **Date**: YYYY-MM-DD
- **Session**: SESSION_ID

## User Prompt
> Record the user's original request as verbatim as possible

## Actions
- List major actions performed by Claude in chronological order
- Include tools used, files read, files created/modified

## Results
- Output summary (generated file paths, key findings)
- Key data or metrics

## Decisions
- Decisions made and their rationale

## Next
- Next steps or pending items
```

**Section Purposes**:
- **User Prompt**: Requirements tracking
- **Actions**: Execution history (reproducibility)
- **Results**: Output verification
- **Decisions**: Architecture Decision Records (ADR)
- **Next**: Work continuity

### index.md Structure

```markdown
# Phase Log Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
```

**Column Meanings**:
- `#`: Phase number (001, 002, ...)
- `Title`: Phase title
- `Status`: Status (typically `done`, extensible: `in-progress`, `blocked`)
- `Date`: Completion date (YYYY-MM-DD)
- `Summary`: One-line summary (30-50 characters)

### claude-md-snippet.md

**Protocol Content**:
```markdown
# Phase Logging Protocol (prompt-vault)

## Rules
- When a meaningful unit of work (phase) is complete, log it with `/prompt-vault:log [title]`
- Suggest logging when you detect a phase is complete, or when the user explicitly invokes it
- Always log current work before context compaction

## Context Management
- Before `/compact`, save progress with `/prompt-vault:log`
- After compaction, refer to `.local/logs/_index.md` for progress state
- Use sub-agents (Task) to reduce main context load
- Check current progress with `/prompt-vault:status`
```

**Purpose**: Inserted into the target project's `CLAUDE.md` to guide Claude to follow the logging protocol

## Customization Guide

### 1. Changing Thresholds

**Purpose**: Receive warnings earlier or later

**Method**:
```bash
vim .local/logs/.config
```

**Lower to 70%** (earlier warnings):
```json
{
  "model": "claude-opus-4-6",
  "context_window_tokens": 200000,
  "warn_percent": 70,
  "warn_bytes": 560000
}
```

**Raise to 90%** (later warnings):
```json
{
  "warn_percent": 90,
  "warn_bytes": 720000
}
```

### 2. Custom Phase Format

**Purpose**: Adapt to your organization's documentation standards

**Method**:
```bash
vim ~/Downloads/prompt-vault/templates/phase.md
```

**Example: Adding Issue Tracker Link**:
```markdown
# Phase NNN: TITLE

- **Date**: YYYY-MM-DD
- **Session**: SESSION_ID
- **Issue**: [#123](https://github.com/user/repo/issues/123)

...
```

### 3. Adding New Hooks

**Purpose**: Custom actions like Slack notifications after compaction

**Method**:
```bash
# 1. Write the script
vim ~/Downloads/prompt-vault/scripts/notify-slack.sh

#!/bin/bash
# Send compaction notification via Slack webhook
WEBHOOK_URL="https://hooks.slack.com/services/..."
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Context compacted!"}' \
  $WEBHOOK_URL
```

```bash
# 2. Grant execute permission
chmod +x ~/Downloads/prompt-vault/scripts/notify-slack.sh

# 3. Edit hooks.json
vim ~/Downloads/prompt-vault/hooks/hooks.json
```

```json
{
  "hooks": {
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/pre-compact.sh",
            "statusMessage": "Saving phase log..."
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/notify-slack.sh",
            "statusMessage": "Notifying Slack..."
          }
        ]
      }
    ]
  }
}
```

### 4. Multilingual Support

**Purpose**: Write phase logs in English

**Method**:
```bash
vim ~/Downloads/prompt-vault/templates/phase.md
```

**English Template**:
```markdown
# Phase NNN: TITLE

- **Date**: YYYY-MM-DD
- **Session**: SESSION_ID

## User Prompt
> Original user request

## Actions
- Actions performed by Claude

## Results
- Output summary

## Decisions
- Decisions made and rationale

## Next
- Next steps or pending items
```

## Extension Points

### 1. Phase Export (HTML/PDF)

**Idea**: Convert logs to web pages or PDF

**Implementation Example**:
```bash
# Using Pandoc
pandoc .local/logs/phase-*.md -o project-report.pdf

# Or add a new skill
/prompt-vault:export [format]
# Internally calls pandoc
```

### 2. Phase Search Feature

**Idea**: Search past phases by keyword

**Implementation Example**:
```bash
# New skill: /prompt-vault:search [keyword]
# Internally runs grep -r "[keyword]" .local/logs/
# Formats and outputs results
```

### 3. Git Integration

**Idea**: Auto-commit each phase to git

**Implementation Example**:
```bash
# Auto-commit after /prompt-vault:log
git add .local/logs/
git commit -m "phase-NNN: [title]"
```

**Caution**: May contain sensitive information; provide as opt-in feature

### 4. Team Collaboration Feature

**Idea**: Per-member phase tagging

**Implementation Example**:
```markdown
# Phase NNN: TITLE

- **Date**: YYYY-MM-DD
- **Author**: @username
...
```

## Testing and Debugging

### Manual Testing Workflow

**1. Initialization Test**:
```bash
cd ~/test-project
claude --plugin-dir ~/Downloads/prompt-vault
/prompt-vault:init
ls -la .local/logs/
cat .local/logs/.config
cat .local/logs/_index.md
```

**2. Logging Test**:
```bash
/prompt-vault:log "Test Phase"
ls .local/logs/phase-*.md
cat .local/logs/phase-001.md
cat .local/logs/_index.md
```

**3. Status Test**:
```bash
/prompt-vault:status
```

**4. Hook Test**:
```bash
# Manual Stop hook execution
echo '{"transcript_path":"/path/to/transcript.jsonl"}' | \
  ~/Downloads/prompt-vault/scripts/context-check.sh

# PreCompact hook
~/Downloads/prompt-vault/scripts/pre-compact.sh
cat .local/logs/compaction.log

# SessionStart hook
~/Downloads/prompt-vault/scripts/post-compact.sh
```

### Hook Debugging

**Adding echo statements**:
```bash
vim ~/Downloads/prompt-vault/scripts/context-check.sh

# Add debug output
echo "DEBUG: TRANSCRIPT=$TRANSCRIPT" >&2
echo "DEBUG: SIZE=$SIZE, THRESHOLD=$THRESHOLD" >&2
```

**Logging to stderr**:
- stdout is displayed to Claude
- stderr is for debugging (`>&2`)

**Standalone Execution Test**:
```bash
# Create fake transcript
dd if=/dev/zero of=/tmp/test-transcript bs=1024 count=700  # 700KB

# Manual test
echo '{"transcript_path":"/tmp/test-transcript"}' | \
  ~/Downloads/prompt-vault/scripts/context-check.sh
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `jq: command not found` | jq not installed | `brew install jq` |
| `Permission denied: .local/logs/` | No write permission | `chmod +w .local/logs/` |
| No warnings | `.config` missing or threshold too high | Re-run `/init` or adjust threshold |
| No recovery | Didn't log before compaction | Always run `/log` before compaction |
| Duplicate phase numbers | Race condition (concurrent logging) | Use sequential execution |

## Performance Considerations

### Stop Hook Overhead

**Measurement**:
```bash
time echo '{"transcript_path":"/path/to/transcript"}' | \
  scripts/context-check.sh
```

**Results**:
- `jq` parsing: ~10ms
- `wc` execution: ~20ms
- Conditional evaluation: ~5ms
- **Total**: 35-50ms

**Impact**: Imperceptible to user (Claude response generation takes several seconds)

### Log Operation Time

**Measurement**:
- File creation: ~100ms
- Model invocation (content generation): 2-5 seconds
- Index update: ~50ms
- **Total**: 2-5 seconds

**Bottleneck**: Model invocation (unavoidable, quality prioritized)

### Recovery Data Size

**Injected Data**:
- `_index.md`: ~500 bytes (for 10 phases)
- `phase-*.md`: ~1-3 KB
- **Total**: ~2-5 KB

**Impact**: ~0.01% of context window (negligible)

## Security and Privacy

### Local Storage

- All logs stored on user's device only
- No network transmission
- No external service dependencies

### Git Safety

- `.local/` directory auto-added to `.gitignore`
- Prevents accidental commits
- Protects sensitive API keys and internal logic

### User Responsibility

**Warning**: Logs may contain:
- User prompts (requirements)
- Generated code (internal logic)
- Decisions (architecture secrets)
- File paths (project structure)

**Recommendations**:
- Don't include sensitive information in logs
- Review before committing to Git
- Remove sensitive info when sharing with team

## Contributing Guide

### Development Setup

```bash
# 1. Clone the repository
git clone https://github.com/lemon-etvibe/prompt-vault.git
cd prompt-vault

# 2. Local testing
claude --plugin-dir $(pwd)

# 3. Code style check
shellcheck scripts/*.sh
```

### PR Guidelines

**Branch Naming**:
- `feature/add-export-skill`: New feature
- `fix/hook-permission-error`: Bug fix
- `docs/architecture-update`: Documentation improvement

**Commit Messages**:
```
<type>: <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code structure improvement
- `test`: Add tests

**Example**:
```
feat: add /prompt-vault:search skill

Implement keyword-based phase search using grep.
Supports regex patterns and outputs formatted results.

Closes #42
```

### Code Style

**Bash**:
- Must pass `shellcheck`
- Variables in UPPERCASE (`PHASE_NUM`)
- Error handling: `set -e` or explicit checks

**Markdown**:
- CommonMark compliant
- Language hints in code blocks (```bash, ```json)
- Aligned tables

## Version History

### v1.0.0 (2026-02-12)

**Initial Release**:
- ✅ 3 skills: `init`, `log`, `status`
- ✅ 3 hooks: Stop, PreCompact, SessionStart
- ✅ Template system
- ✅ Context threshold auto-warning
- ✅ Post-compaction auto-recovery
- ✅ Git-safe storage

**Known Limitations**:
- No phase search feature (manual `grep` required)
- No PDF export support
- No Git auto-commit

### v1.1.0 (2026-02-26)

**HTML Reporting Feature**:
- ✅ `/prompt-vault:report` skill (summary/detail/all/custom)
- ✅ `generate-report.sh` shell script (zero token cost)
- ✅ Summary dashboard + detailed chat log HTML templates
- ✅ Coolors-based 5-color palette system (colormind.io API + fallback)
- ✅ `.config` extended: `project_name`, `project_description`, `palette`
- ✅ `init` skill update: project meta + random palette assignment

**Future Plans**:
- v1.2.0: PreCompact hook auto-report refresh, output path customization
- v2.0.0: Multi-user collaboration features

## References

- **Claude Code Plugin Docs**: https://docs.anthropic.com/claude-code/plugins
- **Hook System Spec**: https://docs.anthropic.com/claude-code/hooks
- **Skill Spec**: https://docs.anthropic.com/claude-code/skills
- **GitHub Repository**: https://github.com/lemon-etvibe/prompt-vault

---

**Questions or suggestions?**
Discuss on GitHub Issues. Contributions welcome!
