---
description: "Show phase progress summary. Use when the user asks '진행 상황', '현재 상태', 'status', or 'progress'."
allowed-tools: ["Skill"]
---

**You MUST use the Skill tool to invoke `prompt-vault:status`.**

This skill:
- Reads `_index.md` and `.config` (for language)
- Displays total/completed phase count, latest phase, and recent phases table

Do NOT read _index.md and summarize manually — always delegate to the skill.
