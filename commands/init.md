---
description: "Initialize prompt-vault logging environment. Use when starting a new project, when .local/logs/ doesn't exist, or when the user says 'init', '초기화', 'set up logging'. Pass 'en' or 'ko' to set language directly."
argument-hint: [en|ko]
---

**You MUST use the Skill tool to invoke `prompt-vault:init` with args `{argument}`.**

This skill:
- Collects user preferences (language, model, project name, palette, auto-logging)
- Runs `init.sh` to create `.local/logs/`, `.config`, `_index.md`, `.gitignore`, `CLAUDE.md` entries

Do NOT create these files manually — always delegate to the skill.
