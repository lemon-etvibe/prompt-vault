[한국어](GETTING_STARTED.md) | English

# prompt-vault Getting Started Guide

Welcome! This tutorial is a hands-on guide for first-time users of the prompt-vault plugin. Follow step-by-step to learn the plugin's core features.

## Learning Objectives

After completing this tutorial, you will be able to:

1. ✅ Initialize prompt-vault logging environment for a project
2. ✅ Systematically record work in phase units
3. ✅ View phase progress at a glance
4. ✅ Understand and utilize the context protection mechanism
5. ✅ Apply best practices in real projects

**Estimated time**: 15-20 minutes
**Difficulty**: Beginner

## Prerequisites

Before starting, prepare the following:

```bash
# 1. Verify Claude Code installation
claude --version

# 2. Verify jq installation
which jq

# If not installed:
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

## Tutorial Preparation

### Step 1: Install the Plugin

```bash
# Clone the plugin
cd ~/Downloads  # or your preferred location
git clone https://github.com/lemon-etvibe/prompt-vault.git

# Verify installation
ls prompt-vault/
# Expected: README.md, hooks/, scripts/, skills/, templates/, ...
```

### Step 2: Create a Sample Project

```bash
# Create a tutorial project directory
mkdir ~/tutorial-todo-app
cd ~/tutorial-todo-app

# Start Claude with the plugin
claude --plugin-dir ~/Downloads/prompt-vault
```

### Step 3: Verify Plugin Loaded

When Claude starts, you should see:

```
✓ Loaded plugin: prompt-vault (1.0.0)
  Skills: /prompt-vault:init, /prompt-vault:log, /prompt-vault:status
```

If not displayed:
- Check that `--plugin-dir` path is correct
- Verify `prompt-vault/.claude-plugin/plugin.json` exists

## Phase 1: Initialize Logging Environment

Let's start using prompt-vault!

### 1.1 Run Initialization

Enter in Claude:

```
/prompt-vault:init
```

### 1.2 Expected Output

Claude will perform these actions:

```
✓ Created .local/logs/ directory
✓ Created .local/logs/.config with context thresholds
✓ Created .local/logs/_index.md (phase index table)
✓ Added .local/ to .gitignore
✓ Added Phase Logging Protocol to CLAUDE.md

Initialization complete! You can now use:
- /prompt-vault:log [title] — Log completed work
- /prompt-vault:status — View phase progress
```

### 1.3 Verify Generated Files

Check generated files in your terminal:

```bash
# Check directory structure
ls -la .local/logs/

# Expected:
# .config
# _index.md

# Check .config contents
cat .local/logs/.config
```

**Expected output**:
```json
{
  "model": "claude-opus-4-6",
  "context_window_tokens": 200000,
  "warn_percent": 80,
  "warn_bytes": 640000
}
```

### 1.4 Exercise 1.1: Understanding .config Fields

Let's examine each field in `.config`:

- **`model`**: Current Claude model ID
- **`context_window_tokens`**: Model's context window size (in tokens)
- **`warn_percent`**: Warning threshold (80% = warn when 80% of context is used)
- **`warn_bytes`**: Threshold converted to transcript file byte size

**Calculation example**:
```
200,000 tokens × 4 bytes/token × 80% = 640,000 bytes
```

### 1.5 Exercise 1.2: Idempotency Test

Run `/prompt-vault:init` again. It will skip existing files and only add new content.

```
/prompt-vault:init
```

This is an **idempotent operation**. Safe to run multiple times!

## Phase 2: Simulating Your First Work

Let's simulate actual work.

### 2.1 Scenario: Building a Todo App

Ask Claude:

```
Create a simple todo app. Implement add, list, and mark-complete features in Python.
```

Claude will create a `todo.py` file with basic CRUD functionality.

### 2.2 Verify Your Work

```bash
ls todo.py
python todo.py
```

## Phase 3: Your First Phase Log

Work is done — let's log it!

### 3.1 Create Phase Log

Enter in Claude:

```
/prompt-vault:log "Basic todo app implementation"
```

### 3.2 Verify the Generated Log

```bash
cat .local/logs/phase-001.md
```

The log will contain structured sections: User Prompt, Actions, Results, Decisions, and Next steps.

### 3.3 Check the Index

```bash
cat .local/logs/_index.md
```

**Expected**:
```markdown
# Phase Log Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | Basic todo app implementation | done | 2026-02-12 | Python todo CRUD implementation |
```

### 3.4 Exercise 2.1: Add a Second Phase

Now add a delete feature. Ask Claude, then log:

```
/prompt-vault:log "Add todo delete feature"
```

Check that `_index.md` now shows two rows!

## Phase 4: Checking Progress

### 4.1 Status Query

```
/prompt-vault:status
```

This displays the complete phase index table with all recorded phases.

### 4.2 Use Cases

`/prompt-vault:status` is useful when:
- Reopening a project after a break
- Sharing progress with teammates
- Planning next steps

## Phase 5: Context Protection Experience

This section covers prompt-vault's core feature: the **context protection mechanism**.

### 5.1 Context Warning

After extended work, when context exceeds 80%:

```
⚠️ [prompt-vault] Context ~85% used (680000 bytes).
💡 Run /prompt-vault:log to save progress, then /compact to free context.
```

### 5.2 How It Works

The **Stop hook (context-check.sh)** runs after every response:

1. Measures current transcript file size
2. Reads `warn_bytes` from `.local/logs/.config`
3. Outputs warning if threshold exceeded

### 5.3 Save Checkpoint Before Compaction

When warning appears:

```
/prompt-vault:log "Checkpoint: file save/load feature complete"
/compact
```

### 5.4 Compaction Workflow

When `/compact` runs, these occur sequentially:

1. **PreCompact hook** (`pre-compact.sh`) — Records timestamp and phase count to `compaction.log`
2. **Claude compacts context** — Summarizes long conversation to free space
3. **SessionStart hook** (`post-compact.sh`) — Re-injects `_index.md` + latest phase into Claude's new context

### 5.5 Key Insight

**Progress is preserved even after compaction!**

- ✅ Phase index table recovered (full history)
- ✅ Latest phase log recovered (immediate work context)
- ✅ Claude restarts aware of project state

## Real-World Scenarios

### Scenario 1: Multi-Day Project

**Day 1**: Initialize, work, log phases.
**Day 2**: Run `/prompt-vault:status` to review yesterday's progress, then continue.

### Scenario 2: Multiple Projects

Each project's `.local/logs/` is completely independent. Just `cd` to the project and use the plugin.

### Scenario 3: Team Collaboration

Remove `.local/` from `.gitignore` to share logs via Git. Useful for team progress tracking.

## Best Practices

### When to Log

Set clear **completion criteria**:
- ✅ "3 API endpoints implemented" → Log
- ✅ "Bug fixed and tests passing" → Log
- ❌ "Still writing code..." → Don't log yet

### Phase Naming

**Action-oriented, result-focused**:
```bash
# Good
/prompt-vault:log "Implement JWT authentication"
/prompt-vault:log "Refactor 3 React components"

# Avoid
/prompt-vault:log "work"           # Too vague
/prompt-vault:log "code changes"   # Meaningless
```

### Phase Granularity

Aim for **30-60 minute focused work units**:
```
❌ Too large: "Implement entire app"
✅ Right size: "User model and API endpoints"
❌ Too small: "Add one function"
```

## Advanced Tips

### 1. Manual Phase Editing

Logs are plain markdown — freely editable:
```bash
vim .local/logs/phase-001.md
```

### 2. History Search

Search past decisions or keywords:
```bash
grep -r "PostgreSQL" .local/logs/
```

### 3. Custom Thresholds

Want earlier warnings? Edit `.config`:
```json
{
  "warn_percent": 70,
  "warn_bytes": 560000
}
```

### 4. Phase Export

```bash
# Merge all phases into one file
cat .local/logs/phase-*.md > project-history.md
```

## Troubleshooting

### Permission Denied
```bash
sudo chown -R $USER:$USER .local/
```

### No Warnings Appearing
```bash
which jq          # Verify jq installed
cat .local/logs/.config  # Verify config exists
```

### No Recovery After Compaction
Ensure at least one phase was logged before compaction. The SessionStart hook requires `phase-*.md` files to exist.

## Self-Assessment Quiz

### Q1. When do you run `/prompt-vault:init`?
**A**: Once per project. Idempotent — safe to run multiple times.

### Q2. How are phase logs stored?
**A**: As `.local/logs/phase-NNN.md` markdown files (NNN auto-increments from 001).

### Q3. When do context warnings appear?
**A**: When transcript size exceeds `warn_bytes` in `.config` (default 640KB).

### Q4. What gets recovered after compaction?
**A**: `_index.md` (phase index) + most recent `phase-*.md` (latest phase log).

### Q5. Can you use it across multiple projects?
**A**: Yes, each project's `.local/logs/` is independently managed.

## Next Steps

Congratulations! You've mastered prompt-vault's core features.

### Further Reading

- **[ARCHITECTURE.en.md](ARCHITECTURE.en.md)** — Deep dive into plugin internals
- **[README.en.md](README.en.md)** — Quick reference guide

### Customization

Adapt the plugin to your workflow:
- Modify phase template (`templates/phase.md`)
- Adjust thresholds (`.local/logs/.config`)
- Add new hooks (`hooks/hooks.json`)

## Resources

- **GitHub**: https://github.com/lemon-etvibe/prompt-vault
- **Issues**: https://github.com/lemon-etvibe/prompt-vault/issues

---

**Questions or feedback?**
Feel free to open a GitHub Issue. We'd love to hear from you!

**Happy logging! 🚀**
