[한국어](GETTING_STARTED.md) | English

# prompt-vault Getting Started Guide

Welcome! This tutorial is a hands-on guide for first-time users of the prompt-vault plugin. Follow along step-by-step to learn the plugin's core features.

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
# Expected output: README.md, hooks/, scripts/, skills/, templates/, ...
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

When Claude starts, you should see the following message:

```
✓ Loaded plugin: prompt-vault (1.1.0)
  Skills: /prompt-vault:init, /prompt-vault:log, /prompt-vault:status, /prompt-vault:report
```

If not displayed:
- Check that `--plugin-dir` path is correct
- Verify `prompt-vault/.claude-plugin/plugin.json` file exists

## Phase 1: Initialize Logging Environment

Let's start using prompt-vault!

### 1.1 Run Initialization

Enter the following in Claude:

```
/prompt-vault:init
```

### 1.2 Expected Output

Claude will perform the following actions:

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

Check the generated files in your terminal:

```bash
# Check directory structure
ls -la .local/logs/

# Expected output:
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

- **`model`**: Currently active Claude model ID
- **`context_window_tokens`**: Model's context window size (in tokens)
- **`warn_percent`**: Threshold for triggering warnings (80% = warn when 80% of context is used)
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

**Expected output**:
```
✓ .local/logs/ already exists, skipping
✓ .config already exists, skipping
...
```

This is an **idempotent operation**. Safe to run multiple times!

## Phase 2: Simulating Your First Work

Now let's simulate actual work.

### 2.1 Scenario: Building a Todo App

Ask Claude the following:

```
Create a simple todo app. Implement add, list, and mark-complete features in Python.
```

Claude will create a `todo.py` file. Example code:

```python
# todo.py
todos = []

def add_todo(task):
    todos.append({"task": task, "done": False})
    print(f"Added: {task}")

def list_todos():
    for i, todo in enumerate(todos, 1):
        status = "✓" if todo["done"] else " "
        print(f"{i}. [{status}] {todo['task']}")

def mark_done(index):
    if 0 <= index < len(todos):
        todos[index]["done"] = True
        print(f"Marked done: {todos[index]['task']}")

if __name__ == "__main__":
    add_todo("Buy milk")
    add_todo("Write tutorial")
    list_todos()
    mark_done(0)
    list_todos()
```

### 2.2 Verify Your Work

```bash
# Check generated file
ls todo.py

# Run test
python todo.py
```

**Expected output**:
```
Added: Buy milk
Added: Write tutorial
1. [ ] Buy milk
2. [ ] Write tutorial
Marked done: Buy milk
1. [✓] Buy milk
2. [ ] Write tutorial
```

## Phase 3: Your First Phase Log

Work is done — let's log it!

### 3.1 Create Phase Log

Enter the following in Claude:

```
/prompt-vault:log "Basic todo app implementation"
```

### 3.2 Verify the Generated Log

```bash
# Check phase-001.md file
cat .local/logs/phase-001.md
```

**Expected output**:
```markdown
# Phase 001: Basic todo app implementation

- **Date**: 2026-02-12
- **Session**: 0e303ae8-0889-4a75-b99b-3a642be5c07c

## User Prompt
> Create a simple todo app. Implement add, list, and mark-complete features in Python.

## Actions
- Created `todo.py` file for Python todo app implementation
- Implemented the following features:
  - `add_todo(task)`: Add new todo item
  - `list_todos()`: List all todo items
  - `mark_done(index)`: Mark todo as complete
- Added simple test cases (main block)

## Results
- **File created**: `todo.py` (~25 lines)
- **Core data structure**: `todos` list (dictionary elements: task, done)
- **Status display**: ✓ for complete, blank for incomplete

## Decisions
- **Language choice**: Python (conciseness, readability)
- **Data structure**: List + Dictionary (simple structure, no DB needed)
- **Output format**: Emoji checkbox (visual clarity)

## Next
- Add delete feature
- Add file save/load functionality (persistence)
- Improve CLI interface
```

### 3.3 Check the Index

```bash
# Check _index.md
cat .local/logs/_index.md
```

**Expected output**:
```markdown
# Phase Log Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | Basic todo app implementation | done | 2026-02-12 | Python todo add/list/complete features implemented |
```

### 3.4 Exercise 2.1: Add a Second Phase

This time, let's add a delete feature. Ask Claude:

```
Add a delete feature to todo.py. It should be able to delete a todo by index.
```

Claude will add a `delete_todo(index)` function. After completion:

```
/prompt-vault:log "Add todo delete feature"
```

### 3.5 Exercise 2.2: Compare Two Phases

```bash
# Check second log
cat .local/logs/phase-002.md

# Check index update
cat .local/logs/_index.md
```

Now `_index.md` will show two rows!

## Phase 4: Checking Progress

### 4.1 Status Query

Ask Claude:

```
/prompt-vault:status
```

### 4.2 Expected Output

```markdown
# Phase Log Index

| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | Basic todo app implementation | done | 2026-02-12 | Python todo add/list/complete features implemented |
| 002 | Add todo delete feature | done | 2026-02-12 | Index-based todo delete function implemented |

Total: 2 phases completed
```

### 4.3 Use Cases

`/prompt-vault:status` is useful in these situations:
- When reopening a project after a long break
- When sharing progress with team members
- When planning next steps

## Phase 5: Context Protection Experience

This section covers prompt-vault's core feature: the **context protection mechanism**.

### 5.1 Context Warning Simulation

In practice, after extended work, when context exceeds 80%, an automatic warning is displayed:

```
⚠️ [prompt-vault] Context ~85% used (680000 bytes).
💡 Run /prompt-vault:log to save progress, then /compact to free context.
```

### 5.2 Understanding the Internal Mechanism

The **Stop hook (context-check.sh)** runs after every response:

1. Measure current transcript file size
2. Read `warn_bytes` (640,000) from `.local/logs/.config`
3. Output warning if transcript size exceeds threshold

**Try it yourself**:
```bash
# Check the Stop hook script
cat ~/Downloads/prompt-vault/scripts/context-check.sh
```

### 5.3 Saving Checkpoint Before Compaction

When the warning appears, execute:

```
/prompt-vault:log "Checkpoint: file save/load feature complete"
/compact
```

### 5.4 Compaction Workflow

When `/compact` is executed, the following occurs sequentially:

1. **PreCompact hook** (`pre-compact.sh`) executes
   - Records current time and phase count to `.local/logs/compaction.log`

2. **Claude compacts context**
   - Summarizes long conversation to free context space

3. **SessionStart hook** (`post-compact.sh`) executes
   - Reads `.local/logs/_index.md`
   - Reads most recent `phase-*.md`
   - **Outputs both to stdout → Injected into Claude's new session context**

### 5.5 Recovery Verification

After compaction, Claude will display a recovery message like:

```
=== Phase Progress (post-compaction recovery) ===
# Phase Log Index
| # | Title | Status | Date | Summary |
|---|-------|--------|------|---------|
| 001 | Basic todo app implementation | done | 2026-02-12 | ... |
| 002 | Add todo delete feature | done | 2026-02-12 | ... |
| 003 | Checkpoint: file save/load feature complete | done | 2026-02-12 | ... |

=== Latest Phase Log ===
# Phase 003: Checkpoint: file save/load feature complete
- **Date**: 2026-02-12
...
=== End Recovery ===
```

### 5.6 Key Insight

**Progress is preserved even after compaction!**

- ✅ Phase index table recovered (full history)
- ✅ Latest phase log recovered (immediate work context)
- ✅ Claude restarts aware of project state

### 5.7 Exercise 3.1: Check Compaction History

```bash
# Check compaction history file
cat .local/logs/compaction.log
```

**Expected output**:
```
⚠️ Auto-compaction at 2026-02-12 14:32:10
Phase count: 3
---
```

## Real-World Scenarios

### Scenario 1: Multi-Day Project

**Day 1**:
```bash
# Start project
/prompt-vault:init
[Work 1] "Implement user authentication"
/prompt-vault:log "User authentication API implementation"
[Work 2] "Database design"
/prompt-vault:log "PostgreSQL schema design"
```

**Day 2 Resume**:
```bash
# Check yesterday's status
/prompt-vault:status

# Output:
# | 001 | User authentication API implementation | done | 2026-02-11 | ... |
# | 002 | PostgreSQL schema design | done | 2026-02-11 | ... |

# Now start next task
[Work 3] "Frontend implementation"
```

### Scenario 2: Managing Multiple Projects

```bash
# Project A
cd ~/project-a
claude --plugin-dir ~/Downloads/prompt-vault
/prompt-vault:init
[Work...]

# Project B (independent logs)
cd ~/project-b
claude --plugin-dir ~/Downloads/prompt-vault
/prompt-vault:init
[Work...]
```

Each project's `.local/logs/` is completely independent!

### Scenario 3: Team Collaboration (Future)

Commit logs to Git and share with team:

```bash
# Remove .local/ from .gitignore
vim .gitignore
# (Delete the `.local/` line)

# Commit logs
git add .local/logs/
git commit -m "docs: Add phase logs for sprint 1"
git push
```

## Best Practices

### When to Log

Set clear **completion criteria**:

- ✅ "3 API endpoints implemented" → Log
- ✅ "Bug fixed and tests passing" → Log
- ❌ "Still writing code..." → Don't log yet

### Phase Naming

**Action-oriented, result-focused**:

```bash
# Good examples
/prompt-vault:log "Implement JWT token authentication"
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

Logs are plain markdown files, so they're freely editable:

```bash
vim .local/logs/phase-001.md
# Fix typos, supplement content, add links, etc.
```

### 2. History Search

Search for past decisions or keywords:

```bash
# Find phases mentioning "PostgreSQL"
grep -r "PostgreSQL" .local/logs/

# Example output:
# phase-002.md:## Decisions
# phase-002.md:- **Database**: PostgreSQL chosen, reason: JSONB support
```

### 3. Custom Threshold Settings

If you want to receive context warnings earlier:

```bash
vim .local/logs/.config
```

```json
{
  "model": "claude-opus-4-6",
  "context_window_tokens": 200000,
  "warn_percent": 70,          # Changed from 80 → 70
  "warn_bytes": 560000         # Changed from 640000 → 560000
}
```

### 4. Phase Export

Use for documentation or report creation:

```bash
# Merge all phases into one file
cat .local/logs/phase-*.md > project-history.md

# Only phases from a specific period
cat .local/logs/phase-{001..005}.md > sprint1-history.md
```

## Tutorial Troubleshooting

### Issue 1: Permission Denied

**Symptom**:
```
Error: Permission denied: .local/logs/
```

**Solution**:
```bash
# Check project directory ownership
ls -la .local/

# Change ownership
sudo chown -R $USER:$USER .local/
```

### Issue 2: No Warnings Appearing

**Cause**: `jq` not installed or `.config` file issue

**Solution**:
```bash
# Check jq
which jq
brew install jq  # Install if missing

# Check .config
cat .local/logs/.config
/prompt-vault:init  # Re-initialize if missing
```

### Issue 3: No Recovery After Compaction

**Cause**: Didn't log any phases before compaction

**Solution**:
- The SessionStart hook requires at least one `phase-*.md` file to work
- Always run `/prompt-vault:log` before compaction

### Issue 4: Phase Number Gaps

**Symptom**: phase-001, phase-003 exist, but phase-002 is missing

**Cause**: Previously manually deleted phase-002, or numbering logic characteristic

**Solution**: **This is normal behavior.** Phase numbers don't need to be consecutive. Just sort by filename.

## Self-Assessment Quiz

Test your understanding of the tutorial:

### Q1. When do you run `/prompt-vault:init`?
**A**: Once per project. It's an idempotent operation, so it's safe to run multiple times.

### Q2. What format are phase logs stored in?
**A**: `.local/logs/phase-NNN.md` markdown files (NNN auto-increments from 001)

### Q3. When do context warnings appear?
**A**: When transcript size exceeds the `warn_bytes` threshold in `.config` (default 640KB)

### Q4. What gets recovered after compaction?
**A**: `_index.md` (phase index table) + most recent `phase-*.md` (latest phase log)

### Q5. What is the Stop hook's role?
**A**: After every response, it checks transcript size and outputs a warning message when 80% is exceeded

### Q6. How do you commit logs to Git?
**A**: Remove the `.local/` line from `.gitignore`. (Be careful of sensitive information!)

### Q7. Is it okay if phase numbers have gaps?
**A**: Yes, it's normal. Gaps can occur when files are deleted.

### Q8. Can it be used across multiple projects simultaneously?
**A**: Yes, each project's `.local/logs/` is managed independently.

## Next Steps

Congratulations! You've now mastered all of prompt-vault's core features.

### Additional Learning Resources

- **[ARCHITECTURE.en.md](ARCHITECTURE.en.md)** — Deep dive into plugin internals
  - Hook system mechanics
  - Skill implementation details
  - Customization guide

- **[README.en.md](README.en.md)** — Quick reference guide
  - FAQ
  - Troubleshooting
  - Best practices

### Explore Customization

Adapt the plugin to your own workflow:

- Modify the phase template (`templates/phase.md`)
- Adjust thresholds (`.local/logs/.config`)
- Add new hooks (`hooks/hooks.json`)

### Multi-Project Workflow

Try using the plugin in a real project:

```bash
cd ~/my-real-project
claude --plugin-dir ~/Downloads/prompt-vault
/prompt-vault:init
[Start your actual work]
```

## Resources

- **GitHub**: https://github.com/lemon-etvibe/prompt-vault
- **Issue Tracking**: https://github.com/lemon-etvibe/prompt-vault/issues
- **README.en.md**: Quick reference guide
- **ARCHITECTURE.en.md**: Technical internal structure

---

**Have questions or feedback?**
Feel free to leave them on GitHub Issues. We'd love to hear from you!

**Happy logging! 🚀**
