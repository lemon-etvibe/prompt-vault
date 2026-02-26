[한국어](README.md) | English

# prompt-vault

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/lemon-etvibe/prompt-vault)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> A phase-based conversation logging plugin for Claude Code with automatic context protection

## What is prompt-vault?

When working on long projects with Claude Code, context compaction causes **important work history and progress to be lost**. prompt-vault was born to solve this problem.

### Problems It Solves

- **Work history loss during context compaction**: After compaction, previous phase decisions and progress are forgotten
- **No project progress tracking**: Difficult to see at a glance what's been completed and what was decided
- **Manual logging burden**: Having to manually record work content in separate documents

### How It Works

prompt-vault solves these problems with **hook-based automatic recovery** and **phase-unit structured logging**:

1. **Automatic context monitoring**: Checks context usage after every response, warns at 80%
2. **Phase-based logging**: Systematically records meaningful work units with `/prompt-vault:log`
3. **Automatic recovery**: After context compaction, auto-injects phase index and latest log on session restart

### Key Benefits

- ✅ **Structured logging**: Systematically records user prompts, actions, results, and decisions
- ✅ **Automatic context protection**: Stop/PreCompact/SessionStart hooks auto-preserve progress
- ✅ **Git-safe storage**: All logs stored in `.local/logs/`, auto-excluded from git
- ✅ **Multi-project support**: Independent log management per project, reusable plugin form

## Key Features

### 📝 Phase-Based Logging
- Auto-numbered completed work as `phase-001.md`, `phase-002.md`
- Structured format including user prompts, actions, results, decisions, next steps
- View all phases at a glance via `_index.md` table

### ⚠️ Automatic Context Usage Warnings
- Monitors transcript size after every response
- Auto-warns when 80% threshold is exceeded
- Accurate thresholds tuned for each model's context window

### 🔄 Automatic Post-Compaction Recovery
- **PreCompact hook**: Auto-records compaction timestamp to `compaction.log`
- **SessionStart hook**: After compaction, auto-injects `_index.md` + latest phase log to Claude
- Ensures work continuity without losing progress

### 📊 HTML Report Visualization
- Convert phase logs to visual HTML reports with `/prompt-vault:report`
- **Summary dashboard**: Timeline, stat cards, phase index table
- **Detailed log view**: Chat bubble UI showing user prompts ↔ Claude responses
- Project-unique design with 5-color palette
- Pure static HTML — viewable with just a browser

### 🔒 Git-Safe Storage
- All logs stored in project's `.local/logs/` directory
- `.local/` auto-added to `.gitignore` during initialization
- Protects sensitive work history from accidental commits

## Prerequisites

- **Claude Code**: Latest version (hook system support required)
- **jq**: JSON processor (required for hooks)
  ```bash
  # macOS
  brew install jq

  # Ubuntu/Debian
  sudo apt install jq

  # Windows (WSL)
  sudo apt install jq
  ```
- **Platform**: macOS, Linux, Windows WSL

## Installation

### Method 1: Claude Plugin Add (Recommended)

```bash
claude plugin add lemon-etvibe/prompt-vault
```

### Method 2: Manual Installation

```bash
# 1. Clone the plugin
git clone https://github.com/lemon-etvibe/prompt-vault.git

# 2. Run Claude with the plugin directory
claude --plugin-dir /path/to/prompt-vault
```

## Quick Start (5 minutes)

```bash
# 1. Initialize logging environment for your project
/prompt-vault:init

# 2. Work on features
[User] "Implement basic todo app features"
[Claude] "Sure, I'll create todo.py..."

# 3. Log the completed phase
/prompt-vault:log "Basic todo app implementation"

# 4. Check progress
/prompt-vault:status

# 5. Continue working until context warning appears
⚠️ [prompt-vault] Context ~85% used (680000 bytes).
💡 Run /prompt-vault:log to save progress, then /compact to free context.

# 6. Log checkpoint and compact
/prompt-vault:log "Checkpoint: delete feature complete"
/compact

# 7. Auto-recovery in next session!
=== Phase Progress (post-compaction recovery) ===
# Phase Log Index
| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | Basic todo app implementation | done | 2026-02-12 | CRUD basics complete |
| 002 | Checkpoint: delete feature complete | done | 2026-02-12 | Delete with confirmation |
=== End Recovery ===
```

## Skill Reference

### `/prompt-vault:init`

**Purpose**: Initialize logging environment for a project

**Actions**:
- Creates `.local/logs/` directory
- Creates `.local/logs/.config` (model-specific context thresholds)
- Initializes `.local/logs/_index.md` (phase index table)
- Adds `.local/` to `.gitignore` (skips if present)
- Adds Phase Logging Protocol section to `CLAUDE.md` (skips if present)

**When to use**: Once per project (idempotent operation)

### `/prompt-vault:log [title]`

**Purpose**: Record completed work as a phase log

**Format**: `phase-NNN.md` (NNN auto-increments from 001)

**Contents**:
- **User Prompt**: Original user request
- **Actions**: Major actions performed by Claude (tools, files read/created/modified)
- **Results**: Deliverable summary (file paths, key findings, key data)
- **Decisions**: Decisions made and their rationale
- **Next**: Next steps or open items

**When to use**:
- After completing a meaningful work unit (phase)
- When context warning occurs (required before compaction)
- Before breaks to save current work state

**Examples**:
```bash
/prompt-vault:log "User authentication API implementation"
/prompt-vault:log "Database schema design"
```

### `/prompt-vault:report [summary|detail|all|custom]`

**Purpose**: Convert phase logs to visualized HTML reports

**Actions**:
- Runs `scripts/generate-report.sh` (zero token cost)
- Generates `.local/logs/report-summary.html` — Project summary dashboard
- Generates `.local/logs/report-detail.html` — Phase-by-phase detailed chat log

**Arguments**:
- `summary`: Summary dashboard only
- `detail`: Detailed log view only
- `all` (default): Both
- `custom`: Claude generates a custom report

**Examples**:
```bash
/prompt-vault:report           # Generate default report
/prompt-vault:report summary   # Summary only
/prompt-vault:report custom    # Custom (reflects additional requests)
open .local/logs/report-summary.html  # Open in browser
```

### `/prompt-vault:status`

**Purpose**: Display phase progress summary

**Actions**: Reads `.local/logs/_index.md` and outputs phase table

## Context Protection Mechanism

prompt-vault protects work history before and after context compaction through three hooks.

### Stop Hook (context-check.sh)

**Trigger**: After every Claude response

**Actions**:
1. Measures current session transcript file size
2. Reads `warn_bytes` threshold from `.local/logs/.config`
3. Outputs warning if transcript exceeds threshold
4. Suggests `/prompt-vault:log` + `/compact`

**Performance**: Typically < ~50ms

### PreCompact Hook (pre-compact.sh)

**Trigger**: Just before context compaction

**Actions**:
1. Records current timestamp
2. Counts current phase count
3. Appends compaction history to `.local/logs/compaction.log`

### SessionStart Hook (post-compact.sh)

**Trigger**: On session restart after compaction (matcher: "compact")

**Actions**:
1. Reads `.local/logs/_index.md`
2. Reads most recent `phase-*.md` file (by modification time)
3. Outputs both to stdout → **Injected into Claude's new session context**

## Generated Project Structure

After running `/prompt-vault:init`:

```
your-project/
├── .local/
│   └── logs/
│       ├── .config              # Model/threshold settings (JSON)
│       ├── _index.md            # Phase index table
│       ├── phase-001.md         # First phase log
│       ├── phase-002.md         # Second phase log
│       ├── compaction.log       # Auto-compaction history (audit trail)
│       ├── report-summary.html  # Project summary dashboard (auto-generated)
│       └── report-detail.html   # Phase-by-phase detailed chat log (auto-generated)
├── .gitignore                   # .local/ added (merged if exists)
└── CLAUDE.md                    # Phase Logging Protocol section added
```

## Configuration

### `.config` Format

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

**Fields**:
- `model`: Claude model ID in use
- `context_window_tokens`: Model's context window size (tokens)
- `warn_percent`: Warning threshold (percentage)
- `warn_bytes`: Warning threshold (transcript bytes)
- `project_name`: Used in report title (default: directory name)
- `project_description`: Report subtitle (default: empty)
- `palette`: 5-color palette array — [primary, secondary, accent, surface, muted]

### Recommended Thresholds by Model

| Model | Context Window | 80% Threshold (bytes) |
|-------|---------------|----------------------|
| Opus 4.6 (200K) | 200,000 tokens | 640,000 bytes |
| Sonnet 4.5 (200K) | 200,000 tokens | 640,000 bytes |
| Haiku 4.5 (200K) | 200,000 tokens | 640,000 bytes |
| Extended (1M) | 1,000,000 tokens | 3,200,000 bytes |

**Formula**: `warn_bytes = (context_window_tokens × 4) × (warn_percent / 100)`
(1 token ≈ 4 bytes estimate)

### Customizing Thresholds

You can adjust thresholds by editing the `.config` file directly:

```bash
# Lower threshold to 70% (receive warnings earlier)
vim .local/logs/.config
# Change warn_percent to 70, warn_bytes to 560000
```

## Best Practices

### When to Log

**✅ Log at these moments**:
- After completing a meaningful feature (e.g., "Implemented user auth")
- When recording important decisions (e.g., "Chose PostgreSQL because...")
- Before breaks to save current work state
- When context warning appears (required before compaction)

**❌ Avoid excessive logging**:
- Don't log every typo fix or single-line change
- A phase should represent ~30-60 minutes of focused work

### Phase Naming Conventions

**Good examples**:
- "User authentication API implementation"
- "Database schema design"
- "Frontend component refactoring"

**Avoid**:
- "Task 1", "Task 2" (meaningless)
- "Code changes" (too vague)
- "Bug fix" (specify which bug)

### Context Management Tips

1. **Regular status checks**: Use `/prompt-vault:status` to track progress
2. **Mandatory logging before compaction**: Always save current work when warnings appear
3. **Semantic phase units**: Each phase should have one clear objective
4. **Leverage sub-agents**: Delegate long exploratory tasks via Task tool to protect main context

## FAQ

### Q1. What's the performance impact?

**A**: Minimal. The Stop hook runs after every response but adds < ~50ms overhead. Users won't notice.

### Q2. Can I manually edit logs?

**A**: Yes. All logs are plain markdown files, freely editable with any editor. `_index.md` can also be manually updated.

### Q3. What if I forgot to log before compaction?

**A**: Previously recorded phases are preserved, but current in-progress work is lost. The SessionStart hook only recovers the latest logged phase. **Always log when warnings appear.**

### Q4. Can I use it across multiple projects?

**A**: Yes. Each project's `.local/logs/` directory is independently managed. The plugin operates based on `$PWD` (current working directory).

### Q5. What if I want to commit logs to Git?

**A**: Remove the `.local/` line from `.gitignore`. Note that logs may contain sensitive information (API keys, internal logic). Can be useful for team collaboration.

### Q6. What happens if I delete a phase number?

**A**: `/prompt-vault:log` determines the next number based on existing `phase-*.md` files, so deleting a file won't fill the gap. Example: if 001, 002, 003 exist and you delete 002, the next log will be 004.

### Q7. Are logs useful even without compaction?

**A**: Yes, logs are very useful for systematically managing project history regardless of compaction. You can query progress anytime with `/prompt-vault:status` and search past decisions with `grep`.

## Troubleshooting

### Permission Errors

**Symptom**: `Permission denied: .local/logs/`

**Fix**:
```bash
ls -la .local/
sudo chown -R $USER:$USER .local/
```

### Context Warnings Not Appearing

**Cause 1**: `jq` not installed
```bash
which jq
brew install jq  # macOS
```

**Cause 2**: `.config` file missing or malformed
```bash
cat .local/logs/.config
/prompt-vault:init  # Re-run if missing
```

### Post-Compaction Recovery Not Working

**Cause**: No phases were logged before compaction

**Fix**: The SessionStart hook requires `.local/logs/` directory with at least one `_index.md` and `phase-*.md` file. Always run `/prompt-vault:log` before compaction.

### Phase Numbers Have Gaps

**Cause**: Previously manually deleted phase files, or numbering logic characteristic

**This is normal behavior.** Numbers don't need to be sequential; just sort by filename.

## Contributing

Contributions welcome! Bug reports, feature suggestions, and pull requests are all appreciated.

- **Architecture**: See [ARCHITECTURE.en.md](ARCHITECTURE.en.md) for plugin internals
- **Issues**: [GitHub Issues](https://github.com/lemon-etvibe/prompt-vault/issues)
- **Pull Requests**: Validate shell scripts with `shellcheck`, markdown follows CommonMark

## Related Documentation

- **[ARCHITECTURE.en.md](ARCHITECTURE.en.md)** — Plugin technical internals and developer guide
- **[GETTING_STARTED.en.md](GETTING_STARTED.en.md)** — Step-by-step tutorial and hands-on guide
- **[CLAUDE.md](CLAUDE.md)** — Plugin design document
- **[GitHub Repository](https://github.com/lemon-etvibe/prompt-vault)** — Source code and issue tracking

## License

MIT License - See [LICENSE](LICENSE) for details.

---

**Made with ❤️ by [etvibe](https://github.com/lemon-etvibe)**
