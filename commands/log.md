---
description: "Record completed work as a phase log. Use when a task is done, the user says '로그', '기록', 'log', or before ending a session."
argument-hint: [phase-title]
---

**You MUST use the Skill tool to invoke `prompt-vault:log` with args `{argument}` (phase title).**

This skill:
- Creates `phase-NNN.md` with User Prompt, Actions, Results, Decisions, Next sections
- Updates `_index.md` with the new phase row
- Updates `last-log-state.json` to prevent auto-logger duplication

Do NOT write phase logs or update _index.md manually — always delegate to the skill.
