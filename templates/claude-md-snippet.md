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
